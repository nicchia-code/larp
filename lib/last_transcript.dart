import 'dart:io';

import 'package:flutter/material.dart';

/// Opens [path] with the system's default application.
Future<void> openWithDefaultApp(String path) async {
  // ponytail: no url_launcher; xdg-open on Linux, open on macOS.
  final result = await Process.run(
    Platform.isMacOS ? 'open' : 'xdg-open',
    [path],
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      Platform.isMacOS ? 'open' : 'xdg-open',
      [path],
      '${result.stderr}',
      result.exitCode,
    );
  }
}

/// Esito dell'ultima trascrizione mostrato nella finestra.
sealed class LastTranscript {
  const LastTranscript();
}

/// Ultima trascrizione pronta: nome del markdown e pulsante "Apri".
final class TranscriptAvailable extends LastTranscript {
  const TranscriptAvailable(this.markdownPath);

  final String markdownPath;
}

/// Ultima trascrizione fallita: messaggio d'errore e pulsante "Riprova".
final class TranscriptionFailed extends LastTranscript {
  const TranscriptionFailed(this.error);

  final String error;
}

class LastTranscriptView extends StatelessWidget {
  const LastTranscriptView({
    super.key,
    required this.last,
    required this.onRetry,
    this.openFile = openWithDefaultApp,
  });

  /// Null before the first transcription: shows "Nessuna call trascritta".
  final LastTranscript? last;
  final VoidCallback onRetry;
  final Future<void> Function(String path) openFile;

  @override
  Widget build(BuildContext context) {
    return switch (last) {
      null => const Text('Nessuna call trascritta'),
      TranscriptAvailable(:final markdownPath) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ultima trascrizione pronta'),
            Text(markdownPath.split('/').last),
            ElevatedButton(
              onPressed: () => openFile(markdownPath),
              child: const Text('Apri'),
            ),
          ],
        ),
      TranscriptionFailed(:final error) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Trascrizione fallita'),
            Text(error),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Riprova'),
            ),
          ],
        ),
    };
  }
}
