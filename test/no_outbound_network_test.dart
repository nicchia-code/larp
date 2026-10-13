import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Network APIs. Audio and transcripts must never reach them.
final _networkApi = RegExp(
  r'\bHttpClient\b|\bWebSocket\b|\bSocket\b|package:http/|package:dio/'
  r'|package:web_socket_channel/|\bDio\(',
);

// Files allowed to use the network: only the model download (Task aj8aded1).
// ponytail: static check by API name; add the download file here when it lands.
const _networkAllowed = <String>{'lib/models/model_download.dart'};

void main() {
  test('network API detection works', () {
    expect(_networkApi.hasMatch('final c = HttpClient();'), isTrue);
    expect(_networkApi.hasMatch("import 'package:dio/dio.dart';"), isTrue);
    expect(_networkApi.hasMatch('final s = RawSocketThing();'), isFalse);
  });

  test('audio and transcripts never leave the PC', () {
    final offenders = <String>[];
    for (final file
        in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = file.path;
      if (!path.endsWith('.dart') || _networkAllowed.contains(path)) continue;
      if (_networkApi.hasMatch(file.readAsStringSync())) offenders.add(path);
    }
    expect(offenders, isEmpty);
  });
}
