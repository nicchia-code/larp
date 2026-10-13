import 'package:call_to_record/last_transcript.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('transcript available shows file name and Apri opens it',
      (tester) async {
    String? opened;
    await tester.pumpWidget(MaterialApp(
      home: LastTranscriptView(
        last: const TranscriptAvailable(
            '/home/u/CallToRecord/2026-10-13_17-51-00.md'),
        onRetry: () => fail('Riprova must not be shown'),
        openFile: (path) async => opened = path,
      ),
    ));

    expect(find.text('2026-10-13_17-51-00.md'), findsOneWidget);
    expect(find.text('Riprova'), findsNothing);
    await tester.tap(find.text('Apri'));
    expect(opened, '/home/u/CallToRecord/2026-10-13_17-51-00.md');
  });

  testWidgets('transcription failed shows error and Riprova calls retry',
      (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: LastTranscriptView(
        last: const TranscriptionFailed('Modello non trovato'),
        onRetry: () => retried = true,
        openFile: (_) async => fail('Apri must not be shown'),
      ),
    ));

    expect(find.text('Modello non trovato'), findsOneWidget);
    expect(find.text('Apri'), findsNothing);
    await tester.tap(find.text('Riprova'));
    expect(retried, isTrue);
  });

  testWidgets('no transcription yet shows Nessuna call trascritta only', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LastTranscriptView(
        last: null,
        onRetry: () => fail('Riprova must not be shown'),
      ),
    ));

    expect(find.text('Nessuna call trascritta'), findsOneWidget);
    expect(find.text('Apri'), findsNothing);
    expect(find.text('Riprova'), findsNothing);
  });
}
