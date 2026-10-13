import 'dart:math';
import 'dart:typed_data';

import 'package:call_to_record/transcription/audio_features.dart';
import 'package:flutter_test/flutter_test.dart';

// Reference values from transformers' Gemma4AudioFeatureExtractor on the same 8000 samples (0.5 s).
Float32List _twoTones() => Float32List.fromList([
  for (var n = 0; n < 8000; n++) 0.3 * sin(2 * pi * 440 * n / 16000) + 0.2 * sin(2 * pi * 1500 * n / 16000),
]);

void main() {
  test('log-mel features match transformers on a reference signal', () {
    final features = melFeatures(_twoTones());

    expect(features.frames, 50);
    expect(features.valid.fold<int>(0, (sum, v) => sum + v), 49);
    expect(features.valid.last, 0);
    double at(int frame, int band) => features.values[frame * melBands + band];
    expect(at(0, 0), closeTo(-6.9077554, 1e-3));
    expect(at(0, 10), closeTo(-0.3080197, 1e-3));
    expect(at(0, 60), closeTo(1.5004579, 1e-3));
    expect(at(0, 127), closeTo(-1.4636374, 1e-3));
    expect(at(5, 0), closeTo(-6.9077554, 1e-3));
    expect(at(5, 10), closeTo(-4.415163, 1e-3));
    expect(at(5, 60), closeTo(-0.22186464, 1e-3));
    expect(at(5, 127), closeTo(-6.8997784, 1e-3));
    expect(at(49, 0), 0);
  });

  test('audio tokens are the valid frames at stride 4', () {
    expect(audioTokenCount(melFeatures(_twoTones()).valid), 13);
    expect(audioTokenCount(Uint8List(100)..fillRange(0, 100, 1)), 25);
    expect(audioTokenCount(Uint8List(100)..fillRange(0, 40, 1)), 10);
  });
}
