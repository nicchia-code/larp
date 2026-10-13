import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import '../models/model_download.dart' show modelsDirectory;
import 'audio_embedder.dart';
import 'audio_vocabulary.dart';
import 'onnx_runtime.dart';
import 'transcript_markdown.dart';
import 'word_segmentation.dart';

/// A transcription that failed. Its message is shown to the user in Italian.
class TranscriptionError implements Exception {
  TranscriptionError(this.message);

  final String message;

  @override
  String toString() => message;
}

// File names of the models, as downloaded by models/model_download.dart.
const _encoderFile = 'audio_encoder_quantized.onnx';
const _modelFile = 'model_quantized.onnx';
const _vocabularyWords = 'audio_vocabulary.tsv';
const _vocabularyVectors = 'audio_vocabulary.f32';

/// The ONNX Runtime library shipped with the app: lib/ next to the executable on Linux, Frameworks/ in the macOS app.
String onnxRuntimeLibrary() {
  final folder = File(Platform.resolvedExecutable).parent.path;
  return Platform.isMacOS ? '$folder/../Frameworks/libonnxruntime.dylib' : '$folder/lib/libonnxruntime.so';
}

/// Transcribes the call recorded in [wav] (left channel "Io", right channel "Altri") and writes its markdown
/// next to it, with the same base name. Reports progress in [0, 1]. Nothing is written when it fails.
///
/// The work runs in its own isolate, which loads the models: EmbeddingGemma 2 through ONNX Runtime and the vocabulary.
Future<File> transcribeCall({
  required File wav,
  required DateTime start,
  required void Function(double progress) onProgress,
}) async {
  final reply = ReceivePort();
  final result = Completer<String>();
  reply.listen((Object? message) {
    if (result.isCompleted) return;
    switch (message) {
      case {'progress': double progress}:
        onProgress(progress);
      case {'done': String path}:
        result.complete(path);
      case {'error': String text}:
        result.completeError(TranscriptionError(text));
      default:
        result.completeError(TranscriptionError('Trascrizione interrotta'));
    }
  });
  final job = _Job(
    wavPath: wav.path,
    start: start,
    modelsPath: modelsDirectory().path,
    libraryPath: onnxRuntimeLibrary(),
    reply: reply.sendPort,
  );
  try {
    await Isolate.spawn(_worker, job, onError: reply.sendPort, onExit: reply.sendPort);
    return File(await result.future);
  } finally {
    reply.close();
  }
}

/// Transcribes [wav] with the given [vocabulary] and [embed], writes the markdown next to it and returns it.
/// Progress goes from 0 to 1 over the two tracks.
Future<File> writeTranscript({
  required File wav,
  required DateTime start,
  required AudioVocabulary vocabulary,
  required Float32List Function(Float32List window) embed,
  required void Function(double progress) onProgress,
}) async {
  final tracks = <List<Sentence>>[];
  var length = Duration.zero;
  for (var channel = 0; channel < 2; channel++) {
    final samples = await readWavChannel(wav, channel);
    length = Duration(microseconds: samples.length * 1000000 ~/ Tuning.sampleRate);
    final words = recognizeWords(
      samples: samples,
      vocabulary: vocabulary,
      embed: embed,
      onProgress: (fraction) => onProgress((channel + fraction) / 2),
    );
    tracks.add(sentencesOf(words, speaker: channel == 0 ? 'Io' : 'Altri'));
  }
  final markdown = transcriptMarkdown(
    start: start,
    length: length,
    sentences: interleave(tracks[0], tracks[1]),
  );
  final file = File(wav.path.replaceFirst(RegExp(r'\.wav$'), '.md'));
  await file.writeAsString(markdown, encoding: utf8);
  onProgress(1);
  return file;
}

