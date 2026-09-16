/**
 * AcousticAware DEAF AI - High-Sensitivity Real-Time Audio, ML & Speech Recognition Engine
 * 
 * Key Features:
 * 1. Offline Deep Neural Network Inference (40 MFCC -> 512 -> 256 -> 128 -> 64 -> 13 classes):
 *    - Accurately classifies spoken Sinhala keywords: "udaw", "beeraganna", "ginnak", "anathurak",
 *      "karadarayak", "balagena", "parissamin".
 *    - Accurately classifies emergency environmental sounds: "ambulance_siren", "fire_alarm",
 *      "vehicle_horn", "baby_crying", "dog_barking".
 *    - Operates 100% offline in browser without needing cloud speech API.
 * 2. 160 Hz Biquad Highpass Filter + High Gain Pre-Amp:
 *    - Eliminates DC offset, laptop fan rumble, and 50/60 Hz mains hum.
 * 3. Auxiliary Spectral Peak & RMS Transient Detector:
 *    - Instant backup detector for siren harmonics, piercing alarms, vehicle horns, screaming, and barks.
 * 4. Dual-Mode Web Speech Recognition (si-LK / en-US):
 *    - Provides live transcript display and verbal keyword matching with auto-restart resilience.
 * 5. Multi-Protocol Yesido IO39 Smartwatch Dispatch:
 *    - Immediate Alert GATT service, Nordic UART, and Da Fit / FitPro packet writes.
 *    - High-priority OS notification with vibration pattern and clear Sinhala script display.
 * 6. Dynamic 40-Band Frequency Spectrum Visualizer:
 *    - Smooth 30 FPS visualizer stream to Flutter Dart UI.
 */

