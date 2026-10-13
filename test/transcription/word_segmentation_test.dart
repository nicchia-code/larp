import 'dart:math';
import 'dart:typed_data';

import 'package:call_to_record/transcription/audio_embedder.dart';
import 'package:call_to_record/transcription/audio_vocabulary.dart';
import 'package:call_to_record/transcription/word_segmentation.dart';
import 'package:flutter_test/flutter_test.dart';

// Vocabulary of three words, both voices alike: "ciao" on dimension 0, "bene" on 1, "altro" on 2.
AudioVocabulary _vocabulary() {
  final vectors = Float32List(3 * 2 * embeddingDimension);
  for (var word = 0; word < 3; word++) {
    for (var voice = 0; voice < 2; voice++) {
      vectors[(word * 2 + voice) * embeddingDimension + word] = 1;
    }
  }
  return AudioVocabulary(words: const ['ciao', 'bene', 'altro'], vectors: vectors);
}

// A track on the 0.4 s grid: each step is silence (0) or a constant level that identifies its word.
// 0.5 is "ciao", -0.5 is "bene", 0.25 is a word outside the vocabulary.
Float32List _track(List<double> steps) => Float32List.fromList([
  for (final level in steps) ...List.filled(6400, level),
]);

int embedCalls = 0;

// Stands in for the encoder: a window is its level's direction, mixed with an orthogonal direction
// in proportion to how much of it is silence, so a window only half on the word matches it half.
Float32List _embed(Float32List window) {
  embedCalls++;
  final speech = window.where((v) => v != 0).length / window.length;
  final level = window.firstWhere((v) => v != 0, orElse: () => 0);
  final target = level > 0.4 ? 0 : (level < -0.4 ? 1 : 3);
  final vector = Float32List(embeddingDimension)
    ..[target] = speech
    ..[10] = sqrt(1 - speech * speech);
  return vector;
}

void main() {
  setUp(() => embedCalls = 0);

  test('finds the words of the windows that match, with their timing', () {
    final track = _track([0, 0.5, 0, -0.5, 0, 0, 0, 0.25, 0]);

    final words = recognizeWords(samples: track, vocabulary: _vocabulary(), embed: _embed);

    expect(words.map((w) => w.text), ['ciao', 'bene', unknownWord]);
    expect(words[0].start, const Duration(milliseconds: 400));
    expect(words[0].end, const Duration(milliseconds: 800));
    expect(words[1].start, const Duration(milliseconds: 1200));
    expect(words[2].start, const Duration(milliseconds: 2800));
  });

  test('silence produces no words and is never embedded', () {
    final words = recognizeWords(
      samples: _track([0, 0, 0.001, 0]),
      vocabulary: _vocabulary(),
      embed: _embed,
    );

    expect(words, isEmpty);
    expect(embedCalls, 0);
  });

  test('sentences close at a pause longer than the sentence gap, capitalized and with a period', () {
    const words = [
      RecognizedWord(start: Duration(milliseconds: 0), end: Duration(milliseconds: 400), text: 'ciao'),
      RecognizedWord(start: Duration(milliseconds: 1000), end: Duration(milliseconds: 1400), text: 'bene'),
      RecognizedWord(start: Duration(milliseconds: 2200), end: Duration(milliseconds: 2600), text: 'altro'),
    ];

    final sentences = sentencesOf(words, speaker: 'Io');

    expect(sentences.map((s) => s.text), ['Ciao bene.', 'Altro.']);
    expect(sentences.map((s) => s.start), [Duration.zero, const Duration(milliseconds: 2200)]);
    expect(sentences.first.speaker, 'Io');
  });

  test('the sentences of both speakers interleave by start, Io first on a tie', () {
    Sentence at(int ms, String speaker) =>
        Sentence(start: Duration(milliseconds: ms), speaker: speaker, text: '$speaker $ms.');

    final merged = interleave(
      [at(0, 'Io'), at(2000, 'Io')],
      [at(1000, 'Altri'), at(2000, 'Altri')],
    );

    expect(merged.map((s) => s.speaker), ['Io', 'Altri', 'Io', 'Altri']);
  });
}
