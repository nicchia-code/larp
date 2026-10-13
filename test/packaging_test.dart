import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The app opens ONNX Runtime where the bundles put it (onnxRuntimeLibrary in lib/transcription/transcribe_call.dart):
// lib/libonnxruntime.so next to the executable on Linux, Frameworks/libonnxruntime.dylib in the macOS app.
void main() {
  test('Linux bundle installs ONNX Runtime as lib/libonnxruntime.so', () {
    final cmake = File('linux/CMakeLists.txt').readAsStringSync();
    final dart = File('lib/transcription/transcribe_call.dart').readAsStringSync();
    expect(dart, contains('/lib/libonnxruntime.so'));
    expect(
      cmake,
      contains('install(FILES "\${ONNXRUNTIME_LIBRARY}" DESTINATION "\${INSTALL_BUNDLE_LIB_DIR}"'),
    );
    expect(cmake, contains('/third_party/onnxruntime/linux/libonnxruntime.so"'));
  });

  test('macOS app embeds ONNX Runtime in Frameworks/, signed on copy', () {
    final dart = File('lib/transcription/transcribe_call.dart').readAsStringSync();
    final project = File('macos/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(dart, contains('/../Frameworks/libonnxruntime.dylib'));
    expect(
      project,
      contains('path = ../third_party/onnxruntime/macos/libonnxruntime.dylib;'),
    );
    expect(
      project,
      contains('/* libonnxruntime.dylib in Bundle Framework */ = {isa = PBXBuildFile;'),
    );
    expect(project, contains('ATTRIBUTES = (CodeSignOnCopy, );'));
    expect(
      RegExp(r'files = \([^)]*libonnxruntime\.dylib in Bundle Framework[^)]*\);\s*name = "Bundle Framework";')
          .hasMatch(project),
      isTrue,
    );
  });
}
