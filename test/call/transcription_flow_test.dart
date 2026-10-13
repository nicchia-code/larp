import 'dart:async';
import 'dart:io';

import 'package:call_to_record/call/audio_sources.dart';
import 'package:call_to_record/call/call_controller.dart';
import 'package:call_to_record/last_transcript.dart';
import 'package:call_to_record/transcription/transcribe_call.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_capture.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late Directory dir;
  late File file;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('transcription_flow_test_');
    file = File('${dir.path}/call.wav');
  });

  tearDown(() => dir.deleteSync(recursive: true));

  CallController controllerWith(Transcriber transcribe) => CallController(
    missingSources: () async => [],
    capture: (_) async => FakeCapture(),
    newFile: (_) async => file,
    transcribe: transcribe,
  );

  Future<CallController> recordingWith(Transcriber transcribe) async {
    final controller = controllerWith(transcribe)..modelsReady();
    await controller.start();
    return controller;
  }

  test('Transcribing shows progress, then Transcript available with the markdown', () async {
    final done = Completer<File>();
    late void Function(double) report;
    final controller = await recordingWith(({required wav, required start, required onProgress}) {
      report = onProgress;
      return done.future;
    });

    await controller.stop();
    expect(controller.state, CallState.transcribing);
    expect(controller.canStart, isFalse);
    report(0.5);
    expect(controller.progress, 0.5);

    final md = File('${dir.path}/call.md')..writeAsStringSync('# Call');
    done.complete(md);
    await settle();

    expect(controller.state, CallState.transcriptAvailable);
    expect((controller.last as TranscriptAvailable).markdownPath, md.path);
    expect(controller.canStart, isTrue);
  });

  test('a failed transcription shows its error, writes no markdown and keeps Avvia', () async {
    final controller = await recordingWith(({required wav, required start, required onProgress}) async {
      throw TranscriptionError('Modelli non trovati: manca model_quantized.onnx');
    });

    await controller.stop();
    await settle();

    expect(controller.state, CallState.transcriptionFailed);
    expect(
      (controller.last as TranscriptionFailed).error,
      'Modelli non trovati: manca model_quantized.onnx',
    );
    expect(File('${dir.path}/call.md').existsSync(), isFalse);
    expect(controller.canStart, isTrue);
    expect(controller.closeWindow(), isTrue);
    expect(controller.state, CallState.closed);
  });

  test('Riprova transcribes the same audio again', () async {
    final wavs = <File>[];
    final starts = <DateTime>[];
    final controller = await recordingWith(({required wav, required start, required onProgress}) async {
      wavs.add(wav);
      starts.add(start);
      if (wavs.length == 1) throw TranscriptionError('Errore');
      return File('${dir.path}/call.md')..writeAsStringSync('# Call');
    });

    await controller.stop();
    await settle();
    expect(controller.state, CallState.transcriptionFailed);

    await controller.retryTranscription();

    expect(wavs, [file, file]);
    expect(starts[1], starts[0]);
    expect(controller.state, CallState.transcriptAvailable);
  });

  test('a new recording clears the outcome of the last transcription', () async {
    final controller = await recordingWith(({required wav, required start, required onProgress}) async {
      throw TranscriptionError('Errore');
    });
    await controller.stop();
    await settle();
    expect(controller.last, isNotNull);

    await controller.start();

    expect(controller.state, CallState.recording);
    expect(controller.last, isNull);
    await controller.stop();
  });

  test('closing the window while Transcribing is refused', () async {
    final controller = await recordingWith(({required wav, required start, required onProgress}) {
      return Completer<File>().future;
    });
    await controller.stop();

    expect(controller.closeWindow(), isFalse);
    expect(controller.state, CallState.transcribing);
  });

  test('a write that fails while recording makes Stop end in Transcription failed and keeps the WAV', () async {
    final captures = <AudioSource, FakeCapture>{};
    var transcriptions = 0;
    final controller = CallController(
      missingSources: () async => [],
      capture: (source) async => captures[source] = FakeCapture(),
      newFile: (_) async => _FullDiskFile(file),
      transcribe: ({required wav, required start, required onProgress}) async {
        transcriptions++;
        return wav;
      },
    );
    controller.modelsReady();
    await controller.start();
    await captures[AudioSource.microphone]!.send([1, 0]);
    await captures[AudioSource.pcAudio]!.send([2, 0]);

    await controller.stop();
    await settle();

    expect(controller.state, CallState.transcriptionFailed);
    expect(transcriptions, 0);
    expect((controller.last as TranscriptionFailed).error, contains('No space left on device'));
    expect(file.existsSync(), isTrue);
  });
}

/// A WAV file on a full disk: the header is written, every later write fails.
class _FullDiskFile implements File {
  _FullDiskFile(this._file);

  final File _file;

  @override
  Future<RandomAccessFile> open({FileMode mode = FileMode.read}) async =>
      _FullDiskRaf(await _file.open(mode: mode));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FullDiskRaf implements RandomAccessFile {
  _FullDiskRaf(this._raf);

  final RandomAccessFile _raf;
  var _writes = 0;

  @override
  Future<RandomAccessFile> writeFrom(List<int> buffer, [int start = 0, int? end]) async {
    if (++_writes > 1) throw const FileSystemException('No space left on device');
    return _raf.writeFrom(buffer, start, end);
  }

  @override
  Future<RandomAccessFile> close() async {
    await _raf.close();
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
