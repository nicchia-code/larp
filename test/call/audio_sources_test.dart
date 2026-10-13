import 'dart:async';
import 'dart:io';

import 'package:call_to_record/call/audio_sources.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _channel = MethodChannel('call_to_record/audio_sources');
const _micPcm = EventChannel('call_to_record/audio_pcm/microphone');
const _pcAudioPcm = EventChannel('call_to_record/audio_pcm/pcAudio');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(_channel, null);
    messenger.setMockStreamHandler(_micPcm, null);
    messenger.setMockStreamHandler(_pcAudioPcm, null);
  });

  void nativeAnswers(List<String> missing) {
    messenger.setMockMethodCallHandler(_channel, (call) async {
      expect(call.method, 'missingSources');
      return missing;
    });
  }

  test('macOS: the names answered by the native side become the missing sources', () async {
    nativeAnswers(['microphone']);
    expect(await missingAudioSourcesOnMacOS(), [AudioSource.microphone]);

    nativeAnswers(['pcAudio']);
    expect(await missingAudioSourcesOnMacOS(), [AudioSource.pcAudio]);
  });

  test('macOS: nothing missing when the native side finds both sources', () async {
    nativeAnswers([]);
    expect(await missingAudioSourcesOnMacOS(), isEmpty);
  });

  test('macOS: both sources can be missing', () async {
    nativeAnswers(['microphone', 'pcAudio']);
    expect(await missingAudioSourcesOnMacOS(), [AudioSource.microphone, AudioSource.pcAudio]);
  });

  test('macOS: PCM from the native stream reaches the capture; stop cancels the native capture', () async {
    final started = <Object?>[];
    final cancelled = Completer<void>();
    late MockStreamHandlerEventSink events;
    messenger.setMockStreamHandler(
      _micPcm,
      MockStreamHandler.inline(
        onListen: (args, sink) => events = sink,
        onCancel: (args) => cancelled.complete(),
      ),
    );
    messenger.setMockMethodCallHandler(_channel, (call) async {
      expect(call.method, 'startCapture');
      started.add(call.arguments);
      return null;
    });

    final capture = await startCaptureOnMacOS(AudioSource.microphone);
    expect(started, ['microphone']);
    final firstChunk = capture.pcm.first;
    events.success(Uint8List.fromList([1, 2]));
    expect(await firstChunk, [1, 2]);

    capture.stop();
    await cancelled.future;
    await capture.exited;
  });

  test('macOS: the native stream ending by itself completes exited, so the source is lost', () async {
    late MockStreamHandlerEventSink events;
    messenger.setMockStreamHandler(
      _pcAudioPcm,
      MockStreamHandler.inline(onListen: (args, sink) => events = sink),
    );
    messenger.setMockMethodCallHandler(_channel, (call) async => null);

    final capture = await startCaptureOnMacOS(AudioSource.pcAudio);
    events.endOfStream();
    await capture.exited;
  });

  test('macOS: a capture the native side refuses throws, so the source is unavailable', () async {
    messenger.setMockStreamHandler(
      _pcAudioPcm,
      MockStreamHandler.inline(onListen: (args, sink) {}),
    );
    messenger.setMockMethodCallHandler(
      _channel,
      (call) async => throw PlatformException(code: 'unavailable', message: 'permission denied'),
    );

    await expectLater(
      startCaptureOnMacOS(AudioSource.pcAudio),
      throwsA(isA<ProcessException>()),
    );
  });
}
