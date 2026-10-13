import 'dart:io';
import 'dart:typed_data';

import 'package:call_to_record/call/audio_sources.dart';
import 'package:call_to_record/call/call_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_capture.dart';
import 'fake_transcriber.dart';

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  late Directory dir;
  late File file;
  late Map<AudioSource, FakeCapture> captures;
  late Set<AudioSource> unavailable;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('call_recording_test_');
    file = File('${dir.path}/call.wav');
    captures = {};
    unavailable = {};
  });

  tearDown(() => dir.deleteSync(recursive: true));

  CallController controllerWith() => CallController(
    missingSources: () async => [],
    capture: (source) async {
      if (unavailable.contains(source)) {
        throw const ProcessException('parecord', []);
      }
      return captures[source] = FakeCapture();
    },
    newFile: (_) async => file,
    transcribe: pendingTranscription,
  );

  Future<CallController> recording() async {
    final controller = controllerWith()..modelsReady();
    await controller.start();
    return controller;
  }

  List<int> pcmOf(File wav) => wav.readAsBytesSync().sublist(44);

  /// Records once, stops it, and lets its transcription finish: Avvia is available again.
  /// Then starts a second recording, which is left running.
  Future<CallController> afterFirstCall() async {
    var transcriptions = 0;
    var files = 0;
    final controller = CallController(
      missingSources: () async => [],
      capture: (source) async => captures[source] = FakeCapture(),
      newFile: (_) async => File('${dir.path}/call_${files++}.wav'),
      transcribe: ({required wav, required start, required onProgress}) =>
          transcriptions++ == 0
          ? Future.value(wav)
          : pendingTranscription(wav: wav, start: start, onProgress: onProgress),
    );
    controller.modelsReady();
    await controller.start();
    await controller.stop();
    await settle();
    expect(controller.state, CallState.transcriptAvailable);

    await controller.start();
    return controller;
  }

  test('both sources go to one stereo WAV: microphone left, PC audio right', () async {
    final controller = await recording();
    expect(controller.state, CallState.recording);

    await captures[AudioSource.microphone]!.send([1, 0, 2, 0]);
    await captures[AudioSource.pcAudio]!.send([3, 0, 4, 0]);
    await controller.stop();

    final bytes = file.readAsBytesSync();
    final header = ByteData.sublistView(bytes);
    expect(String.fromCharCodes(bytes.sublist(0, 4)), 'RIFF');
    expect(header.getUint16(22, Endian.little), 2);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), 8);
    expect(pcmOf(file), [1, 0, 3, 0, 2, 0, 4, 0]);
  });

  test('audio is on disk while recording, before the stop', () async {
    final controller = await recording();

    await captures[AudioSource.microphone]!.send([1, 0]);
    await captures[AudioSource.pcAudio]!.send([3, 0]);
    await settle();

    expect(file.lengthSync(), greaterThan(44));
    await controller.stop();
  });

  test('a shorter channel is padded with silence when stopped', () async {
    final controller = await recording();

    await captures[AudioSource.microphone]!.send([5, 0]);
    await controller.stop();

    expect(pcmOf(file), [5, 0, 0, 0]);
  });

  test('user.STOP closes the file and moves to Transcribing', () async {
    final controller = await recording();

    await controller.stop();

    expect(controller.state, CallState.transcribing);
    expect(captures[AudioSource.microphone]!.stopped, isTrue);
    expect(captures[AudioSource.pcAudio]!.stopped, isTrue);
    expect(controller.lostSource, isNull);
  });

  test('call.SOURCE_LOST stops, names the lost source and keeps what was recorded', () async {
    final controller = await recording();
    await captures[AudioSource.microphone]!.send([1, 0]);

    captures[AudioSource.pcAudio]!.crash();
    await settle();

    expect(controller.state, CallState.transcribing);
    expect(controller.lostSource, AudioSource.pcAudio);
    expect(captures[AudioSource.microphone]!.stopped, isTrue);
    expect(pcmOf(file), [1, 0, 0, 0]);
  });

  test('user.CLOSE_WINDOW while Recording or Transcribing keeps the window open', () async {
    final controller = await recording();

    expect(controller.closeWindow(), isFalse);
    expect(controller.state, CallState.recording);

    await controller.stop();
    expect(controller.state, CallState.transcribing);
    expect(controller.closeWindow(), isFalse);
  });

  test('a source that cannot start stays Ready, is named, and leaves no file', () async {
    unavailable.add(AudioSource.microphone);
    final controller = controllerWith()..modelsReady();

    await controller.start();

    expect(controller.state, CallState.ready);
    expect(controller.missing, [AudioSource.microphone]);
    expect(file.existsSync(), isFalse);
  });

  test('a second recording stops its own captures and closes its own file', () async {
    final controller = await afterFirstCall();
    expect(controller.state, CallState.recording);

    await captures[AudioSource.microphone]!.send([7, 0]);
    await controller.stop();

    expect(captures[AudioSource.microphone]!.stopped, isTrue);
    expect(captures[AudioSource.pcAudio]!.stopped, isTrue);
    expect(pcmOf(File('${dir.path}/call_1.wav')), [7, 0, 0, 0]);
  });

  test('a source lost in a second recording is named and stops it', () async {
    final controller = await afterFirstCall();

    captures[AudioSource.pcAudio]!.crash();
    await settle();

    expect(controller.state, CallState.transcribing);
    expect(controller.lostSource, AudioSource.pcAudio);
  });
}
