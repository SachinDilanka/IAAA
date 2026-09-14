const fs = require('fs');
const dsp = require('./flutter_mobile_app/web/dsp_constants.json');
const model = require('./flutter_mobile_app/web/sound_model_data.json');
const samples = JSON.parse(fs.readFileSync('./model-training/test_audio_samples.json', 'utf8'));

function _computeRFFT2048(signal, hann) {
  const N = 2048;
  const re = new Float32Array(N);
  const im = new Float32Array(N);

  for (let i = 0; i < N; i++) {
    let rev = 0, temp = i;
    for (let b = 0; b < 11; b++) {
      rev = (rev << 1) | (temp & 1);
      temp >>= 1;
    }
    re[rev] = signal[i] * (hann ? hann[i] : 1.0);
    im[rev] = 0;
  }

  for (let len = 2; len <= N; len <<= 1) {
    const half = len >> 1;
    const angle = -2 * Math.PI / len;
    const wStepRe = Math.cos(angle);
    const wStepIm = Math.sin(angle);

    for (let i = 0; i < N; i += len) {
      let wRe = 1.0, wIm = 0.0;
      for (let j = 0; j < half; j++) {
        const uRe = re[i + j];
        const uIm = im[i + j];
        const vRe = re[i + j + half] * wRe - im[i + j + half] * wIm;
        const vIm = re[i + j + half] * wIm + im[i + j + half] * wRe;

        re[i + j] = uRe + vRe;
        im[i + j] = uIm + vIm;
        re[i + j + half] = uRe - vRe;
        im[i + j + half] = uIm - vIm;

        const nextWRe = wRe * wStepRe - wIm * wStepIm;
        wIm = wRe * wStepIm + wIm * wStepRe;
        wRe = nextWRe;
      }
    }
  }

  const spec = new Float32Array(1025);
  for (let k = 0; k <= 1024; k++) {
    spec[k] = re[k] * re[k] + im[k] * im[k];
  }
  return spec;
}

function predict(rawSignal) {
  const signal = new Float32Array(rawSignal);
  const padded = new Float32Array(signal.length + 2048);
  for (let i = 0; i < 1024; i++) {
    padded[i] = signal[1024 - i];
  }
  padded.set(signal, 1024);
  for (let i = 0; i < 1024; i++) {
    padded[signal.length + 1024 + i] = signal[signal.length - 1 - i];
  }

  const hop = 512;
  const numFrames = Math.floor((padded.length - 2048) / hop) + 1;
  const mfccSum = new Float32Array(40);

  for (let f = 0; f < numFrames; f++) {
    const slice = padded.subarray(f * hop, f * hop + 2048);
    const spec = _computeRFFT2048(slice, dsp.hann_window);

    const mels = new Float32Array(128);
    for (let m = 0; m < 128; m++) {
      let sum = 0;
      const row = dsp.mel_basis[m];
      for (let k = 0; k <= 1024; k++) sum += row[k] * spec[k];
      mels[m] = sum;
    }

    const logMels = new Float32Array(128);
    let maxDb = -1e9;
    for (let m = 0; m < 128; m++) {
      const db = 10.0 * Math.log10(Math.max(1e-10, mels[m]));
      logMels[m] = db;
      if (db > maxDb) maxDb = db;
    }
    const minDb = maxDb - 80.0;
    for (let m = 0; m < 128; m++) {
      if (logMels[m] < minDb) logMels[m] = minDb;
    }

    for (let i = 0; i < 40; i++) {
      let dSum = 0;
      const dRow = dsp.dct_basis[i];
      for (let m = 0; m < 128; m++) dSum += dRow[m] * logMels[m];
      mfccSum[i] += dSum;
    }
  }

  const mfccMean = new Float32Array(40);
  for (let i = 0; i < 40; i++) {
    mfccMean[i] = (mfccSum[i] / numFrames - model.mean[i]) / (model.std[i] || 1.0);
  }

  // Pure Dense Feedforward: 40 -> 512 -> 256 -> 128 -> 64 -> 13
  const h0 = new Float32Array(512);
  for (let j = 0; j < 512; j++) {
    let s = model.b0[j];
    for (let i = 0; i < 40; i++) s += mfccMean[i] * model.W0[i][j];
    h0[j] = s > 0 ? s : 0;
  }

  const h1 = new Float32Array(256);
  for (let j = 0; j < 256; j++) {
    let s = model.b1[j];
    for (let i = 0; i < 512; i++) s += h0[i] * model.W1[i][j];
    h1[j] = s > 0 ? s : 0;
  }

  const h2 = new Float32Array(128);
  for (let j = 0; j < 128; j++) {
    let s = model.b2[j];
    for (let i = 0; i < 256; i++) s += h1[i] * model.W2[i][j];
    h2[j] = s > 0 ? s : 0;
  }

  const h3 = new Float32Array(64);
  for (let j = 0; j < 64; j++) {
    let s = model.b3[j];
    for (let i = 0; i < 128; i++) s += h2[i] * model.W3[i][j];
    h3[j] = s > 0 ? s : 0;
  }

  const logits = new Float32Array(13);
  let maxL = -1e9;
  for (let j = 0; j < 13; j++) {
    let s = model.b4[j];
    for (let i = 0; i < 64; i++) s += h3[i] * model.W4[i][j];
    logits[j] = s;
    if (s > maxL) maxL = s;
  }

  let expSum = 0;
  const probs = new Float32Array(13);
  for (let j = 0; j < 13; j++) {
    probs[j] = Math.exp(logits[j] - maxL);
    expSum += probs[j];
  }
  for (let j = 0; j < 13; j++) probs[j] /= expSum;

  let bestIdx = 0, bestProb = 0;
  for (let j = 0; j < 13; j++) {
    if (probs[j] > bestProb) {
      bestProb = probs[j];
      bestIdx = j;
    }
  }

  return { class: model.classes[bestIdx], prob: bestProb, probs: Array.from(probs) };
}

for (const [name, data] of Object.entries(samples)) {
  const res = predict(data);
  console.log(`Input [${name.padEnd(12)}] -> Predicted: '${res.class.padEnd(16)}' (${(res.prob * 100).toFixed(1)}%)`);
}
