"""Self-check of build_audio_vocabulary.py: python3 tool/build_audio_vocabulary_test.py"""

import io
import tempfile
import unittest
import wave
from pathlib import Path

import numpy as np

import build_audio_vocabulary as bav


class ReadWordsTest(unittest.TestCase):
    def test_keeps_first_distinct_words_up_to_count(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "list.txt"
            path.write_text("ciao 900\n\nil 800\nciao 700\nchi\nse 1\n", encoding="utf-8")
            self.assertEqual(bav.read_words(path, 3), ["ciao", "il", "chi"])


class AudioTokenCountTest(unittest.TestCase):
    def test_all_frames_valid(self):
        # 100 frames -> 50 -> 25 after two stride-2 convolutions
        self.assertEqual(bav.audio_token_count(np.ones(100, dtype=bool)), 25)

    def test_only_leading_frames_valid(self):
        # 40 valid frames -> 20 -> 10
        mask = np.zeros(100, dtype=bool)
        mask[:40] = True
        self.assertEqual(bav.audio_token_count(mask), 10)


class ReadWavTest(unittest.TestCase):
    def _wav(self, channels, rate):
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(channels)
            w.setsampwidth(2)
            w.setframerate(rate)
            w.writeframes(np.array([0, 16384, -32768, 32767] * channels, dtype="<i2").tobytes())
        return buf.getvalue()

    def test_reads_mono_16k_as_float(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ok.wav"
            path.write_bytes(self._wav(1, 16_000))
            np.testing.assert_allclose(bav.read_wav(path), [0.0, 0.5, -1.0, 32767 / 32768])

    def test_rejects_other_formats(self):
        with tempfile.TemporaryDirectory() as tmp:
            for channels, rate in ((2, 16_000), (1, 22_050)):
                path = Path(tmp) / "bad.wav"
                path.write_bytes(self._wav(channels, rate))
                with self.assertRaises(ValueError):
                    bav.read_wav(path)


class WriteEntryTest(unittest.TestCase):
    def test_row_layout_is_tsv_line_and_two_vectors(self):
        tsv, bin_file = io.StringIO(), io.BytesIO()
        male, female = np.full(768, 0.25, np.float32), np.full(768, -0.5, np.float32)
        bav.write_entry(tsv, bin_file, "ciao", "it", male, female)
        self.assertEqual(tsv.getvalue(), "ciao\tit\n")
        row = np.frombuffer(bin_file.getvalue(), dtype="<f4")
        np.testing.assert_array_equal(row, np.concatenate([male, female]))


if __name__ == "__main__":
    unittest.main()
