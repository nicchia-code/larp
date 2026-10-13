import 'dart:async';

import 'package:call_to_record/call/audio_sources.dart';

/// A capture the test feeds by hand and ends either by stop or by crashing.
class FakeCapture implements CaptureProcess {
  final _data = StreamController<List<int>>();
  final _exit = Completer<void>();
  bool stopped = false;

  /// Delivers [bytes] and lets the event queue run.
  Future<void> send(List<int> bytes) async {
    _data.add(bytes);
    await Future<void>.delayed(Duration.zero);
  }

  /// The process ends on its own, as when a source disappears.
  void crash() => _end();

  @override
  Stream<List<int>> get pcm => _data.stream;

  @override
  Future<void> get exited => _exit.future;

  @override
  void stop() {
    stopped = true;
    _end();
  }

  void _end() {
    if (!_exit.isCompleted) _exit.complete();
    _data.close();
  }
}
