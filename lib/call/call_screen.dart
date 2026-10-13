import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';

import 'audio_sources.dart';
import 'call_controller.dart';
import '../last_transcript.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.controller});

  final CallController controller;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

/// Elapsed time as HH:MM:SS.
String formatElapsed(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
}

String _sourceName(AudioSource source) =>
    source == AudioSource.microphone ? 'Microfono' : 'Audio del PC';

String _mb(int bytes) => (bytes / 1e6).toStringAsFixed(1);

class _CallScreenState extends State<CallScreen> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onExitRequested: _onExitRequested);
  }

  Future<AppExitResponse> _onExitRequested() async {
    if (widget.controller.closeWindow()) return AppExitResponse.exit;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          widget.controller.state == CallState.transcribing
              ? 'Attendi la fine della trascrizione.'
              : 'Ferma la registrazione prima di chiudere.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return AppExitResponse.cancel;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Usa le cuffie: con le casse la voce degli altri finisce anche nella tua traccia.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (controller.state == CallState.downloading) ...[
                  const Text('Download dei modelli…'),
                  LinearProgressIndicator(
                    value: controller.downloadTotal > 0
                        ? controller.downloadReceived / controller.downloadTotal
                        : null,
                  ),
                  Text(
                    '${_mb(controller.downloadReceived)} MB di '
                    '${_mb(controller.downloadTotal)} MB',
                  ),
                ] else if (controller.state == CallState.downloadFailed) ...[
                  const Text('Download fallito'),
                  Text(controller.downloadError ?? ''),
                  ElevatedButton(onPressed: controller.retryDownload, child: const Text('Riprova')),
                ] else
                if (controller.state == CallState.recording) ...[
                  const Text('Registrazione in corso'),
                  Text(formatElapsed(controller.elapsed)),
                  ElevatedButton(onPressed: controller.stop, child: const Text('Ferma')),
                ] else ...[
                  if (controller.state == CallState.transcribing) ...[
                    const Text('Trascrizione in corso'),
                    LinearProgressIndicator(value: controller.progress),
                    Text('${(controller.progress * 100).floor()}%'),
                  ],
                  ElevatedButton(
                    onPressed: controller.canStart ? controller.start : null,
                    child: const Text('Avvia'),
                  ),
                ],
                for (final source in controller.missing)
                  Text('${_sourceName(source)} non disponibile'),
                if (controller.startError case final error?)
                  Text('Avvio non riuscito: $error'),
                if (controller.state == CallState.transcribing)
                  if (controller.lostSource case final lost?)
                    Text('${_sourceName(lost)} perso: registrazione fermata'),
                if (controller.state == CallState.ready ||
                    controller.state == CallState.transcriptAvailable ||
                    controller.state == CallState.transcriptionFailed)
                  LastTranscriptView(last: controller.last, onRetry: controller.retryTranscription),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
