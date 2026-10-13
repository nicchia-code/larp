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
import subprocess
import tempfile
import wave
from pathlib import Path

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
    aiff, wav = workdir / "say.aiff", workdir / "say.wav"
    subprocess.run(["say", "-v", voice, "-o", str(aiff), word], check=True)
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", "LEI16@16000", "-c", "1", str(aiff), str(wav)],
        check=True,
    )
    return read_wav(wav)


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
    with tempfile.TemporaryDirectory() as tmp, \
            open(args.out / "audio_vocabulary.tsv", "w", encoding="utf-8") as tsv, \
            open(args.out / "audio_vocabulary.f32", "wb") as bin_file:
        workdir = Path(tmp)
        for lang, words_path in (("it", args.it_words), ("en", args.en_words)):
            words = read_words(words_path, DEFAULT_COUNTS[lang])
            print(f"{lang}: {len(words)} words", flush=True)
            male_voice, female_voice = VOICES[lang]
            for i, word in enumerate(words, 1):
                male = embedder.embed(synthesize(word, male_voice, workdir))
                female = embedder.embed(synthesize(word, female_voice, workdir))
                write_entry(tsv, bin_file, word, lang, male, female)
                if i % 1000 == 0:
                    print(f"{lang}: {i}", flush=True)


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
