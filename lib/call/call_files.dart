import 'dart:io';

/// The fixed folder of all call files: ~/CallToRecord.
Directory callsDirectory() {
  final home = Platform.environment['HOME'];
  if (home == null) throw StateError('HOME is not set');
  return Directory('$home/CallToRecord');
}

/// Creates the calls folder if missing and returns it.
Future<Directory> ensureCallsDirectory() => callsDirectory().create(recursive: true);

/// Base name shared by a call's .wav and .md files: start time as AAAA-MM-GG_HH-MM-SS.
String callBaseName(DateTime start) {
  String two(int n) => n.toString().padLeft(2, '0');
  final year = start.year.toString().padLeft(4, '0');
  return '$year-${two(start.month)}-${two(start.day)}_'
      '${two(start.hour)}-${two(start.minute)}-${two(start.second)}';
}

/// The .wav file of a call started at [start], in the calls folder.
Future<File> newCallFile(DateTime start) async {
  final dir = await ensureCallsDirectory();
  return File('${dir.path}/${callBaseName(start)}.wav');
}
