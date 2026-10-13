import 'dart:io';

import 'package:call_to_record/call/audio_sources.dart';
import 'package:call_to_record/call/call_controller.dart';
import 'package:call_to_record/call/call_screen.dart';
import 'package:call_to_record/models/model_download.dart';
import 'package:call_to_record/transcription/transcribe_call.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_capture.dart';
import 'fake_transcriber.dart';

CallController _controllerWith(List<AudioSource> missing) => CallController(
  missingSources: () async => missing,
  capture: (_) async => FakeCapture(),
  newFile: (_) async => File('${Directory.systemTemp.path}/call_screen_test.wav'),
  transcribe: pendingTranscription,
);

void main() {
  test('models.READY moves Waiting for models to Ready', () {
    final controller = _controllerWith([]);
    expect(controller.state, CallState.waitingForModels);
    expect(controller.canStart, isFalse);

    controller.modelsReady();

    expect(controller.state, CallState.ready);
    expect(controller.canStart, isTrue);
  });

  test('a completed download emits models.READY: Waiting for models moves to Ready', () async {
    final controller = CallController(
      newDownloader: ({required onProgress}) => ModelDownloader(
        files: const [],
        dir: Directory.systemTemp.createTempSync('models_ready_'),
        onProgress: onProgress,
      ),
      transcribe: pendingTranscription,
    );
    expect(controller.state, CallState.waitingForModels);

    await controller.downloadModels();

    expect(controller.state, CallState.ready);
    expect(controller.canStart, isTrue);
  });

  test('user.CLOSE_WINDOW moves Waiting for models to Closed', () {
    final controller = _controllerWith([]);

    expect(controller.closeWindow(), isTrue);

    expect(controller.state, CallState.closed);
    controller.modelsReady();
    expect(controller.state, CallState.closed);
  });

  test('user.START records only when both sources are available', () async {
    final controller = _controllerWith([])..modelsReady();

    await controller.start();

    expect(controller.state, CallState.recording);
    await controller.stop();
  });

  test('user.START with a missing source stays Ready and names it', () async {
    final controller = _controllerWith([AudioSource.pcAudio])..modelsReady();

    await controller.start();

    expect(controller.state, CallState.ready);
    expect(controller.missing, [AudioSource.pcAudio]);
  });

  test('user.START with both sources missing stays Ready and names both', () async {
    final controller = _controllerWith([AudioSource.microphone, AudioSource.pcAudio])
      ..modelsReady();

    await controller.start();

    expect(controller.state, CallState.ready);
    expect(controller.missing, [AudioSource.microphone, AudioSource.pcAudio]);
  });

  test('user.CLOSE_WINDOW from Ready moves to Closed', () {
    final controller = _controllerWith([])..modelsReady();

    expect(controller.closeWindow(), isTrue);

    expect(controller.state, CallState.closed);
  });

  test('formatElapsed shows HH:MM:SS', () {
    expect(formatElapsed(const Duration(hours: 1, minutes: 2, seconds: 3)), '01:02:03');
    expect(formatElapsed(Duration.zero), '00:00:00');
  });

  testWidgets('Avvia is disabled until the models are ready', (tester) async {
    final controller = _controllerWith([]);
    await tester.pumpWidget(
      MaterialApp(home: CallScreen(controller: controller)),
    );

    expect(find.text('Avvia'), findsOneWidget);
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNull);

    controller.modelsReady();
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed, isNotNull);
  });

  testWidgets('a missing source is named on screen', (tester) async {
    final controller = _controllerWith([AudioSource.microphone])..modelsReady();
    await tester.pumpWidget(
      MaterialApp(home: CallScreen(controller: controller)),
    );

    await tester.tap(find.text('Avvia'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Microfono non disponibile'), findsOneWidget);
  });

  testWidgets('Ready shows Nessuna call trascritta before any transcription', (tester) async {
    final controller = _controllerWith([])..modelsReady();
    await tester.pumpWidget(
      MaterialApp(home: CallScreen(controller: controller)),
    );

    expect(find.text('Nessuna call trascritta'), findsOneWidget);
    expect(find.text('Riprova'), findsNothing);
  });

  testWidgets('a failed transcription stays on screen with Riprova when Avvia is refused',
      (tester) async {
    var missing = <AudioSource>[];
    final controller = CallController(
      missingSources: () async => missing,
      capture: (_) async => FakeCapture(),
      newFile: (_) async => File('${Directory.systemTemp.path}/call_screen_test.wav'),
      transcribe: ({required wav, required start, required onProgress}) async =>
          throw TranscriptionError('Modelli non trovati'),
    )..modelsReady();
    await tester.pumpWidget(
      MaterialApp(home: CallScreen(controller: controller)),
    );

    await tester.runAsync(() async {
      await controller.start();
      await controller.stop();
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(find.text('Trascrizione fallita'), findsOneWidget);
    expect(find.text('Modelli non trovati'), findsOneWidget);

    missing = [AudioSource.microphone];
    await tester.runAsync(() => controller.start());
    await tester.pump();

    expect(find.text('Microfono non disponibile'), findsOneWidget);
    expect(find.text('Trascrizione fallita'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
    expect(find.text('Avvia'), findsOneWidget);
  });
}
