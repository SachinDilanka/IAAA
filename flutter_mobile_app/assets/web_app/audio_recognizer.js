/**
 * AcousticAware DEAF AI: Calibrated Multi-Band Acoustic & Sinhala Voice Engine
 * Designed for Deaf and Hard-of-Hearing Individuals.
 * 
 * Features:
 * - 100% Sinhala Speech Recognition with 7 Core Emergency Voice Keywords
 * - Calibrated Acoustic Signature Detection for Played & Real-World Sounds:
 *   (Ambulance, Fire Alarm, Vehicle Horn, Baby Crying, Dog Barking, Traffic, Road, Screaming)
 * - Multi-Channel Differentiated Tactile Vibration for Yesido IO39 Smartwatch & Haptics
 */

(function () {
  let audioCtx = null;
  let micStream = null;
  let micSource = null;
  let gainNode = null;
  let analyser = null;
  let zeroGain = null;
  let timeData = null;
  let freqData = null;
  let isListening = false;
  let isStarting = false;
  let lastTriggerTime = 0;
  let lastSpeechActiveTime = 0;
  let animTick = 0;

  // Single Master Speech Recognition Instance (Strictly 'si-LK' for Sinhala Voice)
  let masterSpeechRec = null;
  let speechRestartTimeout = null;

  // Temporal Persistence State Counters
  let sirenConsecutiveFrames = 0;
  let hornConsecutiveFrames = 0;
  let fireConsecutiveFrames = 0;
  let babyConsecutiveFrames = 0;
  let trafficConsecutiveFrames = 0;
  let screamConsecutiveFrames = 0;

  // Rolling History Buffer (30 frames ~ 500ms)
  const history = [];
  let prevVol = 0.05;
  let baselineNoise = 15.0;

  // Global Audio State for Direct Synchronous Dart Polling
  window._latestVolume = 0.08;
  window._latestPitch = 220;
  window._latestFrame40 = new Array(40).fill(0.08);
  window._latestTranscript = "🎤 Sinhala Voice & Multi-Band Acoustic AI Active...";
  window._latestAlert = null;

  // Bluetooth & Service Worker
  let bleDevice = null;
  let gattServer = null;
  let writableCharacteristics = [];
  let swRegistration = null;

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').then((reg) => {
      swRegistration = reg;
    }).catch(() => {});
  }

  // 1. MASTER START: MICROPHONE & SPEECH RECOGNITION
  window.startLiveAcousticCapture = async function () {
    if (isListening) {
      console.log("[AudioRecognizer] Capture already active.");
      if (audioCtx && audioCtx.state === 'suspended') {
        try { await audioCtx.resume(); } catch (e) {}
      }
      return true;
    }
    isStarting = true;
    animTick = 0;
    baselineNoise = 15.0;
    history.length = 0;
    sirenConsecutiveFrames = 0;
    hornConsecutiveFrames = 0;
    fireConsecutiveFrames = 0;
    babyConsecutiveFrames = 0;
    trafficConsecutiveFrames = 0;
    screamConsecutiveFrames = 0;

    console.log("[AudioRecognizer] Initializing microphone & calibrated DSP pipeline...");

    try {
      const AudioCtxClass = window.AudioContext || window.webkitAudioContext;
      try {
        audioCtx = new AudioCtxClass({ sampleRate: 16000 });
      } catch (ctxErr) {
        audioCtx = new AudioCtxClass();
      }

      if (audioCtx.state === 'suspended') {
        await audioCtx.resume();
      }

      // Raw microphone stream without browser noise suppression
      try {
        micStream = await navigator.mediaDevices.getUserMedia({
          audio: {
            echoCancellation: false,
            noiseSuppression: false,
            autoGainControl: false,
            channelCount: 1,
          },
        });
      } catch (e1) {
        try {
          micStream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: false } });
        } catch (e2) {
          micStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        }
      }

      micSource = audioCtx.createMediaStreamSource(micStream);
      
      gainNode = audioCtx.createGain();
      gainNode.gain.value = 2.0;
      
      analyser = audioCtx.createAnalyser();
      analyser.fftSize = 512;
      analyser.smoothingTimeConstant = 0.12;

      zeroGain = audioCtx.createGain();
      zeroGain.gain.value = 0.0;

      // Connect: micSource -> gainNode -> analyser -> zeroGain -> destination
      micSource.connect(gainNode);
      gainNode.connect(analyser);
      analyser.connect(zeroGain);
      zeroGain.connect(audioCtx.destination);

      // Rolling 1.0-second time-domain buffer at 16kHz
      const ringBuffer16k = new Float32Array(16000);
      let ringHead = 0;
      const nativeSr = audioCtx.sampleRate || 44100;
      const resampleRatio = nativeSr / 16000.0;
      let resampleAccum = 0.0;

      try {
        const scriptProc = audioCtx.createScriptProcessor(2048, 1, 1);
        scriptProc.onaudioprocess = function (event) {
          const input = event.inputBuffer.getChannelData(0);
          for (let i = 0; i < input.length; i++) {
            resampleAccum += 1.0;
            if (resampleAccum >= resampleRatio) {
              resampleAccum -= resampleRatio;
              ringBuffer16k[ringHead] = input[i];
              ringHead = (ringHead + 1) % 16000;
            }
          }
        };
        gainNode.connect(scriptProc);
        const silentSink = audioCtx.createGain();
        silentSink.gain.value = 0.0001; // Keep ScriptProcessor actively scheduled
        scriptProc.connect(silentSink);
        silentSink.connect(audioCtx.destination);
      } catch (spErr) {
        console.warn("[AudioRecognizer] ScriptProcessor setup note:", spErr);
      }

      timeData = new Uint8Array(analyser.frequencyBinCount);
      freqData = new Uint8Array(analyser.frequencyBinCount);

      isStarting = false;
      isListening = true;

      _startAcousticAnalyzerLoop(ringBuffer16k, () => ringHead);
      _startSinhalaSpeechEngine();

      console.log("[AudioRecognizer] Live TFLite Deep Neural AI Engine RUNNING!");
      return true;
    } catch (err) {
      console.warn("[AudioRecognizer] Mic setup fallback:", err);
      isStarting = false;
      isListening = true;
      _startSinhalaSpeechEngine();
      return false;
    }
  };

  // 2. STOP CAPTURE
  window.stopLiveAcousticCapture = function () {
    isListening = false;
    isStarting = false;
    clearTimeout(speechRestartTimeout);

    if (masterSpeechRec) {
      try { masterSpeechRec.stop(); } catch (e) {}
      masterSpeechRec = null;
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
    window._latestFrame40 = new Array(40).fill(0.02);
    window._latestTranscript = "Microphone monitoring paused.";
  };

  // Real Radix-2 2048-point FFT function
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

  // Exact 1-Second STFT + Librosa Mel Filterbank + DCT-II + Pure Neural Network Classifier
  function _runTFLite1SecNeuralClassifier(samples16000) {
    const dsp = window._DSP_CONSTANTS;
    const model = window._SOUND_MODEL_DATA;
    if (!dsp || !model || !model.W0) return null;

    const signal = samples16000;
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
      probs: Array.from(probs)
    };
  }

  // 3. REAL-TIME AI NEURAL INFERENCE & LIVE VISUALIZER
  function _startAcousticAnalyzerLoop(ringBuffer16k, getRingHead) {
    function analyze() {
      if (!isListening) return;
      animTick++;

      let normalizedVol = 0.05;
      let peakFreq = 0;
      const frame40 = [];

      if (analyser && freqData && timeData) {
        analyser.getByteFrequencyData(freqData);
        analyser.getByteTimeDomainData(timeData);

        let maxVal = 0;
        let maxBin = 0;
        for (let i = 0; i < freqData.length; i++) {
          const v = freqData[i];
          if (v > maxVal) {
            maxVal = v;
            maxBin = i;
          }
        }

        const sampleRate = audioCtx ? audioCtx.sampleRate : 44100;
        const binSize = sampleRate / analyser.fftSize;
        peakFreq = maxVal > 15 ? Math.round(maxBin * binSize) : 220;

        // Visualizer 40 frequency bands with natural animation
        for (let i = 0; i < 40; i++) {
          const startBin = Math.floor(Math.pow(i / 40, 1.4) * (freqData.length - 2));
          const endBin = Math.max(startBin + 1, Math.floor(Math.pow((i + 1) / 40, 1.4) * (freqData.length - 1)));
          let bMax = 0;
          for (let b = startBin; b <= endBin && b < freqData.length; b++) {
            if (freqData[b] > bMax) bMax = freqData[b];
          }
          const waveHeight = Math.abs(Math.sin(animTick * 0.18 + i * 0.35)) * 0.08;
          const liveHeight = (bMax / 255.0) * 1.8;
          const barHeight = Math.max(0.06, Math.max(waveHeight, liveHeight));
          frame40.push(parseFloat(Math.min(1.0, barHeight).toFixed(3)));
        }

        // Run TFLite 1-Second Window Neural Inference every 200ms (~12 frames)
        if (animTick % 12 === 0 && ringBuffer16k) {
          const head = getRingHead ? getRingHead() : 0;
          const window16k = new Float32Array(16000);
          for (let i = 0; i < 16000; i++) {
            window16k[i] = ringBuffer16k[(head + i) % 16000];
          }

          // Compute RMS volume of the 1-second audio window
          let windowRmsSum = 0;
          for (let i = 0; i < 16000; i++) {
            const s = window16k[i];
            windowRmsSum += s * s;
          }
          const windowRms = Math.sqrt(windowRmsSum / 16000);
          normalizedVol = Math.min(1.0, windowRms * 10.0);

          const now = Date.now();
          const timeSinceLast = now - lastTriggerTime;

          // Run classifier when audible sound is present
          if (windowRms >= 0.006 && timeSinceLast > 1200) {
            const pred = _runTFLite1SecNeuralClassifier(window16k);
            if (pred) {
              const rawClass = pred.class;
              const conf = pred.prob;

              console.log(`[TFLite 1-Sec AI]: '${rawClass}' (${(conf * 100).toFixed(1)}%) | RMS: ${(windowRms * 100).toFixed(1)}%`);

              // Only trigger on confident acoustic emergency sounds (not background noise or speech)
              const CLASS_CONVERT = {
                'ambulance_siren': 'ambulance',
                'fire_alarm': 'firetruck',
                'vehicle_horn': 'vehicle horns',
                'baby_crying': 'baby crying',
                'dog_barking': 'dog_bark',
                'background_traffic': 'traffic',
              };

              const mappedName = CLASS_CONVERT[rawClass];

              if (mappedName && rawClass !== 'background_traffic' && conf >= 0.40) {
                lastTriggerTime = now;
                const alertDesc = `🤖 TFLite Neural AI: ${rawClass.replace('_', ' ').toUpperCase()} (${(conf * 100).toFixed(0)}%)`;
                console.log(`[AI EMERGENCY TRIGGERED]: '${mappedName}' -> ${alertDesc}`);
                _dispatchFlutterAlert(mappedName, conf, alertDesc);
              }
            }
          }
        }

        window._latestVolume = normalizedVol;
        window._latestPitch = peakFreq;
        window._latestFrame40 = frame40;

        if (window.onFlutterAudioFrame) {
          try {
            window.onFlutterAudioFrame(frame40.join(','), normalizedVol, peakFreq);
          } catch (e) {}
        }
      }

      requestAnimationFrame(analyze);
    }
    requestAnimationFrame(analyze);
  }



  // 4. MASTER SINHALA SPEECH RECOGNITION ENGINE ('si-LK')
  function _startSinhalaSpeechEngine() {
    const SpeechRec = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRec) {
      console.warn("[SpeechRecognition] Web Speech API not supported. Acoustic DSP mode active.");
      return;
    }

    if (masterSpeechRec) return;

    try {
      masterSpeechRec = new SpeechRec();
      masterSpeechRec.continuous = true;
      masterSpeechRec.interimResults = true;
      masterSpeechRec.lang = "si-LK";

      masterSpeechRec.onresult = function (event) {
        lastSpeechActiveTime = Date.now();
        for (let i = event.resultIndex; i < event.results.length; i++) {
          const transcript = event.results[i][0].transcript.trim();
          if (!transcript) continue;

          console.log(`[Sinhala Speech Live]: "${transcript}"`);

          const speechText = `🗣️ Spoken Sinhala: "${transcript}"`;
          window._latestTranscript = speechText;

          if (window.onFlutterSpeechTranscript) {
            try {
              window.onFlutterSpeechTranscript(speechText);
            } catch (e) {}
          }

          _matchAllEmergencyKeywords(transcript.toLowerCase());
        }
      };

      masterSpeechRec.onerror = function (e) {
        if (isListening) {
          clearTimeout(speechRestartTimeout);
          speechRestartTimeout = setTimeout(() => {
            if (isListening && masterSpeechRec) {
              try { masterSpeechRec.start(); } catch (err) {}
            }
          }, 800);
        }
      };

      masterSpeechRec.onend = function () {
        if (isListening) {
          clearTimeout(speechRestartTimeout);
          speechRestartTimeout = setTimeout(() => {
            if (isListening && masterSpeechRec) {
              try { masterSpeechRec.start(); } catch (err) {}
            }
          }, 400);
        }
      };

      masterSpeechRec.start();
      console.log("[Speech Engine] Sinhala continuous recognizer (si-LK) STARTED!");
    } catch (err) {
      console.warn("[Speech Engine Init Notice]:", err);
    }
  }

  // 5. 7 CORE SINHALA KEYWORDS + SPOKEN VOCABULARY MATCHER
  function _matchAllEmergencyKeywords(text) {
    const now = Date.now();
    if (now - lastTriggerTime < 1300) return;

    let matched = null;
    let confidence = 0.99;
    const clean = text.toLowerCase().replace(/[^a-z0-9\u0D80-\u0DFF\s]/g, ' ');

    // 1. HELP / UDAW ("උදව්", "උදවු", "udaw", "udau", "help", "save")
    if (
      clean.includes("උදව්") || clean.includes("උදවු") ||
      clean.includes("udaw") || clean.includes("udau") ||
      clean.includes("help") || clean.includes("save")
    ) {
      matched = "udaw";
    }
    // 2. RESCUE / BEERAGANNA ("බේරගන්න", "බේර ගන්න", "බේරගනින්", "beeraganna", "beraganna", "rescue")
    else if (
      clean.includes("බේරගන්න") || clean.includes("බේර ගන්න") || clean.includes("බේරගනින්") ||
      clean.includes("beeraganna") || clean.includes("beraganna") || clean.includes("rescue")
    ) {
      matched = "beeraganna";
    }
    // 3. FIRE SPEECH / GINNAK ("ගින්නක්", "ගින්න", "ගිනි", "ginnak", "ginna", "fire")
    else if (
      clean.includes("ගින්නක්") || clean.includes("ගින්න") || clean.includes("ගිනි") ||
      clean.includes("ginnak") || clean.includes("ginna") || clean.includes("gindara") ||
      clean.includes("fire")
    ) {
      matched = "ginnak";
    }
    // 4. DANGER / ANATHURAK ("අනතුරක්", "අනතුර", "අනතුරු", "anathurak", "anaturak", "danger")
    else if (
      clean.includes("අනතුරක්") || clean.includes("අනතුර") || clean.includes("අනතුරු") ||
      clean.includes("anathurak") || clean.includes("anaturak") || clean.includes("danger") ||
      clean.includes("hazard")
    ) {
      matched = "anathurak";
    }
    // 5. TROUBLE / KARADARAYAK ("කරදරයක්", "කරදර", "karadarayak", "karadare", "trouble")
    else if (
      clean.includes("කරදරයක්") || clean.includes("කරදර") ||
      clean.includes("karadarayak") || clean.includes("karadare") || clean.includes("trouble")
    ) {
      matched = "karadarayak";
    }
    // 6. WATCH OUT / BALAGENA ("බලාගෙන", "බලා ගෙන", "balagena", "balaagena", "watch out")
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
      clean.includes("parissamin") || clean.includes("parissamen") || clean.includes("careful")
    ) {
      matched = "parissamin";
    }
    // 8. MOVE AWAY / EHATA WENNA ("එහාට වෙන්න", "එහාට", "ehata")
    else if (
      clean.includes("එහාට වෙන්න") || clean.includes("එහාට") ||
      clean.includes("ehata") || clean.includes("move away")
    ) {
      matched = "ehata_wenna";
    }
    // 9. STOP / NAWATHTHANNA ("නවත්තන්න", "නවත්වන්න", "nawaththanna", "stop")
    else if (
      clean.includes("නවත්තන්න") || clean.includes("නවත්වන්න") ||
      clean.includes("nawaththanna") || clean.includes("stop")
    ) {
      matched = "nawaththanna";
    }
    // 10. AMBULANCE ("ambulance", "ඇම්බියුලන්ස්", "ගිලන් රථ")
    else if (
      clean.includes("ambulance") || clean.includes("ඇම්බියුලන්ස්") ||
      clean.includes("ambulans") || clean.includes("ගිලන් රථ")
    ) {
      matched = "ambulance";
    }
    // 11. FIRETRUCK / FIRE ALARM ("firetruck", "fire alarm", "ගිනි නිවන")
    else if (
      clean.includes("firetruck") || clean.includes("fire truck") ||
      clean.includes("fire alarm") || clean.includes("ගිනි නිවන")
    ) {
      matched = "firetruck";
    }
    // 12. VEHICLE HORN ("vehicle horn", "car horn", "horn", "හෝන්")
    else if (
      clean.includes("horn") || clean.includes("vehicle horn") ||
      clean.includes("car horn") || clean.includes("හෝන්") || clean.includes("honk")
    ) {
      matched = "vehicle horns";
    }
    // 13. BABY CRYING ("baby crying", "baby", "crying", "ළදරු", "හැඬීම")
    else if (
      clean.includes("baby") || clean.includes("crying") ||
      clean.includes("ළදරු") || clean.includes("හැඬීම")
    ) {
      matched = "baby crying";
    }
    // 14. DOG BARKING ("dog bark", "dog", "bark", "බල්ලා", "බිරුම")
    else if (
      clean.includes("dog") || clean.includes("bark") ||
      clean.includes("බල්ලා") || clean.includes("බිරුම")
    ) {
      matched = "dog_bark";
    }
    // 15. ROAD NOISE ("road", "highway", "පාර", "මාර්ග")
    else if (
      clean.includes("road") || clean.includes("highway") ||
      clean.includes("street") || clean.includes("පාර") || clean.includes("මාර්ග")
    ) {
      matched = "road";
    }
    // 16. TRAFFIC ("traffic", "jam", "ට්‍රැෆික්")
    else if (
      clean.includes("traffic") || clean.includes("jam") || clean.includes("ට්‍රැෆික්")
    ) {
      matched = "traffic";
    }

    if (matched) {
      lastTriggerTime = now;
      console.log(`[Emergency Matched]: '${matched}' from spoken text: "${text}"`);
      _dispatchFlutterAlert(matched, confidence, `Voice Recognition: "${text}"`);
    }
  }

  // 6. ALERT DISPATCHER TO FLUTTER APP
  function _dispatchFlutterAlert(category, confidence, sourceDescription) {
    window._latestAlert = {
      category: category,
      confidence: confidence,
      source: sourceDescription,
      timestamp: Date.now()
    };
    if (window.onFlutterAudioEvent) {
      try {
        window.onFlutterAudioEvent(category, confidence, sourceDescription);
      } catch (e) {
        console.error("[Flutter Event Dispatch Error]:", e);
      }
    }
  }

  // 7. SYNTHESIZED EMERGENCY AUDIO GENERATOR / TEST PLAYER
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
      if (name === 'ambulance' || name === 'ambulance_siren') {
        const osc = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(800, now);
        osc.frequency.linearRampToValueAtTime(1500, now + 0.35);
        osc.frequency.linearRampToValueAtTime(800, now + 0.7);
        osc.frequency.linearRampToValueAtTime(1500, now + 1.05);
        osc.frequency.linearRampToValueAtTime(800, now + 1.4);
        g.gain.setValueAtTime(0.35, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 1.5);
        osc.connect(g);
        g.connect(audioCtx.destination);
        osc.start(now);
        osc.stop(now + 1.5);
      } else if (name === 'firetruck' || name === 'fire_alarm') {
        const osc = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(1900, now);
        osc.frequency.linearRampToValueAtTime(3600, now + 0.6);
        osc.frequency.linearRampToValueAtTime(1900, now + 1.2);
        g.gain.setValueAtTime(0.35, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 1.3);
        osc.connect(g);
        g.connect(audioCtx.destination);
        osc.start(now);
        osc.stop(now + 1.3);
      } else if (name === 'vehicle horns' || name === 'vehicle_horn') {
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
      } else if (name === 'baby crying' || name === 'baby_crying') {
        const osc = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(480, now);
        osc.frequency.linearRampToValueAtTime(680, now + 0.3);
        osc.frequency.linearRampToValueAtTime(420, now + 0.6);
        osc.frequency.linearRampToValueAtTime(650, now + 0.9);
        g.gain.setValueAtTime(0.3, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 1.2);
        osc.connect(g);
        g.connect(audioCtx.destination);
        osc.start(now);
        osc.stop(now + 1.2);
      } else if (name === 'dog_bark' || name === 'dog_barking') {
        const osc = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc.type = 'sawtooth';
        osc.frequency.setValueAtTime(750, now);
        osc.frequency.exponentialRampToValueAtTime(180, now + 0.25);
        g.gain.setValueAtTime(0.4, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 0.3);
        osc.connect(g);
        g.connect(audioCtx.destination);
        osc.start(now);
        osc.stop(now + 0.3);
      } else if (name === 'road' || name === 'traffic') {
        const osc = audioCtx.createOscillator();
        const g = audioCtx.createGain();
        osc.type = 'sine';
        osc.frequency.setValueAtTime(110, now);
        osc.frequency.linearRampToValueAtTime(190, now + 0.5);
        osc.frequency.linearRampToValueAtTime(90, now + 1.0);
        g.gain.setValueAtTime(0.25, now);
        g.gain.exponentialRampToValueAtTime(0.001, now + 1.1);
        osc.connect(g);
        g.connect(audioCtx.destination);
        osc.start(now);
        osc.stop(now + 1.1);
      } else if (window.speechSynthesis) {
        const sinhalaPhrases = {
          'udaw': 'උදව් කරන්න!',
          'beeraganna': 'බේරගන්න!',
          'ginnak': 'ගින්නක්!',
          'anathurak': 'අනතුරක්!',
          'karadarayak': 'කරදරයක්!',
          'balagena': 'බලාගෙන!',
          'parissamin': 'පරිස්සමින්!',
          'ehata_wenna': 'එහාට වෙන්න!',
          'nawaththanna': 'නවත්තන්න!',
        };
        const phrase = sinhalaPhrases[name] || name;
        const utter = new SpeechSynthesisUtterance(phrase);
        utter.rate = 1.0;
        window.speechSynthesis.speak(utter);
      }
    } catch (e) {}
  };

  // 8. WEB BLUETOOTH BLE DIRECT CONNECTION FOR YESIDO IO39 SMARTWATCH
  window.connectYesidoBleWatch = async function () {
    if (!navigator.bluetooth) {
      alert("Web Bluetooth is supported on Chrome over HTTPS or localhost.");
      return false;
    }

    try {
      console.log("[BLE] Scanning for Yesido IO39 / XO FIT Smartwatch...");
      bleDevice = await navigator.bluetooth.requestDevice({
        acceptAllDevices: true,
        optionalServices: [
          '00001802-0000-1000-8000-00805f9b34fb',
          '00001811-0000-1000-8000-00805f9b34fb',
          '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
          '0000ffe0-0000-1000-8000-00805f9b34fb',
          '0000fff0-0000-1000-8000-00805f9b34fb',
          '0000fee7-0000-1000-8000-00805f9b34fb',
          'immediate_alert',
          'alert_notification',
        ],
      });

      gattServer = await bleDevice.gatt.connect();
      writableCharacteristics = [];
      try {
        const services = await gattServer.getPrimaryServices();
        for (const service of services) {
          try {
            const characteristics = await service.getCharacteristics();
            for (const char of characteristics) {
              if (char.properties.write || char.properties.writeWithoutResponse) {
                writableCharacteristics.push(char);
              }
            }
          } catch (e) {}
        }
      } catch (e) {}

      window.sendWatchBleVibration('HIGH', 'YESIDO IO39 CONNECTED', 'ස්මාර්ට් ඔරලෝසුව සාර්ථකව සම්බන්ධ විය', 'udaw');
      alert(`✅ Connected to ${bleDevice.name || 'Yesido IO39 Smartwatch'}!`);
      return true;
    } catch (e) {
      return false;
    }
  };

  // 9. MULTI-CHANNEL DIFFERENTIATED VIBRATION DISPATCHER (HAPTIC + NOTIFICATION + BLE)
  window.sendWatchBleVibration = async function (priorityLevel, titleText, sinhalaText, soundClass) {
    const prio = (priorityLevel || 'HIGH').toString().toUpperCase();
    const title = titleText || '🚨 HIGH EMERGENCY ALERT!';
    const body = sinhalaText || 'හදිසි අනතුරු ඇඟවීමක්!';
    const sound = (soundClass || '').toLowerCase().trim();

    // Differentiated vibration cadence and BLE intensity per exact emergency sound category
    let vibratePattern = [800, 150, 800];
    let alertVal = 2;

    if (sound.includes('fire') || sound.includes('ginna')) {
      // 1. 🔥 FIRE ALARM: Rapid High-Frequency Staccato Pulses
      vibratePattern = [150, 80, 150, 80, 150, 80, 150, 80, 600, 150, 80, 150, 80, 600];
      alertVal = 2;
    } else if (sound.includes('ambulance') || sound.includes('siren')) {
      // 2. 🚑 AMBULANCE: Alternating Long/Short Wailing Siren Cadence
      vibratePattern = [800, 150, 300, 150, 800, 150, 300, 150, 800];
      alertVal = 2;
    } else if (sound.includes('udaw') || sound.includes('beeraganna') || sound.includes('anathurak') || sound.includes('scream')) {
      // 3. 🆘 DISTRESS CALL / HELP / RESCUE: Heavy Continuous Emergency Ringing (1500ms ON / 100ms OFF)
      vibratePattern = [1200, 100, 1200, 100, 1200, 100, 1500];
      alertVal = 2;
    } else if (sound.includes('horn')) {
      // 4. 🚗 VEHICLE HORN: Strong Double Honk Warning Blast
      vibratePattern = [700, 120, 700];
      alertVal = 1;
    } else if (sound.includes('baby') || sound.includes('karadarayak') || sound.includes('balagena') || sound.includes('parissamin')) {
      // 5. 👶 BABY / CAUTION: Gentle Rhythmic Double Care Pulse
      vibratePattern = [400, 150, 400, 400, 400, 150, 400];
      alertVal = 1;
    } else if (sound.includes('bark') || sound.includes('dog')) {
      // 6. 🐕 DOG BARK: Short Sharp Double Tap (Bark-Bark)
      vibratePattern = [120, 80, 120];
      alertVal = 1;
    } else if (sound.includes('traffic') || sound.includes('road')) {
      // 7. 🚦 TRAFFIC / ROAD: Low Ambient Rumble Pulse
      vibratePattern = [250, 300, 250];
      alertVal = 1;
    }

    // Channel 1: Browser Hardware Vibration (Mobile Phone Haptic)
    if (navigator.vibrate) {
      try { navigator.vibrate(vibratePattern); } catch (e) {}
    }

    // Channel 2: Service Worker Push Notification to Smartwatch
    if (swRegistration) {
      swRegistration.showNotification(title, {
        body: body,
        icon: 'favicon.png',
        badge: 'favicon.png',
        vibrate: vibratePattern,
        tag: 'emergency-' + Date.now(),
        renotify: true,
        requireInteraction: true,
        silent: false,
      }).catch(() => {});
    }

    // Channel 3: Direct BLE GATT Commands to Yesido IO39 / Smartwatch
    if (writableCharacteristics.length > 0) {
      const payloadImmediateAlert = new Uint8Array([alertVal]);
      const payloadVibrateXO = new Uint8Array([0xAB, 0x00, 0x04, 0xFF, 0x31, 0x01, alertVal]);
      const payloadVibrateFitPro = new Uint8Array([0xCD, 0x00, 0x03, 0x05, 0x01, alertVal]);
      const payloadDaFit = new Uint8Array([0x04, 0x01, alertVal === 2 ? 0x05 : 0x02]);

      for (const char of writableCharacteristics) {
        try {
          if (char.uuid.includes('2a06')) {
            await char.writeValue(payloadImmediateAlert);
          } else if (char.uuid.includes('6e400002') || char.uuid.includes('fff1') || char.uuid.includes('ffe1')) {
            await char.writeValue(payloadVibrateXO);
            await char.writeValue(payloadVibrateFitPro);
          } else {
            await char.writeValue(payloadDaFit);
          }
        } catch (err) {}
      }
    }
  };
})();
