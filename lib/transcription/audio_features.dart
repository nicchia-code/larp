import 'dart:math';
import 'dart:typed_data';

/// Log-mel features as EmbeddingGemma 2's audio encoder expects them (transformers' Gemma4AudioFeatureExtractor):
/// 16 kHz mono, 20 ms periodic Hann frames every 10 ms, 128 HTK mel bands from 0 to 8 kHz, log(mel + 0.001).
const melBands = 128;

const _frameLength = 320;
const _hopLength = 160;
const _fftLength = 512;
const _fftBins = _fftLength ~/ 2 + 1;
const _maxFrequency = 8000.0;
const _melFloor = 0.001;
const _padMultiple = 128;
const _leftPad = _frameLength ~/ 2;

class AudioFeatures {
  AudioFeatures({required this.values, required this.valid});

  /// Row-major [frames x melBands]; the rows of invalid frames are zero.
  final Float32List values;

  /// One entry per frame: 1 when the frame's last sample is real audio.
  final Uint8List valid;

  int get frames => valid.length;
}

/// Computes the features of a mono 16 kHz waveform in [-1, 1].
AudioFeatures melFeatures(Float32List wave) {
  final length = wave.length;
  // The processor pads the waveform to a multiple of 128 samples; the semicausal padding adds 160 zeros in front.
  final padded = (length + _padMultiple - 1) ~/ _padMultiple * _padMultiple;
  final total = _leftPad + padded;
  final frames = total < _frameLength + 1 ? 0 : (total - _frameLength - 1) ~/ _hopLength + 1;
  final values = Float32List(frames * melBands);
  final valid = Uint8List(frames);
  final re = Float64List(_fftLength);
  final im = Float64List(_fftLength);
  final magnitude = Float64List(_fftBins);
  for (var i = 0; i < frames; i++) {
    // The mask sample is the last one of the frame's 321-sample analysis window.
    final validFrame = i * _hopLength + _frameLength - _leftPad < length;
    valid[i] = validFrame ? 1 : 0;
    if (!validFrame) continue;
    final first = i * _hopLength - _leftPad;
    for (var j = 0; j < _fftLength; j++) {
      final r = first + j;
      re[j] = j < _frameLength && r >= 0 && r < length ? wave[r] * _window[j] : 0;
      im[j] = 0;
    }
    _fft(re, im);
    for (var k = 0; k < _fftBins; k++) {
      magnitude[k] = sqrt(re[k] * re[k] + im[k] * im[k]);
    }
    for (var b = 0; b < melBands; b++) {
      final weights = _melWeights[b];
      final from = _melFirstBin[b];
      var mel = 0.0;
      for (var w = 0; w < weights.length; w++) {
        mel += magnitude[from + w] * weights[w];
      }
      values[i * melBands + b] = log(mel + _melFloor);
    }
  }
  return AudioFeatures(values: values, valid: valid);
}

/// Audio placeholder tokens for a frame mask: two stride-2 convolutions, as the processor simulates them.
int audioTokenCount(Uint8List valid) {
  var count = 0;
  for (var i = 0; i < valid.length; i += 4) {
    count += valid[i];
  }
  return count;
}

// Periodic Hann window of 320 samples (numpy hanning(321)[:320]).
final _window = Float64List.fromList([
  for (var n = 0; n < _frameLength; n++) 0.5 - 0.5 * cos(2 * pi * n / _frameLength),
]);

// HTK mel filter bank as transformers builds it: triangles between 130 mel-spaced points, linear in Hz
// over the 257 FFT bins. Each band keeps only its non-zero bins, starting at _melFirstBin[b].
final _melFirstBin = Int32List(melBands);
final List<Float64List> _melWeights = _buildMelFilters();

List<Float64List> _buildMelFilters() {
  double melOf(double hz) => 2595 * log(1 + hz / 700) / ln10;
  double hzOf(double mel) => 700 * (pow(10, mel / 2595) - 1);
  final melMax = melOf(_maxFrequency);
  final points = [for (var i = 0; i < melBands + 2; i++) hzOf(melMax * i / (melBands + 1))];
  final filters = <Float64List>[];
  for (var b = 0; b < melBands; b++) {
    final weights = [
      for (var k = 0; k < _fftBins; k++) _triangle(k * _maxFrequency / (_fftBins - 1), points, b),
    ];
    final first = weights.indexWhere((w) => w > 0);
    if (first < 0) {
      filters.add(Float64List(0));
      continue;
    }
    final last = weights.lastIndexWhere((w) => w > 0);
    _melFirstBin[b] = first;
    filters.add(Float64List.fromList(weights.sublist(first, last + 1)));
  }
  return filters;
}

double _triangle(double hz, List<double> points, int b) {
  final rising = (hz - points[b]) / (points[b + 1] - points[b]);
  final falling = (points[b + 2] - hz) / (points[b + 2] - points[b + 1]);
  return max(0.0, min(rising, falling));
}

// Radix-2 FFT of size _fftLength, in place.
final _bitReverse = () {
  const bits = 9; // log2(_fftLength)
  final table = Int32List(_fftLength);
  for (var i = 0; i < _fftLength; i++) {
    var r = 0;
    for (var b = 0; b < bits; b++) {
      r = (r << 1) | ((i >> b) & 1);
    }
    table[i] = r;
  }
  return table;
}();

final _twiddleRe = Float64List.fromList([
  for (var k = 0; k < _fftLength ~/ 2; k++) cos(-2 * pi * k / _fftLength),
]);
final _twiddleIm = Float64List.fromList([
  for (var k = 0; k < _fftLength ~/ 2; k++) sin(-2 * pi * k / _fftLength),
]);

void _fft(Float64List re, Float64List im) {
  for (var i = 0; i < _fftLength; i++) {
    final j = _bitReverse[i];
    if (j > i) {
      final tr = re[i];
      re[i] = re[j];
      re[j] = tr;
      final ti = im[i];
      im[i] = im[j];
      im[j] = ti;
    }
  }
  for (var size = 2; size <= _fftLength; size <<= 1) {
    final half = size >> 1;
    final stride = _fftLength ~/ size;
    for (var start = 0; start < _fftLength; start += size) {
      for (var k = 0; k < half; k++) {
        final wr = _twiddleRe[k * stride];
        final wi = _twiddleIm[k * stride];
        final a = start + k;
        final b = a + half;
        final tr = re[b] * wr - im[b] * wi;
        final ti = re[b] * wi + im[b] * wr;
        re[b] = re[a] - tr;
        im[b] = im[a] - ti;
        re[a] += tr;
        im[a] += ti;
      }
    }
  }
}
