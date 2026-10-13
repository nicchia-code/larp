import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

/// The two sources of a call: the microphone ("Io") and the PC audio ("Altri").
enum AudioSource { microphone, pcAudio }

const _macosChannel = MethodChannel('call_to_record/audio_sources');

/// Sources that cannot be captured right now. Linux: the default source and the
/// default sink (whose monitor is the PC audio) must exist per pactl. macOS: see
/// [missingAudioSourcesOnMacOS].
Future<List<AudioSource>> missingAudioSources() async {
  if (Platform.isMacOS) return missingAudioSourcesOnMacOS();
  if (!Platform.isLinux) {
    throw UnsupportedError('audio source check is implemented on Linux and macOS only');
  }
  final microphone = await _pactl('get-default-source');
  final pcAudio = await _pactl('get-default-sink');
  return [
    if (microphone == null) AudioSource.microphone,
    if (pcAudio == null) AudioSource.pcAudio,
  ];
}

/// macOS: the native side (MainFlutterWindow.swift) checks that the default microphone
/// exists with its permission granted, and that the PC audio is capturable (Screen
/// Recording permission). It answers with the names of the missing sources.
Future<List<AudioSource>> missingAudioSourcesOnMacOS() async {
  final names =
      await _macosChannel.invokeListMethod<String>('missingSources') ?? [];
  return [for (final name in names) AudioSource.values.byName(name)];
}

Future<String?> _pactl(String command) async {
  try {
    final result = await Process.run('pactl', [command]);
    final output = (result.stdout as String).trim();
    return result.exitCode == 0 && output.isNotEmpty ? output : null;
  } on ProcessException {
    return null;
  }
}

/// Name of the default device, as pactl reports it now. Throws when pactl reports none.
Future<String> _defaultDevice(String command) async {
  final name = await _pactl(command);
  if (name == null) throw ProcessException('pactl', [command]);
  return name;
}

/// One running capture of a source: raw 16 kHz mono signed 16-bit little-endian PCM.
abstract class CaptureProcess {
  Stream<List<int>> get pcm;

  /// Completes when the capture ends, for any reason.
  Future<void> get exited;

  /// Ends the capture on purpose.
  void stop();
}

/// Starts capturing [source]. Throws [ProcessException] when it cannot start.
Future<CaptureProcess> startCapture(AudioSource source) async {
  if (Platform.isMacOS) return startCaptureOnMacOS(source);
  if (!Platform.isLinux) {
    throw UnsupportedError('audio capture is implemented on Linux and macOS only');
  }
  // Named at start, not @DEFAULT_*@: a capture stays on the device the call started with, so its
  // loss ends the process and raises call.SOURCE_LOST.
  final device = switch (source) {
    AudioSource.microphone => await _defaultDevice('get-default-source'),
    AudioSource.pcAudio => '${await _defaultDevice('get-default-sink')}.monitor',
  };
  final process = await Process.start('parecord', [
    '--raw',
    '--device=$device',
    '--rate=16000',
    '--channels=1',
    '--format=s16le',
  ]);
  process.stderr.drain<void>();
  return _ParecordCapture(process);
}

class _ParecordCapture implements CaptureProcess {
  _ParecordCapture(this._process);

  final Process _process;

  @override
  Stream<List<int>> get pcm => _process.stdout;

  @override
  Future<void> get exited => _process.exitCode;

  @override
  void stop() => _process.kill();
}

/// macOS: the native side (MainFlutterWindow.swift) captures the source and streams it as 16 kHz
/// mono PCM on the event channel `call_to_record/audio_pcm/<source>`. Cancelling that channel
/// stops the capture; the channel ending by itself means the source was lost.
Future<CaptureProcess> startCaptureOnMacOS(AudioSource source) async {
  final lost = Completer<void>();
  final pcm = StreamController<List<int>>();
  void end() {
    if (!lost.isCompleted) lost.complete();
    pcm.close();
  }

  final events = EventChannel('call_to_record/audio_pcm/${source.name}')
      .receiveBroadcastStream()
      .listen(
        (data) => pcm.add(data as Uint8List),
        onError: (Object error, StackTrace stack) => end(),
        onDone: end,
      );
  try {
    await _macosChannel.invokeMethod<void>('startCapture', source.name);
  } on PlatformException catch (e) {
    await events.cancel();
    throw ProcessException('ScreenCaptureKit', [source.name], e.message ?? e.code);
  }
  return _MacosCapture(events, pcm, lost);
}

class _MacosCapture implements CaptureProcess {
  _MacosCapture(this._events, this._pcm, this._lost);

  final StreamSubscription<dynamic> _events;
  final StreamController<List<int>> _pcm;
  final Completer<void> _lost;

  @override
  Stream<List<int>> get pcm => _pcm.stream;

  @override
  Future<void> get exited => _lost.future;

  @override
  void stop() {
    _events.cancel();
    if (!_lost.isCompleted) _lost.complete();
    _pcm.close();
  }
}
