import 'dart:math';
import 'dart:typed_data';

import 'audio_vocabulary.dart';

/// The calibration constants of the transcription, all in this one place (Requirements rules, call/Transcribing).
// ponytail: uncalibrated values. The step decides how many windows are embedded, so the time per call.
abstract final class Tuning {
  static const sampleRate = 16000;

  /// Grid step of the sliding windows, 0.4 s at 16 kHz.
  static const stepSamples = 6400;

  /// Window lengths in grid steps: 0.4 s, 0.8 s and 1.2 s.
  static const windowSteps = [1, 2, 3];

  /// A speech window whose best similarity is below this is written as [unknownWord].
  static const confidence = 0.6;

  /// A window whose RMS is below this is silence and produces no word.
  static const silenceRms = 0.01;

  /// A pause longer than this closes the sentence.
  static const sentenceGap = Duration(milliseconds: 700);
}

/// The text of a speech window that matches no word with enough confidence.
const unknownWord = '[?]';

/// The least a speech window adds to the score of a track; keeps unmatched speech in the words.
const _minimumGain = 1e-9;

/// A word of one track: the vocabulary word of its window, or [unknownWord].
class RecognizedWord {
  const RecognizedWord({required this.start, required this.end, required this.text});

  final Duration start;
  final Duration end;
  final String text;
}

/// A sentence of one speaker, starting when its first word starts.
class Sentence {
  const Sentence({required this.start, required this.speaker, required this.text});

  final Duration start;
  final String speaker;
  final String text;
}

/// Finds the words of one mono 16 kHz track in [-1, 1].
///
/// Windows of every length in [Tuning.windowSteps] slide over the track by one step. Silent windows are skipped;
/// every other window is embedded by [embed] and scored by its best similarity to the vocabulary. The words are
/// then the non-overlapping windows with the best total similarity. [onProgress] reports the fraction of the
/// windows embedded so far.
List<RecognizedWord> recognizeWords({
  required Float32List samples,
  required AudioVocabulary vocabulary,
  required Float32List Function(Float32List window) embed,
  void Function(double progress)? onProgress,
}) {
  const step = Tuning.stepSamples;
  final lengths = Tuning.windowSteps;
  final units = samples.length ~/ step;

  // Energy of every step; a window's RMS follows from the steps it covers.
  final energy = Float64List(units);
  for (var u = 0; u < units; u++) {
    var sum = 0.0;
    for (var i = u * step; i < (u + 1) * step; i++) {
      sum += samples[i] * samples[i];
    }
    energy[u] = sum;
  }

  // Window ending at step t with length index w: its speech flag, similarity and vocabulary vector.
  final cells = (units + 1) * lengths.length;
  final speech = Uint8List(cells);
  var total = 0;
  for (var t = 1; t <= units; t++) {
    for (var w = 0; w < lengths.length; w++) {
      final steps = lengths[w];
      if (steps > t) continue;
      var sum = 0.0;
      for (var u = t - steps; u < t; u++) {
        sum += energy[u];
      }
      if (sqrt(sum / (steps * step)) >= Tuning.silenceRms) {
        speech[t * lengths.length + w] = 1;
        total++;
      }
    }
  }

  final similarity = Float64List(cells);
  final wordOf = Int32List(cells);
  var done = 0;
  for (var t = 1; t <= units; t++) {
    for (var w = 0; w < lengths.length; w++) {
      final cell = t * lengths.length + w;
      if (speech[cell] == 0) continue;
      final steps = lengths[w];
      final window = Float32List.sublistView(samples, (t - steps) * step, t * step);
      final match = vocabulary.bestMatch(embed(window));
      similarity[cell] = match.similarity;
      wordOf[cell] = match.word;
      done++;
      onProgress?.call(done / total);
    }
  }
  if (total == 0) onProgress?.call(1);

  // Best total score over the track up to step t, and the window that ends there, if any. A speech window scores its
  // similarity, never less than a tiny gain: speech that matches nothing still is a window, written as unknownWord.
  final best = Float64List(units + 1);
  final chosen = Int32List(units + 1)..fillRange(0, units + 1, -1);
  for (var t = 1; t <= units; t++) {
    best[t] = best[t - 1];
    for (var w = 0; w < lengths.length; w++) {
      final steps = lengths[w];
      final cell = t * lengths.length + w;
      if (steps > t || speech[cell] == 0) continue;
      final score = best[t - steps] + max(similarity[cell], 0) + _minimumGain;
      if (score > best[t]) {
        best[t] = score;
        chosen[t] = w;
      }
    }
  }

  final words = <RecognizedWord>[];
  var t = units;
  while (t > 0) {
    final w = chosen[t];
    if (w < 0) {
      t--;
      continue;
    }
    final steps = lengths[w];
    final cell = t * lengths.length + w;
    words.add(
      RecognizedWord(
        start: _time((t - steps) * step),
        end: _time(t * step),
        text: similarity[cell] >= Tuning.confidence ? vocabulary.words[wordOf[cell]] : unknownWord,
      ),
    );
    t -= steps;
  }
  return words.reversed.toList();
}

/// The sentences of one speaker. A pause longer than [Tuning.sentenceGap] closes a sentence; each one is its
/// words joined by spaces, with the first letter capitalized and a final period.
List<Sentence> sentencesOf(List<RecognizedWord> words, {required String speaker}) {
  final sentences = <Sentence>[];
  var current = <RecognizedWord>[];

  void close() {
    if (current.isEmpty) return;
    final text = current.map((w) => w.text).join(' ');
    sentences.add(
      Sentence(
        start: current.first.start,
        speaker: speaker,
        text: '${text[0].toUpperCase()}${text.substring(1)}.',
      ),
    );
    current = [];
  }

  for (final word in words) {
    if (current.isNotEmpty && word.start - current.last.end > Tuning.sentenceGap) close();
    current.add(word);
  }
  close();
  return sentences;
}

/// Merges two lists of sentences, each in start order, into one in start order; on a tie [first] comes first.
List<Sentence> interleave(List<Sentence> first, List<Sentence> second) {
  final merged = <Sentence>[];
  var i = 0;
  var j = 0;
  while (i < first.length || j < second.length) {
    if (j >= second.length || (i < first.length && first[i].start <= second[j].start)) {
      merged.add(first[i++]);
    } else {
      merged.add(second[j++]);
    }
  }
  return merged;
}

Duration _time(int samples) => Duration(microseconds: samples * 1000000 ~/ Tuning.sampleRate);