/// The samples of one channel of the call's stereo 16-bit WAV, as floats in [-1, 1].
Future<Float32List> readWavChannel(File wav, int channel) async {
  final file = await wav.open();
  try {
    final length = await file.length();
    final riff = length < 12 ? null : await _read(file, 0, 12);
    if (riff == null || _ascii(riff, 0, 4) != 'RIFF' || _ascii(riff, 8, 4) != 'WAVE') {
      throw TranscriptionError('File audio non valido: ${wav.uri.pathSegments.last}');
    }
    int? channels;
    int? rate;
    int? bits;
    int? dataStart;
    var dataSize = 0;
    var position = 12;
    while (dataStart == null && position + 8 <= length) {
      final chunk = await _read(file, position, 8);
      final id = _ascii(chunk, 0, 4);
      final size = ByteData.sublistView(chunk).getUint32(4, Endian.little);
      if (id == 'fmt ') {
        final fmt = ByteData.sublistView(await _read(file, position + 8, min(size, 16)));
        channels = fmt.getUint16(2, Endian.little);
        rate = fmt.getUint32(4, Endian.little);
        bits = fmt.getUint16(14, Endian.little);
      } else if (id == 'data') {
        dataStart = position + 8;
        dataSize = size;
      }
      position += 8 + size + size % 2;
    }
    if (dataStart == null || channels != 2 || rate != Tuning.sampleRate || bits != 16) {
      throw TranscriptionError('Formato audio non supportato: serve stereo 16 kHz a 16 bit');
    }
    // A file cut short (the app stopped while recording) keeps the data it has.
    if (dataSize == 0 || dataStart + dataSize > length) dataSize = length - dataStart;
    final frames = dataSize ~/ 4;
    final samples = Float32List(frames);
    const framesPerRead = 65536;
    for (var first = 0; first < frames; first += framesPerRead) {
      final count = min(framesPerRead, frames - first);
      final bytes = ByteData.sublistView(await _read(file, dataStart + first * 4, count * 4));
      for (var i = 0; i < count; i++) {
        samples[first + i] = bytes.getInt16(i * 4 + channel * 2, Endian.little) / 32768.0;
      }
    }
    return samples;
  } finally {
    await file.close();
  }
}

class _Job {
  _Job({
    required this.wavPath,
    required this.start,
    required this.modelsPath,
    required this.libraryPath,
    required this.reply,
  });

  final String wavPath;
  final DateTime start;
  final String modelsPath;
  final String libraryPath;
  final SendPort reply;
}

Future<void> _worker(_Job job) async {
  try {
    final file = await _transcribeWithModels(job);
    job.reply.send({'done': file.path});
  } on TranscriptionError catch (e) {
    job.reply.send({'error': e.message});
  } catch (e) {
    job.reply.send({'error': 'Trascrizione non riuscita: $e'});
  }
}

Future<File> _transcribeWithModels(_Job job) async {
  final models = Directory(job.modelsPath);
  final encoderPath = '${models.path}/$_encoderFile';
  final modelPath = '${models.path}/$_modelFile';
  final words = File('${models.path}/$_vocabularyWords');
  final vectors = File('${models.path}/$_vocabularyVectors');
  for (final path in [encoderPath, modelPath, words.path, vectors.path]) {
    if (!File(path).existsSync()) {
      throw TranscriptionError('Modelli non trovati: manca ${File(path).uri.pathSegments.last}');
    }
  }
  final vocabulary = await AudioVocabulary.load(tsv: words, binary: vectors);
  final runtime = OnnxRuntime.open(job.libraryPath);
  final coreMl = Platform.isMacOS;
  final encoder = runtime.openSession(encoderPath, coreMl: coreMl);
  final model = runtime.openSession(modelPath, coreMl: coreMl);
  try {
    final embedder = AudioEmbedder(encoder: encoder, model: model);
    var reported = -1;
    return await writeTranscript(
      wav: File(job.wavPath),
      start: job.start,
      vocabulary: vocabulary,
      embed: embedder.embed,
      onProgress: (progress) {
        final percent = (progress * 100).floor();
        if (percent == reported) return;
        reported = percent;
        job.reply.send({'progress': percent / 100});
      },
    );
  } finally {
    encoder.close();
    model.close();
    runtime.close();
  }
}

Future<Uint8List> _read(RandomAccessFile file, int position, int count) async {
  await file.setPosition(position);
  final bytes = await file.read(count);
  if (bytes.length != count) throw TranscriptionError('File audio troncato');
  return bytes;
}

String _ascii(Uint8List bytes, int offset, int count) => String.fromCharCodes(bytes, offset, offset + count);
