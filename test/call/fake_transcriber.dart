import 'dart:async';
import 'dart:io';

/// A transcriber that never finishes, so the controller stays in Transcribing.
Future<File> pendingTranscription({
  required File wav,
  required DateTime start,
  required void Function(double progress) onProgress,
}) => Completer<File>().future;
