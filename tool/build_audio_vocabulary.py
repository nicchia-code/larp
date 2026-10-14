#!/usr/bin/env python3
"""Generates the audio vocabulary (run once by the developer on macOS).

For every word, `say` synthesizes it with a male and a female voice; `afconvert`
makes it mono 16 kHz; EmbeddingGemma 2 (int8, ONNX Runtime on CPU) embeds it
through the audio path only, as its processor does for `<|audio|>` input.

Usage:
  python3 tool/build_audio_vocabulary.py --model-dir <onnx-community/embeddinggemma-2-ONNX copy> \
      --it-words <frequency list> --en-words <frequency list> --out <folder>

Dependencies: numpy, onnxruntime, transformers (feature extractor and tokenizer only).
Frequency lists: one word per line, most frequent first; text after the word is ignored.

Output in --out, rows in the same order:
  audio_vocabulary.tsv   "<word>\t<it|en>" per word
  audio_vocabulary.f32   per word, 2 x 768 little-endian float32: male voice, then female voice (unit norm)
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import tempfile
import uuid
import wave
import numpy as np

SAMPLE_RATE = 16_000
DIM = 768
AUDIO_DIM = 512  # width of the audio encoder output
# ponytail: voices of a stock macOS install; change here if the M1 lacks them.
VOICES = {"it": ("Luca", "Alice"), "en": ("Alex", "Samantha")}  # (male, female)
DEFAULT_COUNTS = {"it": 50_000, "en": 20_000}


def read_words(path, count):
    """First `count` distinct words of a frequency list, in list order."""
    words, seen = [], set()
    with open(path, encoding="utf-8") as f:
        for line in f:
            fields = line.split()
            if not fields or fields[0] in seen:
                continue
            seen.add(fields[0])
            words.append(fields[0])
            if len(words) == count:
                break
    return words


def read_wav(path):
    """Reads a mono 16 kHz 16-bit PCM WAV as float32 in [-1, 1]."""
    with wave.open(str(path), "rb") as w:
        if (w.getnchannels(), w.getframerate(), w.getsampwidth()) != (1, SAMPLE_RATE, 2):
            raise ValueError(f"{path}: expected mono 16 kHz 16-bit PCM")
        pcm = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2")
    return pcm.astype(np.float32) / 32768.0


def synthesize(word, voice, workdir):
    """Speaks `word` with macOS `say` and returns it as mono 16 kHz audio."""
    wav = workdir / f"{uuid.uuid4().hex}.wav"
    cmd = [
        "say",
        "-v",
        voice,
        "--file-format=WAVE",
        "--data-format=LEI16@16000",
        "-o",
        str(wav),
        "--",
        word,
    ]
    for attempt in range(3):
        try:
            subprocess.run(cmd, check=True, timeout=10)
            break
        except (subprocess.TimeoutExpired, subprocess.SubprocessError):
            wav.unlink(missing_ok=True)
            if attempt == 2:
                raise
    try:
        return read_wav(wav)
    finally:
        wav.unlink(missing_ok=True)


def audio_token_count(mask):
    """Audio placeholder tokens for a mel-frame mask: two stride-2 convolutions, as the processor simulates."""
    for _ in range(2):
        t_out = (len(mask) - 1) // 2 + 1
        mask = mask[::2][:t_out]
    return int(mask.sum())


class Embedder:
    """EmbeddingGemma 2 audio-only embedding, with the same steps as its processor and model."""

    def __init__(self, model_dir):
        import onnxruntime as ort
        from transformers import AutoFeatureExtractor, AutoTokenizer

        self.model_dir = Path(model_dir)
        self.features = AutoFeatureExtractor.from_pretrained(self.model_dir)
        self.tokenizer = AutoTokenizer.from_pretrained(self.model_dir)
        onnx_dir = self.model_dir / "onnx"
        self.encoder = ort.InferenceSession(
            str(onnx_dir / "audio_encoder_quantized.onnx"), providers=["CPUExecutionProvider"]
        )
        self.model = ort.InferenceSession(
            str(onnx_dir / "model_quantized.onnx"), providers=["CPUExecutionProvider"]
        )

    def embed(self, wave):
        """Unit-norm 768-dim embedding of one mono 16 kHz waveform."""
        out = self.features([wave], return_tensors="np")
        feats = np.asarray(out["input_features"])[0].astype(np.float32)
        mask = np.asarray(out["input_features_mask"])[0].astype(bool)
        audio = self.encoder.run(
            ["audio_features"],
            {"input_features": feats[None], "input_features_mask": mask[None]},
        )[0]

        n = audio_token_count(mask)
        if audio.shape[0] != n:
            raise RuntimeError(f"audio encoder gave {audio.shape[0]} tokens, expected {n}")

        t = self.tokenizer
        tokens = t(f"{t.boa_token}{t.audio_token * n}{t.eoa_token}", return_tensors="np")
        vec = self.model.run(
            ["sentence_embedding"],
            {
                "input_ids": tokens["input_ids"].astype(np.int64),
                "attention_mask": tokens["attention_mask"].astype(np.int64),
                "image_features": np.zeros((0, AUDIO_DIM), np.float32),
                "video_features": np.zeros((0, AUDIO_DIM), np.float32),
                "audio_features": audio.astype(np.float32),
            },
        )[0][0]
        if vec.shape != (DIM,):
            raise RuntimeError(f"embedding has shape {vec.shape}, expected ({DIM},)")
        return vec / np.linalg.norm(vec)


def write_entry(tsv, bin_file, word, lang, male, female):
    """Appends one word: its line in the TSV and its two vectors in the binary file."""
    tsv.write(f"{word}\t{lang}\n")
    bin_file.write(np.concatenate([male, female]).astype("<f4").tobytes())


def build(args):
    embedder = Embedder(args.model_dir)
    args.out.mkdir(parents=True, exist_ok=True)
    tsv_path = args.out / "audio_vocabulary.tsv"
    bin_path = args.out / "audio_vocabulary.f32"

    existing_counts = {"it": 0, "en": 0}
    if tsv_path.exists() and bin_path.exists():
        with open(tsv_path, encoding="utf-8") as f:
            for line in f:
                parts = line.rstrip("\n").split("\t")
                if len(parts) == 2 and parts[1] in existing_counts:
                    existing_counts[parts[1]] += 1
        valid_entries = sum(existing_counts.values())
        expected_bin_bytes = valid_entries * 2 * DIM * 4
        actual_bin_bytes = bin_path.stat().st_size
        if actual_bin_bytes != expected_bin_bytes:
            raise RuntimeError(
                f"Resume check failed: TSV has {valid_entries} entries but binary is {actual_bin_bytes} bytes "
                f"(expected {expected_bin_bytes})."
            )
        print(f"Resuming: found {existing_counts['it']} it words and {existing_counts['en']} en words", flush=True)

    mode_tsv = "a" if existing_counts["it"] > 0 or existing_counts["en"] > 0 else "w"
    mode_bin = "ab" if existing_counts["it"] > 0 or existing_counts["en"] > 0 else "wb"

    with tempfile.TemporaryDirectory() as tmp, \
            open(tsv_path, mode_tsv, encoding="utf-8") as tsv, \
            open(bin_path, mode_bin) as bin_file, \
            ThreadPoolExecutor(max_workers=6) as pool:
        workdir = Path(tmp)
        for lang, words_path in (("it", args.it_words), ("en", args.en_words)):
            all_words = read_words(words_path, DEFAULT_COUNTS[lang])
            skip = existing_counts[lang]
            words = all_words[skip:]
            print(f"{lang}: {len(all_words)} words total, skipping {skip}, {len(words)} to process", flush=True)
            if not words:
                continue
            male_voice, female_voice = VOICES[lang]
            batch_size = 64
            for start in range(0, len(words), batch_size):
                batch = words[start:start + batch_size]
                male_futs = [pool.submit(synthesize, w, male_voice, workdir) for w in batch]
                female_futs = [pool.submit(synthesize, w, female_voice, workdir) for w in batch]
                for w, mf, ff in zip(batch, male_futs, female_futs):
                    male = embedder.embed(mf.result())
                    female = embedder.embed(ff.result())
                    write_entry(tsv, bin_file, w, lang, male, female)
                done = skip + min(start + batch_size, len(words))
                if done % 1000 == 0 or done == len(all_words):
                    tsv.flush()
                    bin_file.flush()
                    print(f"{lang}: {done}", flush=True)
def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--it-words", type=Path, required=True)
    parser.add_argument("--en-words", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    build(args)


if __name__ == "__main__":
    main()
