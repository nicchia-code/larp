import 'dart:math';
import 'dart:typed_data';

import 'audio_features.dart';
import 'onnx_runtime.dart';

/// Dimension of EmbeddingGemma 2's sentence embedding, and of each vector of the audio vocabulary.
const embeddingDimension = 768;

const _audioDimension = 512;

// Token ids of EmbeddingGemma 2's tokenizer: <bos>, <eos>, <|audio>, <|audio|> and <audio|>.
const _bos = 2;
const _eos = 1;
const _boa = 256000;
const _audioToken = 258881;
const _eoa = 258883;

/// The audio path of EmbeddingGemma 2 (encoder and model, int8), as the vocabulary builder runs it:
/// a mono 16 kHz window becomes a unit vector of [embeddingDimension] values.
class AudioEmbedder {
  AudioEmbedder({required this.encoder, required this.model});

  final OnnxSession encoder;
  final OnnxSession model;

  Float32List embed(Float32List window) {
    final features = melFeatures(window);
    final tokens = audioTokenCount(features.valid);
    if (tokens == 0) throw StateError('finestra troppo corta: nessun frame audio');
    final frames = features.frames;
    final audio = encoder.run({
      'input_features': OnnxTensor.float([1, frames, melBands], features.values),
      'input_features_mask': OnnxTensor.bool([1, frames], features.valid),
    }, 'audio_features');
    if (audio.length != tokens * _audioDimension) {
      throw StateError('encoder audio: ${audio.length} valori, attesi ${tokens * _audioDimension}');
    }
    final ids = Int64List(tokens + 4)
      ..[0] = _bos
      ..[1] = _boa
      ..[tokens + 2] = _eoa
      ..[tokens + 3] = _eos;
    ids.fillRange(2, tokens + 2, _audioToken);
    final vector = model.run({
      'input_ids': OnnxTensor.int64([1, ids.length], ids),
      'attention_mask': OnnxTensor.int64([1, ids.length], Int64List(ids.length)..fillRange(0, ids.length, 1)),
      'image_features': OnnxTensor.float([0, _audioDimension], Float32List(0)),
      'video_features': OnnxTensor.float([0, _audioDimension], Float32List(0)),
      'audio_features': OnnxTensor.float([tokens, _audioDimension], audio),
    }, 'sentence_embedding');
    if (vector.length != embeddingDimension) {
      throw StateError('embedding di ${vector.length} valori, attesi $embeddingDimension');
    }
    var norm = 0.0;
    for (final v in vector) {
      norm += v * v;
    }
    norm = sqrt(norm);
    return Float32List.fromList([for (final v in vector) v / norm]);
  }
}
