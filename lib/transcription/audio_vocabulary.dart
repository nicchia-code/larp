import 'dart:io';
import 'dart:typed_data';

import 'audio_embedder.dart';

/// The audio vocabulary: each word has two unit vectors, one per voice (male, then female).
/// The files are written by tool/build_audio_vocabulary.py: `audio_vocabulary.tsv` has one `word<TAB>language`
/// line per word and `audio_vocabulary.f32` holds, per word in the same order, 2 x 768 little-endian float32 values.
class AudioVocabulary {
  AudioVocabulary({required this.words, required this.vectors}) {
    if (vectors.length != words.length * 2 * embeddingDimension) {
      throw ArgumentError('vocabolario: ${vectors.length} valori per ${words.length} parole');
    }
  }

  final List<String> words;

  /// [words.length] x 2 x [embeddingDimension] values, row-major.
  final Float32List vectors;

  static Future<AudioVocabulary> load({required File tsv, required File binary}) async {
    if (Endian.host != Endian.little) throw UnsupportedError('il vocabolario è little-endian');
    final words = [
      for (final line in await tsv.readAsLines())
        if (line.isNotEmpty) line.split('\t').first,
    ];
    final vectors = Float32List(words.length * 2 * embeddingDimension);
    final bytes = vectors.buffer.asUint8List();
    final file = await binary.open();
    try {
      if (await file.length() != bytes.length) {
        throw FormatException('${binary.path}: ${await file.length()} byte, attesi ${bytes.length}');
      }
      var read = 0;
      while (read < bytes.length) {
        final n = await file.readInto(bytes, read, bytes.length);
        if (n == 0) throw FileSystemException('lettura interrotta', binary.path);
        read += n;
      }
    } finally {
      await file.close();
    }
    return AudioVocabulary(words: words, vectors: vectors);
  }

  // ponytail: brute-force scan of every vector (about 85 ms per window at 70k words); an index if calls get too slow.
  /// The vector most similar to [query] (a unit vector): its cosine similarity and the index of its word.
  ({double similarity, int word}) bestMatch(Float32List query) {
    var best = double.negativeInfinity;
    var bestVector = 0;
    final rows = words.length * 2;
    for (var v = 0; v < rows; v++) {
      final base = v * embeddingDimension;
      var dot = 0.0;
      for (var d = 0; d < embeddingDimension; d++) {
        dot += query[d] * vectors[base + d];
      }
      if (dot > best) {
        best = dot;
        bestVector = v;
      }
    }
    return (similarity: best, word: bestVector ~/ 2);
  }
}
