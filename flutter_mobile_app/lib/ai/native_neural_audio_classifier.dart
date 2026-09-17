import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/services.dart';

class ModelPrediction {
  final String label;
  final double probability;
  final Map<String, double> allProbabilities;

  ModelPrediction({
    required this.label,
    required this.probability,
    required this.allProbabilities,
  });
}

/// Pure Dart offline Deep Neural Network Audio Classifier (identical to Web audio_recognizer.js)
class NativeNeuralAudioClassifier {
  static final NativeNeuralAudioClassifier _instance = NativeNeuralAudioClassifier._internal();
  factory NativeNeuralAudioClassifier() => _instance;
  NativeNeuralAudioClassifier._internal();

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  List<double> _hannWindow = [];
  List<List<double>> _melBasis = [];
  List<List<double>> _dctBasis = [];

  List<String> _classes = [];
  List<double> _mean = [];
  List<double> _std = [];
  List<List<double>> _W0 = [];
  List<double> _b0 = [];
  List<List<double>> _W1 = [];
  List<double> _b1 = [];
  List<List<double>> _W2 = [];
  List<double> _b2 = [];
  List<List<double>> _W3 = [];
  List<double> _b3 = [];
  List<List<double>> _W4 = [];
  List<double> _b4 = [];

  Future<bool> loadModel() async {
    if (_isLoaded) return true;

    try {
      // 1. Load DSP Constants (Hann, Mel Basis, DCT Basis)
      final dspString = await rootBundle.loadString('assets/models/dsp_constants.json');
      final dspJson = jsonDecode(dspString) as Map<String, dynamic>;

      _hannWindow = (dspJson['hann_window'] as List).map((e) => (e as num).toDouble()).toList();
      _melBasis = (dspJson['mel_basis'] as List)
          .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
          .toList();
      _dctBasis = (dspJson['dct_basis'] as List)
          .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
          .toList();

      // 2. Load Deep Neural Net Weights & Normalization Parameters
      final modelString = await rootBundle.loadString('assets/models/sound_model_data.json');
      final modelJson = jsonDecode(modelString) as Map<String, dynamic>;

      _classes = (modelJson['classes'] as List).map((e) => e.toString()).toList();
      _mean = (modelJson['mean'] as List).map((e) => (e as num).toDouble()).toList();
      _std = (modelJson['std'] as List).map((e) => (e as num).toDouble()).toList();

      _W0 = (modelJson['W0'] as List)
          .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
          .toList();
      _b0 = (modelJson['b0'] as List).map((e) => (e as num).toDouble()).toList();

      _W1 = (modelJson['W1'] as List)
          .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
          .toList();
      _b1 = (modelJson['b1'] as List).map((e) => (e as num).toDouble()).toList();

      _W2 = (modelJson['W2'] as List)
          .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
          .toList();
      _b2 = (modelJson['b2'] as List).map((e) => (e as num).toDouble()).toList();

      _W3 = (modelJson['W3'] as List)
          .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
          .toList();
      _b3 = (modelJson['b3'] as List).map((e) => (e as num).toDouble()).toList();

      _W4 = (modelJson['W4'] as List)
          .map((row) => (row as List).map((e) => (e as num).toDouble()).toList())
          .toList();
      _b4 = (modelJson['b4'] as List).map((e) => (e as num).toDouble()).toList();

      _isLoaded = true;
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Run 2048-point RFFT matching the web audio_recognizer.js
  List<double> _rfft2048(List<double> signal) {
    const int N = 2048;
    final List<double> re = List<double>.filled(N, 0.0);
    final List<double> im = List<double>.filled(N, 0.0);

    for (int i = 0; i < N; i++) {
      int rev = 0, tmp = i;
      for (int b = 0; b < 11; b++) {
        rev = (rev << 1) | (tmp & 1);
        tmp >>= 1;
      }
      final double window = (i < _hannWindow.length) ? _hannWindow[i] : 1.0;
      re[rev] = signal[i] * window;
    }

    for (int len = 2; len <= N; len <<= 1) {
      final int half = len >> 1;
      final double ang = -2.0 * math.pi / len;
      final double wr = math.cos(ang), wi = math.sin(ang);
      for (int i = 0; i < N; i += len) {
        double cr = 1.0, ci = 0.0;
        for (int j = 0; j < half; j++) {
          final double ur = re[i + j], ui = im[i + j];
          final double vr = re[i + j + half] * cr - im[i + j + half] * ci;
          final double vi = re[i + j + half] * ci + im[i + j + half] * cr;
          re[i + j] = ur + vr;
          im[i + j] = ui + vi;
          re[i + j + half] = ur - vr;
          im[i + j + half] = ui - vi;
          final double ncr = cr * wr - ci * wi;
          ci = cr * wi + ci * wr;
          cr = ncr;
        }
      }
    }

    final List<double> spec = List<double>.filled(1025, 0.0);
    for (int k = 0; k <= 1024; k++) {
      spec[k] = re[k] * re[k] + im[k] * im[k];
    }
    return spec;
  }

  /// Resample arbitrary PCM audio stream to exact 16,000 Hz 1-second buffer
  List<double> resampleTo16k(List<double> input, int sampleRate) {
    if (sampleRate == 16000 && input.length >= 16000) {
      return input.sublist(0, 16000);
    }
    final List<double> out = List<double>.filled(16000, 0.0);
    final double step = input.length / 16000.0;
    for (int i = 0; i < 16000; i++) {
      final int startIdx = (i * step).floor();
      final int endIdx = math.min(input.length, ((i + 1) * step).floor());
      double sum = 0;
      int count = 0;
      for (int j = startIdx; j < endIdx; j++) {
        sum += input[j];
        count++;
      }
      out[i] = count > 0 ? (sum / count) : input[startIdx.clamp(0, input.length - 1)];
    }
    return out;
  }

  /// Classify 1-second 16kHz audio buffer using exact Deep Neural Net architecture
  ModelPrediction? predict(List<double> raw16k) {
    if (!_isLoaded || raw16k.isEmpty) return null;

    List<double> sig = List<double>.from(raw16k);
    if (sig.length > 16000) {
      sig = sig.sublist(0, 16000);
    } else if (sig.length < 16000) {
      sig.addAll(List<double>.filled(16000 - sig.length, 0.0));
    }

    // Reflect-pad 1024 on each side
    final List<double> pad = List<double>.filled(sig.length + 2048, 0.0);
    for (int i = 0; i < 1024; i++) {
      pad[i] = sig[1024 - i];
    }
    for (int i = 0; i < sig.length; i++) {
      pad[1024 + i] = sig[i];
    }
    for (int i = 0; i < 1024; i++) {
      pad[sig.length + 1024 + i] = sig[sig.length - 1 - i];
    }

    const int hop = 512;
    final int nFrames = ((pad.length - 2048) / hop).floor() + 1;
    final List<double> mfccSum = List<double>.filled(40, 0.0);

    for (int f = 0; f < nFrames; f++) {
      final slice = pad.sublist(f * hop, f * hop + 2048);
      final spec = _rfft2048(slice);

      // 128 Mel Filterbanks
      final List<double> mels = List<double>.filled(128, 0.0);
      for (int m = 0; m < 128; m++) {
        double s = 0.0;
        final row = _melBasis[m];
        for (int k = 0; k <= 1024; k++) {
          s += row[k] * spec[k];
        }
        mels[m] = s;
      }

      // Log Mel (dB) with dynamic range clamping
      final List<double> logM = List<double>.filled(128, 0.0);
      double maxDb = -1e9;
      for (int m = 0; m < 128; m++) {
        final double db = 10.0 * (math.log(math.max(1e-10, mels[m])) / math.ln10);
        logM[m] = db;
        if (db > maxDb) maxDb = db;
      }
      final double minDb = maxDb - 80.0;
      for (int m = 0; m < 128; m++) {
        if (logM[m] < minDb) logM[m] = minDb;
      }

      // DCT (MFCC 40 coefficients)
      for (int i = 0; i < 40; i++) {
        double d = 0.0;
        final row = _dctBasis[i];
        for (int m = 0; m < 128; m++) {
          d += row[m] * logM[m];
        }
        mfccSum[i] += d;
      }
    }

    // Standardize features (mean & std)
    final List<double> feat = List<double>.filled(40, 0.0);
    for (int i = 0; i < 40; i++) {
      feat[i] = (mfccSum[i] / nFrames - _mean[i]) / (_std[i] > 0 ? _std[i] : 1.0);
    }

    // 40 -> 512 -> 256 -> 128 -> 64 -> 13 Dense layers with ReLU
    double relu(double x) => x > 0.0 ? x : 0.0;

    // Layer 0: 40 -> 512
    final List<double> h0 = List<double>.filled(512, 0.0);
    for (int j = 0; j < 512; j++) {
      double s = _b0[j];
      for (int i = 0; i < 40; i++) {
        s += feat[i] * _W0[i][j];
      }
      h0[j] = relu(s);
    }

    // Layer 1: 512 -> 256
    final List<double> h1 = List<double>.filled(256, 0.0);
    for (int j = 0; j < 256; j++) {
      double s = _b1[j];
      for (int i = 0; i < 512; i++) {
        s += h0[i] * _W1[i][j];
      }
      h1[j] = relu(s);
    }

    // Layer 2: 256 -> 128
    final List<double> h2 = List<double>.filled(128, 0.0);
    for (int j = 0; j < 128; j++) {
      double s = _b2[j];
      for (int i = 0; i < 256; i++) {
        s += h1[i] * _W2[i][j];
      }
      h2[j] = relu(s);
    }

    // Layer 3: 128 -> 64
    final List<double> h3 = List<double>.filled(64, 0.0);
    for (int j = 0; j < 64; j++) {
      double s = _b3[j];
      for (int i = 0; i < 128; i++) {
        s += h2[i] * _W3[i][j];
      }
      h3[j] = relu(s);
    }

    // Layer 4: 64 -> 13 Logits
    final List<double> logits = List<double>.filled(13, 0.0);
    double maxL = -1e9;
    for (int j = 0; j < 13; j++) {
      double s = _b4[j];
      for (int i = 0; i < 64; i++) {
        s += h3[i] * _W4[i][j];
      }
      logits[j] = s;
      if (s > maxL) maxL = s;
    }

    // Softmax
    double expSum = 0.0;
    final List<double> probs = List<double>.filled(13, 0.0);
    for (int j = 0; j < 13; j++) {
      probs[j] = math.exp(logits[j] - maxL);
      expSum += probs[j];
    }
    for (int j = 0; j < 13; j++) {
      probs[j] /= (expSum > 0 ? expSum : 1.0);
    }

    int bestIdx = 0;
    double bestP = 0.0;
    final Map<String, double> allProbs = {};
    for (int j = 0; j < 13; j++) {
      final String cls = _classes[j];
      allProbs[cls] = probs[j];
      if (probs[j] > bestP) {
        bestP = probs[j];
        bestIdx = j;
      }
    }

    return ModelPrediction(
      label: _classes[bestIdx],
      probability: bestP,
      allProbabilities: allProbs,
    );
  }
}
