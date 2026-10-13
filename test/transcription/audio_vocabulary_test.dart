import 'dart:io';
import 'dart:typed_data';

import 'package:call_to_record/transcription/audio_embedder.dart';
import 'package:call_to_record/transcription/audio_vocabulary.dart';
import 'package:flutter_test/flutter_test.dart';

/// A unit vector along dimension [d].
Float32List _unit(int d) => Float32List(embeddingDimension)..[d] = 1;

Uint8List _bytes(List<Float32List> vectors) {
  final all = Float32List(vectors.length * embeddingDimension);
  for (var i = 0; i < vectors.length; i++) {
    all.setRange(i * embeddingDimension, (i + 1) * embeddingDimension, vectors[i]);
  }
  return all.buffer.asUint8List();
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('audio_vocabulary_test_'));

  tearDown(() => dir.deleteSync(recursive: true));

  test('loads the words and finds the vector most similar to a window', () async {
    final tsv = File('${dir.path}/audio_vocabulary.tsv')..writeAsStringSync('ciao\tit\nbene\ten\n');
    // Each word: male voice, then female voice.
    final bin = File('${dir.path}/audio_vocabulary.f32')
      ..writeAsBytesSync(_bytes([_unit(0), _unit(0), _unit(1), _unit(2)]));

    final vocabulary = await AudioVocabulary.load(tsv: tsv, binary: bin);

    expect(vocabulary.words, ['ciao', 'bene']);
    final match = vocabulary.bestMatch(_unit(2));
    expect(match.word, 1);
    expect(match.similarity, closeTo(1, 1e-6));
  });

  test('a vocabulary file of the wrong size is refused', () async {
    final tsv = File('${dir.path}/audio_vocabulary.tsv')..writeAsStringSync('ciao\tit\n');
    final bin = File('${dir.path}/audio_vocabulary.f32')..writeAsBytesSync(_bytes([_unit(0)]));

    await expectLater(
      AudioVocabulary.load(tsv: tsv, binary: bin),
      throwsA(isA<FormatException>()),
    );
  });
}
