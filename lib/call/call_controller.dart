import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'audio_sources.dart';
import 'call_files.dart';
import 'recorder.dart';
import '../last_transcript.dart';
import '../models/model_download.dart';
import '../transcription/transcribe_call.dart';

/// Shown under Download fallito: the error text itself is for the developer, on stderr.
const _downloadFailedMessage = 'Il download dei modelli non è riuscito. Controlla la connessione e riprova.';

/// Call states of this part of the Model: Waiting for models, Ready, Recording, Transcribing, Transcript available,
/// Transcription failed, Closed.
enum CallState {
  waitingForModels,
  downloading,
  downloadFailed,
  ready,
  recording,
  transcribing,
  transcriptAvailable,
  transcriptionFailed,
  closed,
}

/// Transcribes the call recorded in [wav] that started at [start], reporting progress in [0, 1].
typedef Transcriber =
    Future<File> Function({
      required File wav,
      required DateTime start,
      required void Function(double progress) onProgress,
    });

/// True when every model file is on disk with its expected size.
bool _modelsOnDisk() => modelsComplete(modelFiles, modelsDirectory());

class CallController extends ChangeNotifier {
  CallController({
    Future<List<AudioSource>> Function()? missingSources,
    Future<CaptureProcess> Function(AudioSource source)? capture,
    Future<File> Function(DateTime start)? newFile,
    ModelDownloader Function({required void Function(int received, int total) onProgress})?
    newDownloader,
    Transcriber? transcribe,
    bool Function()? modelsPresent,
  }) : _missingSources = missingSources ?? missingAudioSources,
       _newFile = newFile ?? newCallFile,
       _newDownloader = newDownloader ?? newModelDownloader,
       _transcribe = transcribe ?? transcribeCall,
       _modelsPresent = modelsPresent ?? _modelsOnDisk,
       _capture = capture ?? startCapture;

  final Future<List<AudioSource>> Function() _missingSources;
  final Future<File> Function(DateTime start) _newFile;
  final ModelDownloader Function({required void Function(int received, int total) onProgress})
  _newDownloader;
  final Transcriber _transcribe;
  final bool Function() _modelsPresent;
  final Future<CaptureProcess> Function(AudioSource source) _capture;
  late CallRecorder _recorder;

  CallState _state = CallState.waitingForModels;
  List<AudioSource> _missing = const [];
  String? _startError;
  bool _starting = false;
  DateTime? _startedAt;
  AudioSource? _lost;
  Timer? _ticker;
  ModelDownloader? _downloader;
  int _downloadReceived = 0;
  int _downloadTotal = 0;
  String? _downloadError;
  File? _wav;
  double _progress = 0;
  LastTranscript? _last;

  CallState get state => _state;

  bool get canStart => _idle && !_starting;

  /// Ready, or a finished transcription: Avvia is available.
  bool get _idle =>
      _state == CallState.ready ||
      _state == CallState.transcriptAvailable ||
      _state == CallState.transcriptionFailed;

  /// Share of the transcription done, in [0, 1]; meaningful while Transcribing.
  double get progress => _progress;

  /// Outcome of the last transcription: the markdown or the error. Null before the first one.
  LastTranscript? get last => _last;

  /// Sources reported missing by the last user.START in Ready.
  List<AudioSource> get missing => _missing;

  /// Reason the last user.START in Ready did not start, when no source is named.
  String? get startError => _startError;

  /// Source whose capture ended during Recording: named once Transcribing starts.
  AudioSource? get lostSource => _lost;

  /// Bytes of the models downloaded so far and their total; meaningful while Downloading.
  int get downloadReceived => _downloadReceived;
  int get downloadTotal => _downloadTotal;

  /// Message in Italian of the last failed download; meaningful in Download failed. The error itself goes to stderr.
  String? get downloadError => _downloadError;

  /// Time since the recording started; meaningful while Recording.
  Duration get elapsed =>
      _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  /// Event models.FOUND or models.MISSING, checked at startup: Ready when every model file is
  /// complete, otherwise the download starts.
  Future<void> checkModels() async {
    if (_state != CallState.waitingForModels) return;
    if (_modelsPresent()) {
      modelsReady();
    } else {
      await downloadModels();
    }
  }

  /// Event models.READY: the models are present or have just been downloaded.
  void modelsReady() {
    if (_state != CallState.waitingForModels && _state != CallState.downloading) return;
    _state = CallState.ready;
    notifyListeners();
  }

  /// Event models.MISSING: downloads the models, showing progress. Completion moves to Ready;
  /// a failure moves to Download failed and discards what was downloaded.
  Future<void> downloadModels() async {
    if (_state != CallState.waitingForModels) return;
    await _download();
  }

