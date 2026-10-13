import 'dart:io';

import '../call/call_files.dart';

/// One file of the transcription models, downloaded to the models folder under its [name].
class ModelFile {
  const ModelFile(this.name, this.url, this.expectedBytes);

  final String name;
  final String url;

  /// Exact size of the published file; null while it is unknown, so the file can never be verified.
  final int? expectedBytes;

  /// True when [dir] holds this file with exactly [expectedBytes].
  bool isComplete(Directory dir) {
    final file = File('${dir.path}/$name');
    return expectedBytes != null && file.existsSync() && file.lengthSync() == expectedBytes;
  }
}

/// Base URL of the GitHub Release holding the audio vocabulary, set at build time:
/// `--dart-define=AUDIO_VOCABULARY_RELEASE_URL=<release download folder>`.
const audioVocabularyReleaseUrl = String.fromEnvironment('AUDIO_VOCABULARY_RELEASE_URL');

// The int8 variant of EmbeddingGemma 2 from Hugging Face, and the audio vocabulary.
// ponytail: file paths inside the Hugging Face repo assumed to sit under onnx/.
List<ModelFile> get modelFiles => [
  const ModelFile(
    'audio_encoder_quantized.onnx',
    'https://huggingface.co/onnx-community/embeddinggemma-2-ONNX/resolve/main/onnx/audio_encoder_quantized.onnx',
    249330,
  ),
  const ModelFile(
    'audio_encoder_quantized.onnx_data',
    'https://huggingface.co/onnx-community/embeddinggemma-2-ONNX/resolve/main/onnx/audio_encoder_quantized.onnx_data',
    340058624,
  ),
  const ModelFile(
    'model_quantized.onnx',
    'https://huggingface.co/onnx-community/embeddinggemma-2-ONNX/resolve/main/onnx/model_quantized.onnx',
    495165,
  ),
  const ModelFile(
    'model_quantized.onnx_data',
    'https://huggingface.co/onnx-community/embeddinggemma-2-ONNX/resolve/main/onnx/model_quantized.onnx_data',
    313724928,
  ),
  // ponytail: vocabulary sizes stay null until the vocabulary is generated and published; set them then.
  ModelFile('audio_vocabulary.tsv', _releaseFile('audio_vocabulary.tsv'), null),
  ModelFile('audio_vocabulary.f32', _releaseFile('audio_vocabulary.f32'), null),
];

String _releaseFile(String name) =>
    audioVocabularyReleaseUrl.isEmpty ? '' : '$audioVocabularyReleaseUrl/$name';

/// The models folder, inside the fixed calls folder.
Directory modelsDirectory() => Directory('${callsDirectory().path}/models');

/// True only when every file of [files] is in [dir] with its expected size: the models are present.
bool modelsComplete(List<ModelFile> files, Directory dir) => files.every((f) => f.isComplete(dir));

/// Downloader of the models into the models folder, the default of the controller.
ModelDownloader newModelDownloader({required void Function(int received, int total) onProgress}) =>
    ModelDownloader(files: modelFiles, dir: modelsDirectory(), onProgress: onProgress);

/// Downloads [files] into [dir], one after the other, reporting the bytes received out of the total.
///
/// Each file is written as `<name>.part`; once every file is complete, they replace the files in [dir] together.
/// [discard] removes the partial files, so a failed or abandoned download leaves the complete files it found as they were.
class ModelDownloader {
  ModelDownloader({
    required this.files,
    required this.dir,
    required this.onProgress,
    HttpClient? client,
  }) : _client = client ?? HttpClient();

  final List<ModelFile> files;
  final Directory dir;
  final void Function(int received, int total) onProgress;
  final HttpClient _client;
  bool _cancelled = false;
  final _parts = <(File, File)>[];

  /// Downloads every file. Throws when a file cannot be fetched or the download is cancelled.
  Future<void> run() async {
    for (final file in files) {
      if (file.expectedBytes == null) throw StateError('Dimensione attesa non nota per ${file.name}');
    }
    var total = 0;
    for (final file in files) {
      total += await _size(file.url);
    }
    await dir.create(recursive: true);
    var received = 0;
    onProgress(received, total);
    for (final file in files) {
      final part = File('${dir.path}/${file.name}.part');
      _parts.add((part, File('${dir.path}/${file.name}')));
      final sink = part.openWrite();
      try {
        final response = await (await _client.getUrl(Uri.parse(file.url))).close();
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          throw HttpException('HTTP ${response.statusCode} per ${file.name}', uri: Uri.parse(file.url));
        }
        await for (final chunk in response) {
          _check();
          sink.add(chunk);
          received += chunk.length;
          onProgress(received, total);
        }
        await sink.close();
      } catch (_) {
        await sink.close().catchError((_) {});
        rethrow;
      }
      if (await part.length() != file.expectedBytes) {
        throw HttpException('Dimensione di ${file.name} diversa da quella attesa', uri: Uri.parse(file.url));
      }
      _check();
    }
    for (final (part, target) in _parts) {
      await part.rename(target.path);
    }
    _parts.clear();
  }

  /// Stops the download: the pending [run] throws.
  void cancel() {
    _cancelled = true;
    _client.close(force: true);
  }

  /// Deletes the partial files this download wrote. The files in [dir] that were complete before the
  /// download stay as they were.
  void discard() {
    for (final (part, _) in _parts) {
      if (part.existsSync()) part.deleteSync();
    }
  }

  void _check() {
    if (_cancelled) throw const HttpException('Download annullato');
  }

  Future<int> _size(String url) async {
    if (url.isEmpty) throw StateError('URL del modello non configurato');
    final request = await _client.openUrl('HEAD', Uri.parse(url));
    final response = await request.close();
    await response.drain<void>();
    if (response.statusCode != HttpStatus.ok || response.contentLength < 0) {
      throw HttpException('Dimensione non disponibile per $url', uri: Uri.parse(url));
    }
    return response.contentLength;
  }
}