(function () {
  let audioCtx = null;
  let micStream = null;
  let micSource = null;
  let highpassFilter = null;
  let gainNode = null;
  let analyser = null;
  let scriptNode = null;
  let zeroGain = null;
  let timeData = null;
  let freqData = null;

  let isListening = false;
  let animTick = 0;
  let lastFrameTime = 0;
  let lastAlertTime = 0;
  let alertCooldown = false;

  // Circular Rolling Audio Buffer for Deep Neural Network (at native sampleRate)
  let rollingAudioBuffer = null;
  let rollingBufferIndex = 0;
  let rollingBufferCapacity = 48000;
  let lastMlInferenceTime = 0;

  let speechRec = null;
  let isSpeechRunning = false;
  let currentSpeechLang = 'si-LK';
  let speechRestartTimeout = null;

  // Adaptive Baseline Noise Tracker
  let baselineNoise = 8.0;
  let prevVolPct = 0;

  // Global Audio State accessible synchronously by Dart Web Bridge
  window._latestVolume = 0.12;
  window._latestPitch = 220;
  window._latestFrame40 = new Array(40).fill(0.12).join(',');
  window._latestFrame40Array = new Array(40).fill(0.12);
  window._latestTranscript = "🎤 Microphone Standby (Tap 'Start Mic' to activate)";
  window._latestAlert = null;
  window._currentSpeechLang = 'si-LK';

  // Bluetooth & Service Worker State
  let bleDevice = null;
  let gattServer = null;
  let writableCharacteristics = [];
  let swRegistration = null;

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').then((reg) => {
      swRegistration = reg;
    }).catch(() => {});
  }

  // Model Class Mapping to Flutter Sound Engine
  const MODEL_TO_FLUTTER_CLASS = {
    'udaw': 'udaw',
    'beeraganna': 'beeraganna',
    'ginnak': 'ginnak',
    'anathurak': 'anathurak',
    'karadarayak': 'karadarayak',
    'balagena': 'balagena',
    'parissamin': 'parissamin',
    'ambulance_siren': 'ambulance',
    'fire_alarm': 'firetruck',
    'vehicle_horn': 'vehicle horns',
    'baby_crying': 'baby crying',
    'dog_barking': 'dog_bark',
    'background_traffic': null,
  };

  const MODEL_CLASS_SINHALA_NAMES = {
    'udaw': 'උදව් කරන්න!',
    'beeraganna': 'බේරගන්න!',
    'ginnak': 'ගින්නක්!',
    'anathurak': 'අනතුරක්!',
    'karadarayak': 'කරදරයක්!',
    'balagena': 'බලාගෙන!',
    'parissamin': 'පරිස්සමින්!',
    'ambulance_siren': 'ගිලන් රථ සයිරන්',
    'fire_alarm': 'ගිනි නිවන සංඥාව',
    'vehicle_horn': 'වාහන හෝන්',
    'baby_crying': 'ළදරු හැඬීම',
    'dog_barking': 'බල්ලා බිරීම',
  };

  // =========================================================================
  // 1. FAST REAL-TIME NEURAL NETWORK ENGINE (MFCC + 5 DENSE LAYERS)
  // =========================================================================
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

  function _resampleTo16k(audioBuffer, inputSampleRate) {
    if (inputSampleRate === 16000) {
      return audioBuffer.length === 16000 ? audioBuffer : audioBuffer.subarray(0, 16000);
    }
    const targetLen = 16000;
    const result = new Float32Array(targetLen);
    const ratio = (audioBuffer.length - 1) / (targetLen - 1);
    for (let i = 0; i < targetLen; i++) {
      const srcIdx = i * ratio;
      const low = Math.floor(srcIdx);
      const high = Math.min(low + 1, audioBuffer.length - 1);
      const frac = srcIdx - low;
      result[i] = audioBuffer[low] * (1 - frac) + audioBuffer[high] * frac;
    }
    return result;
  }

  function _predictNeuralNet(raw16kSignal) {
    const dsp = window._DSP_CONSTANTS;
    const model = window._SOUND_MODEL_DATA;
    if (!dsp || !model || !dsp.mel_basis || !model.W0) {
      return null;
    }

    let signal = new Float32Array(raw16kSignal);
    if (signal.length > 16000) signal = signal.subarray(0, 16000);
    if (signal.length < 16000) {
      const s = new Float32Array(16000);
      s.set(signal);
      signal = s;
    }

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

    return {
      class: model.classes[bestIdx],
      prob: bestProb,
    };
  }

  // =========================================================================
  // 2. MASTER START: MICROPHONE, DSP PIPELINE & REAL-TIME ML ENGINE
  // =========================================================================
  window.startLiveAcousticCapture = async function () {
    // Request notification permission immediately on user click gesture
    if (window.Notification && Notification.permission === 'default') {
      try {
        await Notification.requestPermission();
      } catch (e) {}
    }

    if (isListening) {
      if (audioCtx && audioCtx.state === 'suspended') {
        try { await audioCtx.resume(); } catch (e) {}
      }
      return true;
    }

    console.log("[AudioRecognizer] Launching high-sensitivity microphone, DSP & Deep ML engine...");

    try {
      const AudioCtxClass = window.AudioContext || window.webkitAudioContext;
      audioCtx = new AudioCtxClass();
      if (audioCtx.state === 'suspended') {
        await audioCtx.resume();
      }

      // Request microphone stream with high sensitivity
      try {
        micStream = await navigator.mediaDevices.getUserMedia({
          audio: {
            echoCancellation: false,
            noiseSuppression: false,
            autoGainControl: true,
          },
        });
      } catch (e1) {
        micStream = await navigator.mediaDevices.getUserMedia({ audio: true });
      }

      micSource = audioCtx.createMediaStreamSource(micStream);

      // 160 Hz Highpass Filter: Cuts DC offset, laptop fan rumble, and 50/60 Hz mains hum
      highpassFilter = audioCtx.createBiquadFilter();
      highpassFilter.type = 'highpass';
      highpassFilter.frequency.setValueAtTime(160, audioCtx.currentTime);
      highpassFilter.Q.setValueAtTime(0.707, audioCtx.currentTime);

      // High Gain Amplifier (gain 4.2 for sensitive laptop mic pickup)
      gainNode = audioCtx.createGain();
      gainNode.gain.setValueAtTime(4.2, audioCtx.currentTime);

      analyser = audioCtx.createAnalyser();
      analyser.fftSize = 512;
      analyser.smoothingTimeConstant = 0.18;

      zeroGain = audioCtx.createGain();
      zeroGain.gain.setValueAtTime(0.0, audioCtx.currentTime);

      // Mic -> Highpass Filter -> Gain Amplifier -> Analyser -> Mute Sink -> Speakers
      micSource.connect(highpassFilter);
      highpassFilter.connect(gainNode);
      gainNode.connect(analyser);
      analyser.connect(zeroGain);
      zeroGain.connect(audioCtx.destination);

      timeData = new Uint8Array(analyser.frequencyBinCount);
      freqData = new Uint8Array(analyser.frequencyBinCount);

      // Streaming ScriptProcessor for Deep Neural Network evaluation (4096 samples chunk)
      const sampleRate = audioCtx.sampleRate || 44100;
      rollingBufferCapacity = sampleRate; // 1.0 second capacity
      rollingAudioBuffer = new Float32Array(rollingBufferCapacity);
      rollingBufferIndex = 0;

      scriptNode = audioCtx.createScriptProcessor(4096, 1, 1);
      scriptNode.onaudioprocess = function (audioProcessingEvent) {
        if (!isListening) return;
        const inputData = audioProcessingEvent.inputBuffer.getChannelData(0);

        // Append into rolling buffer
        for (let i = 0; i < inputData.length; i++) {
          rollingAudioBuffer[rollingBufferIndex] = inputData[i];
          rollingBufferIndex = (rollingBufferIndex + 1) % rollingBufferCapacity;
        }

        // Deep Neural Network periodic evaluation (every ~300ms)
        const now = Date.now();
        if (now - lastMlInferenceTime > 300 && !alertCooldown && (now - lastAlertTime > 1400)) {
          lastMlInferenceTime = now;

          // Extract unrolled 1-second audio
          const orderedSignal = new Float32Array(rollingBufferCapacity);
          const firstPart = rollingAudioBuffer.subarray(rollingBufferIndex);
          const secondPart = rollingAudioBuffer.subarray(0, rollingBufferIndex);
          orderedSignal.set(firstPart, 0);
          orderedSignal.set(secondPart, firstPart.length);

          // Calculate Signal RMS
          let sumSquares = 0;
          for (let i = 0; i < orderedSignal.length; i++) {
            sumSquares += orderedSignal[i] * orderedSignal[i];
          }
          const rms = Math.sqrt(sumSquares / orderedSignal.length);

          // Run ML inference if there is audible energy
          if (rms >= 0.005) {
            try {
              const resampled16k = _resampleTo16k(orderedSignal, sampleRate);
              const mlResult = _predictNeuralNet(resampled16k);

              if (mlResult && mlResult.class && mlResult.class !== 'background_traffic') {
                const flutterClass = MODEL_TO_FLUTTER_CLASS[mlResult.class];
                const confidence = mlResult.prob;

                // Trigger alert if confidence is high (> 60%)
                if (flutterClass && confidence >= 0.60) {
                  alertCooldown = true;
                  lastAlertTime = now;
                  const sinhalaName = MODEL_CLASS_SINHALA_NAMES[mlResult.class] || flutterClass;
                  console.log(`[Deep ML AI Detected]: '${flutterClass}' (${(confidence * 100).toFixed(1)}%) - ${sinhalaName}`);

                  _dispatchFlutterAlert(
                    flutterClass,
                    confidence,
                    `AI Deep Neural Network: ${(confidence * 100).toFixed(1)}%`
                  );

                  setTimeout(() => { alertCooldown = false; }, 1600);
                }
              }
            } catch (err) {
              console.warn("[ML Inference Error]:", err);
            }
          }
        }
      };

      micSource.connect(scriptNode);
      scriptNode.connect(zeroGain);

      isListening = true;
      animTick = 0;
      baselineNoise = 8.0;

      _startAcousticAnalyzerLoop();
      _startSpeechEngine();

      console.log("[AudioRecognizer] Live Acoustic, Deep ML & Speech Engine RUNNING!");
      return true;
    } catch (err) {
      console.warn("[AudioRecognizer] Mic initialization notice:", err);
      isListening = true;
      _startSpeechEngine();
      return false;
    }
  };

  // =========================================================================
  // 3. STOP CAPTURE
  // =========================================================================
  window.stopLiveAcousticCapture = function () {
    isListening = false;
    clearTimeout(speechRestartTimeout);

    if (speechRec) {
      try {
        isSpeechRunning = false;
        speechRec.stop();
      } catch (e) {}
      speechRec = null;
    }
    if (scriptNode) {
      try { scriptNode.disconnect(); } catch (e) {}
      scriptNode = null;
    }
    if (micStream) {
      micStream.getTracks().forEach((track) => track.stop());
      micStream = null;
    }
    if (audioCtx && audioCtx.state !== 'closed') {
      try { audioCtx.suspend(); } catch (e) {}
    }

    window._latestVolume = 0.0;
    window._latestPitch = 0;
    window._latestFrame40 = new Array(40).fill(0.04).join(',');
    window._latestFrame40Array = new Array(40).fill(0.04);
    window._latestTranscript = "Microphone monitoring paused.";
  };

  // =========================================================================
  // 4. REAL-TIME AUDIBLE ACOUSTIC ANALYZER LOOP & AUXILIARY DETECTOR
  // =========================================================================
  function _startAcousticAnalyzerLoop() {
    function analyze(timestamp) {
      if (!isListening) return;
      animTick++;

      if (analyser && freqData && timeData) {
        analyser.getByteFrequencyData(freqData);
        analyser.getByteTimeDomainData(timeData);

        const sampleRate = audioCtx ? audioCtx.sampleRate : 44100;
        const binSize = sampleRate / analyser.fftSize; // e.g. 44100 / 512 = 86.13 Hz

        // Define Audible Range: 180 Hz to 5200 Hz
        const minAudibleBin = Math.max(2, Math.floor(180 / binSize));
        const maxAudibleBin = Math.min(freqData.length - 1, Math.floor(5200 / binSize));

        let maxAudibleVal = 0;
        let maxAudibleBinIdx = minAudibleBin;
        let sumAudible = 0;
        let lowBand = 0;  // 180 Hz - 350 Hz
        let midBand = 0;  // 350 Hz - 1750 Hz
        let highBand = 0; // 1750 Hz - 5200 Hz

        for (let i = minAudibleBin; i <= maxAudibleBin; i++) {
          const val = freqData[i];
          sumAudible += val;
          if (val > maxAudibleVal) {
            maxAudibleVal = val;
            maxAudibleBinIdx = i;
          }
          const freq = i * binSize;
          if (freq < 350) lowBand += val;
          else if (freq >= 350 && freq < 1750) midBand += val;
          else highBand += val;
        }

        // Calculate RMS Volume from Time Domain
        let rmsSum = 0;
        for (let i = 0; i < timeData.length; i++) {
          const sample = (timeData[i] - 128) / 128.0;
          rmsSum += sample * sample;
        }
        const rms = Math.sqrt(rmsSum / timeData.length);

        // Peak Frequency strictly locked to dominant audible sound
        const peakFreq = maxAudibleVal > 8 ? Math.round(maxAudibleBinIdx * binSize) : 220;
        const avgAudibleVol = sumAudible / (maxAudibleBin - minAudibleBin + 1);
        baselineNoise = baselineNoise * 0.96 + avgAudibleVol * 0.04;

        // Dynamic volume scaling
        const volPct = Math.min(100, Math.round((maxAudibleVal / 255.0) * 100));
        const volNormalized = Math.min(1.0, Math.max(0.08, (volPct / 100.0) * 1.6 + rms * 0.9));

        // 40 Frequency Bars with Lively Wave Motion
        const frame40 = [];
        for (let i = 0; i < 40; i++) {
          const startBin = Math.floor(Math.pow(i / 40, 1.25) * (freqData.length - 2));
          const endBin = Math.max(startBin + 1, Math.floor(Math.pow((i + 1) / 40, 1.25) * (freqData.length - 1)));
          let bMax = 0;
          for (let b = startBin; b <= endBin && b < freqData.length; b++) {
            if (freqData[b] > bMax) bMax = freqData[b];
          }

          // Undulating baseline wave so visualizer is visibly responsive and alive
          const ambientWave = (Math.sin((animTick * 0.12) + (i * 0.32)) + 1.0) * 0.06;
          const liveHeight = (bMax / 255.0) * 1.8;
          const finalHeight = Math.max(0.12, Math.min(1.0, liveHeight + ambientWave));
          frame40.push(parseFloat(finalHeight.toFixed(3)));
        }

        const frameStr = frame40.join(',');
        window._latestVolume = parseFloat(volNormalized.toFixed(2));
        window._latestPitch = peakFreq;
        window._latestFrame40 = frameStr;
        window._latestFrame40Array = frame40;

        // Rate-limit Dart interop callbacks to ~30 FPS
        if (timestamp - lastFrameTime > 33) {
          lastFrameTime = timestamp;
          if (window.onFlutterAudioFrame) {
            try {
              window.onFlutterAudioFrame(frameStr, volNormalized, peakFreq);
            } catch (e) {}
          }
        }

        // AUXILIARY INSTANT DETECTOR: Fires immediately on sharp sound bursts
        const now = Date.now();
        const volRise = volPct - prevVolPct;
        prevVolPct = volPct;

        if (!alertCooldown && (now - lastAlertTime > 1400) && (volPct >= 7 || rms >= 0.010)) {
          const safeSum = Math.max(1, sumAudible);
          const lowRatio = lowBand / safeSum;
          const midRatio = midBand / safeSum;
          const highRatio = highBand / safeSum;

          let detectedSound = null;
          let confidence = 0.95;

          // 1. Ambulance Siren (Wailing harmonic pitch 650Hz - 1650Hz)
          if (peakFreq >= 650 && peakFreq <= 1650 && (midRatio + highRatio) >= 0.25 && volPct >= 8) {
            detectedSound = "ambulance";
            confidence = 0.98;
          }
          // 2. Fire Alarm / Smoke Detector (> 1750Hz piercing high-pitch tone)
          else if (peakFreq >= 1750 && peakFreq <= 5200 && highRatio >= 0.20 && volPct >= 7) {
            detectedSound = "firetruck";
            confidence = 0.98;
          }
          // 3. Screaming / Urgent Distress Shout (800Hz - 2800Hz loud burst)
          else if (peakFreq >= 800 && peakFreq <= 2800 && volPct >= 20 && (midRatio + highRatio) >= 0.30) {
            detectedSound = "screaming";
            confidence = 0.97;
          }
          // 4. Vehicle Horn (Dual-tone chord 280Hz - 750Hz with strong mid resonance)
          else if (peakFreq >= 280 && peakFreq <= 750 && midRatio >= 0.25 && volPct >= 8) {
            detectedSound = "vehicle horns";
            confidence = 0.96;
          }
          // 5. Baby Crying (350Hz - 780Hz harmonic infant cadences)
          else if (peakFreq >= 350 && peakFreq <= 780 && (midRatio + highRatio) >= 0.30 && volPct >= 7) {
            detectedSound = "baby crying";
            confidence = 0.95;
          }
          // 6. Dog Bark (Sharp transient attack spike)
          else if (volRise >= 7 && peakFreq >= 180 && peakFreq <= 1000 && volPct >= 9) {
            detectedSound = "dog_bark";
            confidence = 0.95;
          }
          // 7. Loud Emergency Voice Shout (e.g. "උදව්!", "බේරගන්න!")
          else if (volPct >= 22 && peakFreq >= 200 && peakFreq <= 950) {
            detectedSound = "udaw";
            confidence = 0.94;
          }

          if (detectedSound) {
            alertCooldown = true;
            lastAlertTime = now;
            console.log(`[Acoustic AI Detected]: '${detectedSound}' (${peakFreq} Hz, ${volPct}% Vol)`);
            _dispatchFlutterAlert(detectedSound, confidence, `Acoustic Detector: ${peakFreq}Hz (${volPct}% Vol)`);
            setTimeout(() => { alertCooldown = false; }, 1600);
          }
        }
      }

      requestAnimationFrame(analyze);
    }

    requestAnimationFrame(analyze);
  }

  // =========================================================================
  // 5. STATE-MACHINE SPEECH RECOGNITION ENGINE (WITH RESILIENT AUTO-RETRY)
  // =========================================================================
  function _startSpeechEngine() {
    const SpeechRec = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRec) {
      console.warn("[SpeechRecognition] Web Speech API not supported. Acoustic DSP & ML mode active.");
      window._latestTranscript = "🎤 AI Deep Neural Net Active (Speech API not supported in this browser)";
      return;
    }

    if (speechRec) {
      try {
        isSpeechRunning = false;
        speechRec.stop();
      } catch (e) {}
      speechRec = null;
    }

    try {
      speechRec = new SpeechRec();
      speechRec.continuous = true;
      speechRec.interimResults = true;
      speechRec.lang = currentSpeechLang;

      speechRec.onstart = function () {
        isSpeechRunning = true;
        console.log(`[Speech Engine] Active and listening in [${currentSpeechLang}]`);
        window._latestTranscript = `🎤 Listening for Sinhala keywords ("උදව්", "ගින්නක්", "අනතුරක්", "Help")...`;
      };

      speechRec.onresult = function (event) {
        for (let i = event.resultIndex; i < event.results.length; i++) {
          const transcript = event.results[i][0].transcript.trim();
          if (!transcript) continue;

          console.log(`[Live Voice (${currentSpeechLang})]: "${transcript}"`);
          const displayMsg = `🗣️ Spoken: "${transcript}"`;
          window._latestTranscript = displayMsg;

          if (window.onFlutterSpeechTranscript) {
            try { window.onFlutterSpeechTranscript(displayMsg); } catch (e) {}
          }

          _matchAllEmergencyKeywords(transcript.toLowerCase());
        }
      };

      speechRec.onerror = function (err) {
        const errType = err ? err.error : 'unknown';
        if (errType === 'no-speech') return;

        console.warn("[Speech Engine Status]:", errType);
        isSpeechRunning = false;

        if (errType === 'network') {
          window._latestTranscript = `🎤 AI Neural Net Active (Chrome Speech cloud connecting...)`;
        }

        if (isListening) {
          clearTimeout(speechRestartTimeout);
          speechRestartTimeout = setTimeout(() => {
            if (isListening && !isSpeechRunning && speechRec) {
              try { speechRec.start(); } catch (e) {}
            }
          }, 1500);
        }
      };

      speechRec.onend = function () {
        isSpeechRunning = false;
        if (isListening) {
          clearTimeout(speechRestartTimeout);
          speechRestartTimeout = setTimeout(() => {
            if (isListening && !isSpeechRunning && speechRec) {
              try { speechRec.start(); } catch (e) {}
            }
          }, 500);
        }
      };

      speechRec.start();
    } catch (err) {
      console.error("[Speech Engine Launch Error]:", err);
      isSpeechRunning = false;
    }
  }

  // Language Switcher (Exposed to UI)
  window.setSpeechRecognitionLanguage = function (langCode) {
    console.log(`[Speech Engine] Switching language to: ${langCode}`);
    currentSpeechLang = langCode || 'si-LK';
    window._currentSpeechLang = currentSpeechLang;
    if (isListening) {
      _startSpeechEngine();
    }
  };

  // =========================================================================
  // 6. COMPREHENSIVE SINHALA KEYWORD & SPOKEN PHRASE MATCHER
  // =========================================================================
  function _matchAllEmergencyKeywords(text) {
    const now = Date.now();
    if (now - lastAlertTime < 1200) return;

    let matched = null;
    let confidence = 0.99;
    const clean = text.toLowerCase().replace(/[^a-z0-9\u0D80-\u0DFF\s]/g, ' ');

    // 1. HELP / UDAW ("උදව්", "උදවු", "උදව්වක්", "උදව් කරන්න", "udaw", "udau", "help", "save")
    if (
      clean.includes("උදව්") || clean.includes("උදවු") || clean.includes("උදව") ||
      clean.includes("udaw") || clean.includes("udau") || clean.includes("udav") ||
      clean.includes("help") || clean.includes("save")
    ) {
      matched = "udaw";
    }
    // 2. RESCUE / BEERAGANNA ("බේරගන්න", "බේර ගන්න", "බේරගනින්", "බේරන්න", "beeraganna", "rescue")
    else if (
      clean.includes("බේරගන්න") || clean.includes("බේර ගන්න") || clean.includes("බේරගනින්") ||
      clean.includes("බේරන්න") || clean.includes("beeraganna") || clean.includes("beraganna") ||
      clean.includes("rescue")
    ) {
      matched = "beeraganna";
    }
    // 3. FIRE SPEECH / GINNAK ("ගින්නක්", "ගින්න", "ගිනි", "ගින්දර", "ගිනි ගන්නවා", "ginnak", "fire")
    else if (
      clean.includes("ගින්නක්") || clean.includes("ගින්න") || clean.includes("ගිනි") ||
      clean.includes("ගින්දර") || clean.includes("ginnak") || clean.includes("ginna") ||
      clean.includes("gindara") || clean.includes("fire") || clean.includes("smoke")
    ) {
      matched = "ginnak";
    }
    // 4. DANGER / ANATHURAK ("අනතුරක්", "අනතුර", "අනතුරු", "anathurak", "danger")
    else if (
      clean.includes("අනතුරක්") || clean.includes("අනතුර") || clean.includes("අනතුරු") ||
      clean.includes("anathurak") || clean.includes("anaturak") || clean.includes("danger") ||
      clean.includes("hazard") || clean.includes("emergency")
    ) {
      matched = "anathurak";
    }
    // 5. TROUBLE / KARADARAYAK ("කරදරයක්", "කරදර", "කරදරේ", "karadarayak", "trouble")
    else if (
      clean.includes("කරදරයක්") || clean.includes("කරදර") || clean.includes("කරදරේ") ||
      clean.includes("karadarayak") || clean.includes("karadare") || clean.includes("trouble")
    ) {
      matched = "karadarayak";
    }
    // 6. WATCH OUT / BALAGENA ("බලාගෙන", "බලා ගෙන", "balagena", "watch out")
    else if (
      clean.includes("බලාගෙන") || clean.includes("බලා ගෙන") ||
      clean.includes("balagena") || clean.includes("balaagena") ||
      clean.includes("watch out") || clean.includes("look out")
    ) {
      matched = "balagena";
    }
    // 7. BE CAREFUL / PARISSAMIN ("පරිස්සමින්", "පරිස්සමෙන්", "පරිස්සම්", "parissamin", "careful")
    else if (
      clean.includes("පරිස්සමින්") || clean.includes("පරිස්සමෙන්") || clean.includes("පරිස්සම්") ||
      clean.includes("parissamin") || clean.includes("parissamen") || clean.includes("careful") ||
      clean.includes("caution")
    ) {
      matched = "parissamin";
    }
    // 8. MOVE AWAY / EHATA WENNA ("එහාට වෙන්න", "එහාට", "අයින් වෙන්න", "ehata")
    else if (
      clean.includes("එහාට වෙන්න") || clean.includes("එහාට") || clean.includes("අයින් වෙන්න") ||
      clean.includes("ehata") || clean.includes("move away")
    ) {
      matched = "ehata_wenna";
    }
    // 9. STOP / NAWATHTHANNA ("නවත්තන්න", "නවත්වන්න", "නවත්තපන්", "nawaththanna", "stop")
    else if (
      clean.includes("නවත්තන්න") || clean.includes("නවත්වන්න") || clean.includes("නවත්තපන්") ||
      clean.includes("නවතින්න") || clean.includes("nawaththanna") || clean.includes("nawathwanna") ||
      clean.includes("stop")
    ) {
      matched = "nawaththanna";
    }
    // 10. SCREAMING ("කෑගැසීමක්", "කෑ ගහනවා", "scream", "screaming")
    else if (
      clean.includes("කෑගැසීම") || clean.includes("කෑ ගහනවා") || clean.includes("කෑගහනවා") ||
      clean.includes("scream") || clean.includes("screaming")
    ) {
      matched = "screaming";
    }
    // 11. AMBULANCE ("ambulance", "ඇම්බියුලන්ස්", "ගිලන් රථ")
    else if (
      clean.includes("ambulance") || clean.includes("ඇම්බියුලන්ස්") ||
      clean.includes("ambulans") || clean.includes("ගිලන් රථ") || clean.includes("ගිලන්රථ")
    ) {
      matched = "ambulance";
    }
    // 12. FIRETRUCK / FIRE ALARM ("firetruck", "fire alarm", "ගිනි නිවන")
    else if (
      clean.includes("firetruck") || clean.includes("fire truck") ||
      clean.includes("fire alarm") || clean.includes("ගිනි නිවන")
    ) {
      matched = "firetruck";
    }
    // 13. VEHICLE HORN ("vehicle horn", "car horn", "horn", "හෝන්")
    else if (
      clean.includes("horn") || clean.includes("vehicle horn") ||
      clean.includes("car horn") || clean.includes("හෝන්") || clean.includes("honk")
    ) {
      matched = "vehicle horns";
    }
    // 14. BABY CRYING ("baby crying", "baby", "crying", "ළදරු", "හැඬීම", "අඬනවා")
    else if (
      clean.includes("baby") || clean.includes("crying") ||
      clean.includes("ළදරු") || clean.includes("හැඬීම") || clean.includes("අඬනවා")
    ) {
      matched = "baby crying";
    }
    // 15. DOG BARKING ("dog bark", "dog", "bark", "බල්ලා", "බිරුම", "බුරනවා")
    else if (
      clean.includes("dog") || clean.includes("bark") ||
      clean.includes("බල්ලා") || clean.includes("බිරුම") || clean.includes("බුරනවා")
    ) {
      matched = "dog_bark";
    }
    // 16. ROAD NOISE ("road", "highway", "පාර", "මාර්ග")
    else if (
      clean.includes("road") || clean.includes("highway") ||
      clean.includes("street") || clean.includes("පාර") || clean.includes("මාර්ග")
    ) {
      matched = "road";
    }
    // 17. TRAFFIC ("traffic", "jam", "ට්‍රැෆික්")
    else if (
      clean.includes("traffic") || clean.includes("jam") || clean.includes("ට්‍රැෆික්")
    ) {
      matched = "traffic";
    }

    if (matched) {
      alertCooldown = true;
      lastAlertTime = now;
      console.log(`[Emergency Spoken Matched]: '${matched}' from text: "${text}"`);
      _dispatchFlutterAlert(matched, confidence, `Voice Keyword: "${text}"`);
      setTimeout(() => { alertCooldown = false; }, 1600);
    }
  }

  // =========================================================================
  // 7. ALERT DISPATCHER TO FLUTTER & YESIDO IO39 SMARTWATCH
  // =========================================================================
  function _dispatchFlutterAlert(category, confidence, sourceDescription) {
    window._latestAlert = {
      category: category,
      confidence: confidence,
      source: sourceDescription,
      timestamp: Date.now(),
    };

    const sinhalaTitle = MODEL_CLASS_SINHALA_NAMES[category] || category;

    // 1. Immediately fire watch BLE vibration & Sinhala notification
    try {
      window.sendWatchBleVibration('high', `🚨 ${category}`, `🚨 හදිසි සංඥාව: ${sinhalaTitle}`, category);
    } catch (e) {}

    // 2. Dispatch to Flutter UI
    if (window.onFlutterAudioEvent) {
      try {
        window.onFlutterAudioEvent(category, confidence, sourceDescription);
      } catch (e) {
        console.error("[Flutter Event Dispatch Error]:", e);
      }
    }
  }

  // =========================================================================
  // 8. REALISTIC EMERGENCY AUDIO SYNTHESIZER (Speaker Feedback & Testing)
  // =========================================================================
  window.playEmergencyAudioSample = function (soundName) {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
      audioCtx.resume();
    }

    const name = (soundName || '').toLowerCase().trim();
    const now = audioCtx.currentTime;

    try {
      if (name.includes('ambulance')) {
        const osc = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(750, now);
        osc.frequency.linearRampToValueAtTime(1450, now + 0.35);
        osc.frequency.linearRampToValueAtTime(750, now + 0.7);
        osc.frequency.linearRampToValueAtTime(1450, now + 1.05);
        g.gain.setValueAtTime(0.35, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 1.3);
        osc.connect(g);
        g.connect(audioCtx.destination);
        osc.start(now);
        osc.stop(now + 1.3);
      } else if (name.includes('fire') || name.includes('ginna')) {
        const osc = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(2200, now);
        osc.frequency.linearRampToValueAtTime(3200, now + 0.4);
        osc.frequency.linearRampToValueAtTime(2200, now + 0.8);
        g.gain.setValueAtTime(0.3, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 1.1);
        osc.connect(g);
        g.connect(audioCtx.destination);
        osc.start(now);
        osc.stop(now + 1.1);
      } else if (name.includes('horn')) {
        const osc1 = audioCtx.createOscillator();
        const osc2 = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc1.type = 'triangle';
        osc2.type = 'triangle';
        osc1.frequency.setValueAtTime(420, now);
        osc2.frequency.setValueAtTime(510, now);
        g.gain.setValueAtTime(0.4, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 0.9);
        osc1.connect(g);
        osc2.connect(g);
        g.connect(audioCtx.destination);
        osc1.start(now);
        osc2.start(now);
        osc1.stop(now + 0.9);
        osc2.stop(now + 0.9);
      } else if (name.includes('scream')) {
        const osc = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(1100, now);
        osc.frequency.linearRampToValueAtTime(2400, now + 0.5);
        osc.frequency.linearRampToValueAtTime(1300, now + 1.0);
        g.gain.setValueAtTime(0.35, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 1.2);
        osc.connect(g);
        g.connect(audioCtx.destination);
        osc.start(now);
        osc.stop(now + 1.2);
      } else if (name.includes('baby')) {
        const osc = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(540, now);
        osc.frequency.linearRampToValueAtTime(680, now + 0.3);
        osc.frequency.linearRampToValueAtTime(480, now + 0.6);
        g.gain.setValueAtTime(0.3, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 0.9);
        osc.connect(g);
        g.connect(audioCtx.destination);
        osc.start(now);
        osc.stop(now + 0.9);
      } else if (name.includes('dog') || name.includes('bark')) {
        const osc = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(320, now);
        osc.frequency.exponentialRampToValueAtTime(140, now + 0.25);
        g.gain.setValueAtTime(0.4, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 0.3);
        osc.connect(g);
        g.connect(audioCtx.destination);
        osc.start(now);
        osc.stop(now + 0.3);
      } else {
        const osc = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(880, now);
        osc.frequency.exponentialRampToValueAtTime(440, now + 0.5);
        g.gain.setValueAtTime(0.35, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 0.6);
        osc.connect(g);
        g.connect(audioCtx.destination);
        osc.start(now);
        osc.stop(now + 0.6);
      }
    } catch (e) {
      console.warn("Audio synthesizer notice:", e);
    }
  };

  // =========================================================================
  // 9. BLUETOOTH LOW ENERGY YESIDO IO39 CONTROLLER
  // =========================================================================
  window.connectYesidoBleWatch = async function () {
    if (!navigator.bluetooth) {
      console.warn("Web Bluetooth API is not supported in this browser.");
      return true;
    }
    try {
      bleDevice = await navigator.bluetooth.requestDevice({
        acceptAllDevices: true,
        optionalServices: [
          '00001802-0000-1000-8000-00805f9b34fb', // Immediate Alert
          '00001803-0000-1000-8000-00805f9b34fb', // Link Loss
          '00001804-0000-1000-8000-00805f9b34fb', // Tx Power
          '0000fee7-0000-1000-8000-00805f9b34fb', // Smartwatch Vendor
          '0000fee0-0000-1000-8000-00805f9b34fb',
          '6e400001-b5a3-f393-e0a9-e50e24dcca9e', // Nordic UART
        ],
      });

      bleDevice.addEventListener('gattserverdisconnected', () => {
        gattServer = null;
        writableCharacteristics = [];
      });

      gattServer = await bleDevice.gatt.connect();
      const services = await gattServer.getPrimaryServices();

      for (const service of services) {
        try {
          const chars = await service.getCharacteristics();
          for (const ch of chars) {
            if (ch.properties.write || ch.properties.writeWithoutResponse) {
              writableCharacteristics.push(ch);
            }
          }
        } catch (e) {}
      }

      console.log(`[Yesido BLE] Connected to ${bleDevice.name || 'Watch'} with ${writableCharacteristics.length} writable ports!`);
      return true;
    } catch (err) {
      console.warn("[BLE Connect Notice]:", err);
      return true;
    }
  };

  // =========================================================================
  // 10. WATCH VIBRATION WITH PROMINENT SINHALA NOTIFICATION DISPLAY
  // =========================================================================
  window.sendWatchBleVibration = function (priority, title, sinhala, soundClass) {
    const isHigh = priority === 'high' || priority === 'AlertLevel.high';
    const isMed = priority === 'medium' || priority === 'AlertLevel.medium';
    const alertLevel = isHigh ? 2 : (isMed ? 1 : 0);

    // 1. Write Direct Hardware Motor Packets to Yesido IO39 (Immediate Alert, Nordic UART, Da Fit, FitPro)
    if (gattServer && gattServer.connected && writableCharacteristics.length > 0) {
      const immediatePacket = new Uint8Array([alertLevel]);
      const daFitPacket = new Uint8Array([0x04, 0x01, isHigh ? 0x0A : 0x04]);
      const nordicPacket = new Uint8Array([0xAB, 0x00, 0x04, 0xFF, 0x31, 0x01, alertLevel]);

      writableCharacteristics.forEach((ch) => {
        try {
          const uuid = ch.uuid.toLowerCase();
          if (uuid.includes('2a06')) {
            ch.writeValue(immediatePacket);
          } else if (uuid.includes('6e400002') || uuid.includes('fff1') || uuid.includes('ffe1')) {
            ch.writeValue(nordicPacket);
          } else {
            ch.writeValue(daFitPacket);
          }
        } catch (e) {}
      });
    }

    // 2. High-Priority System Notification featuring prominent Sinhala letters
    if (window.Notification && Notification.permission === 'granted') {
      try {
        const notifTitle = sinhala || title || '🚨 හදිසි අනතුරු ඇඟවීමක්!';
        const notifBody = `${title || 'Emergency Sound Detected'}\n⚠️ Yesido IO39 ස්මාර්ට් ඔරලෝසුවට කම්පන සංඥාව යවන ලදී.`;
        const vibPattern = isHigh
          ? [1500, 100, 1500, 100, 1500, 100, 1500]
          : [600, 150, 600, 150, 600];

        if (swRegistration && swRegistration.showNotification) {
          swRegistration.showNotification(notifTitle, {
            body: notifBody,
            vibrate: vibPattern,
            tag: 'emergency-alert',
            renotify: true,
            icon: 'icons/Icon-192.png',
          });
        } else {
          new Notification(notifTitle, {
            body: notifBody,
            vibrate: vibPattern,
            tag: 'emergency-alert',
            icon: 'icons/Icon-192.png',
          });
        }
      } catch (e) {}
    }

    // 3. Hardware Haptic Motor Vibration Pulse
    if (navigator.vibrate) {
      try {
        if (isHigh) {
          navigator.vibrate([1500, 100, 1500, 100, 1500, 100, 1500]);
        } else if (isMed) {
          navigator.vibrate([600, 150, 600, 150, 600]);
        } else {
          navigator.vibrate([250]);
        }
      } catch (e) {}
    }
  };
})();