  /// Event user.RETRY_DOWNLOAD in Download failed: downloads the models again from zero.
  Future<void> retryDownload() async {
    if (_state != CallState.downloadFailed) return;
    await _download();
  }

  Future<void> _download() async {
    _state = CallState.downloading;
    _downloadReceived = 0;
    _downloadTotal = 0;
    _downloadError = null;
    notifyListeners();
    final downloader = _newDownloader(
      onProgress: (received, total) {
        _downloadReceived = received;
        _downloadTotal = total;
        notifyListeners();
      },
    );
    _downloader = downloader;
    try {
      await downloader.run();
    } catch (e) {
      if (_state != CallState.downloading) return;
      downloader.discard();
      stderr.writeln('Download dei modelli fallito: $e');
      _downloadError = _downloadFailedMessage;
      _state = CallState.downloadFailed;
      notifyListeners();
      return;
    } finally {
      _downloader = null;
    }
    if (_state != CallState.downloading) return;
    modelsReady();
  }

  /// Event user.START in Ready: records only when both sources are available,
  /// otherwise stays in Ready and names the missing sources.
  Future<void> start() async {
    if (!canStart) return;
    _starting = true;
    _startError = null;
    try {
      final missing = await _missingSources();
      if (!_idle) return;
      _missing = missing;
      if (missing.isNotEmpty) return;
      final startedAt = DateTime.now();
      try {
        final file = await _newFile(startedAt);
        if (!_idle) return;
        _recorder = CallRecorder(capture: _capture, onSourceLost: _sourceLost);
        await _recorder.start(file);
        _startedAt = startedAt;
        _wav = file;
        _lost = null;
        _last = null;
        _state = CallState.recording;
      } on SourceUnavailable catch (e) {
        _missing = [e.source];
        return;
      } catch (e) {
        _startError = '$e';
        return;
      }
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) => notifyListeners());
    } finally {
      _starting = false;
      notifyListeners();
    }
  }

  /// Event user.STOP in Recording: closes the file, then transcribes it. A file that cannot be
  /// closed (a write failed, the disk is full) goes to Transcription failed without transcribing.
  Future<void> stop() async {
    if (_state != CallState.recording) return;
    _state = CallState.transcribing;
    _ticker?.cancel();
    notifyListeners();
    try {
      await _recorder.stop();
    } catch (error) {
      _lost = null;
      _last = TranscriptionFailed('$error');
      _state = CallState.transcriptionFailed;
      notifyListeners();
      return;
    }
    unawaited(_transcribeRecording());
  }

  /// Event user.RETRY_TRANSCRIPTION in Transcription failed: transcribes the same audio again.
  Future<void> retryTranscription() async {
    if (_state != CallState.transcriptionFailed) return;
    _state = CallState.transcribing;
    await _transcribeRecording();
  }

  /// Transcribing: shows the progress, then moves to Transcript available or to Transcription failed.
  Future<void> _transcribeRecording() async {
    _progress = 0;
    notifyListeners();
    try {
      final markdown = await _transcribe(wav: _wav!, start: _startedAt!, onProgress: _reportProgress);
      _last = TranscriptAvailable(markdown.path);
      _state = CallState.transcriptAvailable;
    } catch (error) {
      _last = TranscriptionFailed('$error');
      _state = CallState.transcriptionFailed;
    }
    _lost = null;
    notifyListeners();
  }

  void _reportProgress(double progress) {
    if ((progress * 100).floor() == (_progress * 100).floor()) return;
    _progress = progress;
    notifyListeners();
  }

  /// Event call.SOURCE_LOST in Recording: names the lost source and stops like user.STOP.
  void _sourceLost(AudioSource source) {
    if (_state != CallState.recording) return;
    _lost = source;
    unawaited(stop());
  }

  /// Event user.CLOSE_WINDOW. Returns false while Recording or Transcribing: the window stays open.
  bool closeWindow() {
    if (_state == CallState.recording || _state == CallState.transcribing) return false;
    if (_state == CallState.downloading) {
      _downloader?.cancel();
      _downloader?.discard();
    }
    if (_state == CallState.waitingForModels ||
        _state == CallState.downloading ||
        _state == CallState.downloadFailed ||
        _state == CallState.ready ||
        _state == CallState.transcriptAvailable ||
        _state == CallState.transcriptionFailed) {
      _state = CallState.closed;
      notifyListeners();
    }
    return true;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _downloader?.cancel();
    super.dispose();
  }
}
