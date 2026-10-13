import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'audio_sources.dart';

/// A source that could not start; nothing was recorded.
class SourceUnavailable implements Exception {
  SourceUnavailable(this.source);

  final AudioSource source;
}

/// Records both sources into one stereo WAV file, written while it grows.
class CallRecorder {
  CallRecorder({required this.capture, required this.onSourceLost});

  final Future<CaptureProcess> Function(AudioSource source) capture;
  final void Function(AudioSource source) onSourceLost;

  final _captures = <AudioSource, CaptureProcess>{};
  final _subscriptions = <StreamSubscription<List<int>>>[];
  late WavWriter _wav;
  bool _stopping = false;
  Future<void>? _stopped;

  /// Starts both captures into [file]. Throws [SourceUnavailable] and leaves no
  /// file behind when one source cannot start.
  Future<void> start(File file) async {
    final spawned = <AudioSource, CaptureProcess>{};
    try {
      for (final source in AudioSource.values) {
        try {
          spawned[source] = await capture(source);
        } on Exception {
          throw SourceUnavailable(source);
        }
      }
      _wav = await WavWriter.open(file);
    } catch (_) {
      for (final process in spawned.values) {
        process.stop();
      }
      rethrow;
    }
    _captures.addAll(spawned);
    for (final entry in spawned.entries) {
      final source = entry.key;
      _subscriptions.add(entry.value.pcm.listen((bytes) => _wav.add(source, bytes)));
      entry.value.exited.then((_) {
        if (!_stopping) onSourceLost(source);
      });
    }
  }

  /// Stops both captures and closes the file. Calls after the first return the same future.
  Future<void> stop() => _stopped ??= _stop();

  Future<void> _stop() async {
    _stopping = true;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    for (final process in _captures.values) {
      process.stop();
    }
    await Future.wait(_captures.values.map((process) => process.exited));
    await _wav.close();
  }
}

/// Writes a stereo 16 kHz 16-bit WAV: left = microphone ("Io"), right = PC audio ("Altri").
/// Frames are written as soon as both channels have them; the header is patched on close.
class WavWriter {
  WavWriter._(this._file);

  static const _sampleRate = 16000;

  final RandomAccessFile _file;
  final _pending = <AudioSource, List<int>>{
    AudioSource.microphone: <int>[],
    AudioSource.pcAudio: <int>[],
  };
  int _dataBytes = 0;
  Future<void> _writing = Future.value();
  Object? _writeError;

  static Future<WavWriter> open(File file) async {
    final raf = await file.open(mode: FileMode.write);
    await raf.writeFrom(_header(0));
    return WavWriter._(raf);
  }

  void add(AudioSource source, List<int> bytes) {
    _pending[source]!.addAll(bytes);
    final mic = _pending[AudioSource.microphone]!;
    final pc = _pending[AudioSource.pcAudio]!;
    final whole = min(mic.length, pc.length) ~/ 2 * 2;
    if (whole > 0) _emit(whole);
  }

  /// Interleaves [bytes] bytes of each channel (whole samples) and queues the write.
  void _emit(int bytes) {
    final mic = _pending[AudioSource.microphone]!;
    final pc = _pending[AudioSource.pcAudio]!;
    final out = Uint8List(bytes * 2);
    for (var i = 0; i < bytes; i += 2) {
      final o = i * 2;
      out[o] = mic[i];
      out[o + 1] = mic[i + 1];
      out[o + 2] = pc[i];
      out[o + 3] = pc[i + 1];
    }
    mic.removeRange(0, bytes);
    pc.removeRange(0, bytes);
    _dataBytes += out.length;
    _writing = _writing.then<void>((_) => _file.writeFrom(out)).catchError((Object error) {
      _writeError ??= error;
    });
  }

  /// Writes what is left, padding the shorter channel with silence, then fixes the header. Throws
  /// the first write error that happened while recording; the file is closed either way.
  Future<void> close() async {
    final mic = _pending[AudioSource.microphone]!;
    final pc = _pending[AudioSource.pcAudio]!;
    final longest = (max(mic.length, pc.length) + 1) ~/ 2 * 2;
    mic.addAll(List.filled(longest - mic.length, 0));
    pc.addAll(List.filled(longest - pc.length, 0));
    if (longest > 0) _emit(longest);
    try {
      await _writing;
      final error = _writeError;
      if (error != null) throw error;
      final dataBytes = _dataBytes;
      await _file.setPosition(0);
      await _file.writeFrom(_header(dataBytes));
    } finally {
      await _file.close();
    }
  }

  static Uint8List _header(int dataBytes) {
    final h = ByteData(44);
    void ascii(int offset, String text) {
      for (var i = 0; i < 4; i++) {
        h.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    h.setUint32(4, 36 + dataBytes, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    h.setUint32(16, 16, Endian.little);
    h.setUint16(20, 1, Endian.little); // PCM
    h.setUint16(22, 2, Endian.little); // channels
    h.setUint32(24, _sampleRate, Endian.little);
    h.setUint32(28, _sampleRate * 4, Endian.little); // byte rate
    h.setUint16(32, 4, Endian.little); // block align
    h.setUint16(34, 16, Endian.little); // bits per sample
    ascii(36, 'data');
    h.setUint32(40, dataBytes, Endian.little);
    return h.buffer.asUint8List();
  }
}
