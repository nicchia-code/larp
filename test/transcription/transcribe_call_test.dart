import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:call_to_record/call/audio_sources.dart';
import 'package:call_to_record/call/recorder.dart';
import 'package:call_to_record/transcription/audio_embedder.dart';
import 'package:call_to_record/transcription/audio_vocabulary.dart';
import 'package:call_to_record/transcription/transcribe_call.dart';
import 'package:flutter_test/flutter_test.dart';

// Vocabulary and embedding as in word_segmentation_test: "ciao" 0.5, "bene" -0.5, unknown 0.25.
AudioVocabulary _vocabulary() {
  final vectors = Float32List(3 * 2 * embeddingDimension);
  for (var word = 0; word < 3; word++) {
    for (var voice = 0; voice < 2; voice++) {
      vectors[(word * 2 + voice) * embeddingDimension + word] = 1;
    }
  }
  return AudioVocabulary(words: const ['ciao', 'bene', 'altro'], vectors: vectors);
}

Float32List _embed(Float32List window) {
  final speech = window.where((v) => v != 0).length / window.length;
  final level = window.firstWhere((v) => v != 0, orElse: () => 0);
  final target = level > 0.4 ? 0 : (level < -0.4 ? 1 : 3);
  return Float32List(embeddingDimension)
    ..[target] = speech
    ..[10] = sqrt(1 - speech * speech);
}

// One 0.4 s step per level, as 16-bit PCM bytes.
Uint8List _pcm(List<double> steps) {
  final data = ByteData(steps.length * 6400 * 2);
  var at = 0;
  for (final level in steps) {
    for (var i = 0; i < 6400; i++) {
      data.setInt16(at, (level * 32767).round(), Endian.little);
      at += 2;
    }
  }
  return data.buffer.asUint8List();
}

Future<File> _writeCall(File file, List<double> io, List<double> altri) async {
  final wav = await WavWriter.open(file);
  wav.add(AudioSource.microphone, _pcm(io));
  wav.add(AudioSource.pcAudio, _pcm(altri));
  await wav.close();
  return file;
}

void main() {
  late Directory dir;
  late File wav;
  final start = DateTime(2026, 10, 13, 18, 58);

  setUp(() {
    dir = Directory.systemTemp.createTempSync('transcribe_call_test_');
    wav = File('${dir.path}/2026-10-13_18-58-00.wav');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('each channel of the WAV is one track in [-1, 1]', () async {
    await _writeCall(wav, [0.5, 0], [0, -0.25]);

    final io = await readWavChannel(wav, 0);
    final altri = await readWavChannel(wav, 1);

    expect(io.length, 12800);
    expect(io[0], closeTo(0.5, 1e-3));
    expect(altri[6400], closeTo(-0.25, 1e-3));
  });

  test('the markdown has the words of each speaker in start order, next to the WAV', () async {
    await _writeCall(wav, [0, 0.5, 0, 0], [0, 0, 0, -0.5]);
    final progress = <double>[];

    final md = await writeTranscript(
      wav: wav,
      start: start,
      vocabulary: _vocabulary(),
      embed: _embed,
      onProgress: progress.add,
    );

    expect(md.path, '${dir.path}/2026-10-13_18-58-00.md');
    expect(md.readAsStringSync(), '# Call del 13/10/2026 alle 18:58\n'
        '\n'
        'Durata: 00:00:01\n'
        '\n'
        '[00:00] **Io:** Ciao.\n'
        '[00:01] **Altri:** Bene.\n');
    expect(progress.last, 1);
  });

  test('a call without speech says so', () async {
    await _writeCall(wav, [0, 0], [0, 0]);

    final md = await writeTranscript(
      wav: wav,
      start: start,
      vocabulary: _vocabulary(),
      embed: _embed,
      onProgress: (_) {},
    );

    expect(md.readAsStringSync(), contains('Nessun parlato rilevato'));
  });

  test('a failed transcription writes no markdown', () async {
    await _writeCall(wav, [0, 0.5], [0, 0]);

    await expectLater(
      writeTranscript(
        wav: wav,
        start: start,
        vocabulary: _vocabulary(),
        embed: (_) => throw StateError('modello rotto'),
        onProgress: (_) {},
      ),
      throwsStateError,
    );

    expect(File('${dir.path}/2026-10-13_18-58-00.md').existsSync(), isFalse);
  });
}
