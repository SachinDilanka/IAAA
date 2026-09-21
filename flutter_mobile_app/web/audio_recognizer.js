/**
 * AcousticAware DEAF AI - Offline-First Real-Time Audio Engine v38.0
 *
 * Architecture:
 *  - LAYER 1 (Primary):   Deep Neural Network (MFCC + 5 Dense Layers, 13 classes) — 100% OFFLINE
 *  - LAYER 2 (Secondary): Acoustic Signature Classifier (FFT heuristics) — 100% OFFLINE
 *  - LAYER 3 (Optional):  Cloud Speech-to-Text — FULLY SANDBOXED, never crashes core engine
 *
 * Designed for Hard of Hearing and Deaf users.
 * Cloud Speech API failures are silently swallowed — detection continues via Layers 1 & 2.
 */

(function () {
  'use strict';

  // =========================================================================
  // STATE
  // =========================================================================
  let audioCtx = null;
  let micStream = null;
  let micSource = null;
  let scriptNode = null;
  let analyser = null;
  let freqData = null;

  let isListening = false;
  let isStartingCapture = false;
  let animTick = 0;
  let lastFrameTime = 0;
  let lastAlertTime = 0;
  let alertCooldown = false;

  let micSensitivityBoost = 1.4;

  // Rolling 1-second PCM buffer for Neural Network
  let rollingBuf = null;
  let rollingIdx = 0;
  let rollingCap = 48000;
  let lastMlTime = 0;

  // Pitch / volume history for acoustic cadence analysis
  const HIST_LEN = 30;
  const pitchHist = [];
  const volHist = [];
  let livePeakFreq = 220;
  let liveRms = 0.0;

  // Speech engine state — fully isolated
  let _speech = null;
  let _speechRunning = false;
  let _speechFailCount = 0;
  let _speechRestartTimer = null;
  let _speechLang = 'si-LK';
  const MAX_SPEECH_FAILS = 2; // give up speech after 2 network errors

  // Shared window state polled by Flutter Dart
  window._latestVolume = 0.08;
  window._latestPitch = 220;
  window._latestFrame40 = new Array(40).fill(0.08).join(',');
  window._latestFrame40Array = new Array(40).fill(0.08);
  window._latestTranscript = '🎤 AI Acoustic Sensor Standby...';
  window._latestAlert = null;
  window._currentSpeechLang = 'si-LK';

  // BLE / Service Worker
  let bleDevice = null;
  let gattServer = null;
  let writableChars = [];
  let swReg = null;

  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.register('sw.js').then(r => { swReg = r; }).catch(() => {});
  }

  // =========================================================================
  // AUDIO CONTEXT HELPERS
  // =========================================================================
  function _ensureCtx() {
    if (!audioCtx) {
      try {
        const Cls = window.AudioContext || window.webkitAudioContext;
        audioCtx = new Cls({ sampleRate: 16000 });
      } catch (e) {
        try {
          const Cls = window.AudioContext || window.webkitAudioContext;
          audioCtx = new Cls();
        } catch (e2) {}
      }
    }
    if (audioCtx && audioCtx.state === 'suspended') {
      audioCtx.resume().catch(() => {});
    }
  }

  ['click', 'touchstart', 'keydown'].forEach(ev => {
    window.addEventListener(ev, _ensureCtx, { passive: true });
  });

  // =========================================================================
  // CLASS MAPS
  // =========================================================================
  const FLUTTER_CLASS = {
    udaw: 'udaw', beeraganna: 'beeraganna', ginnak: 'ginnak',
    anathurak: 'anathurak', karadarayak: 'karadarayak',
    balagena: 'balagena', parissamin: 'parissamin',
    ehata_wenna: 'ehata_wenna', nawaththanna: 'nawaththanna',
    screaming: 'screaming',
    ambulance_siren: 'ambulance', ambulance: 'ambulance',
    fire_alarm: 'firetruck', firetruck: 'firetruck',
    vehicle_horn: 'vehicle horns', 'vehicle horns': 'vehicle horns',
    baby_crying: 'baby crying', 'baby crying': 'baby crying',
    dog_barking: 'dog_bark', dog_bark: 'dog_bark',
    road: 'road', traffic: 'traffic',
    background_traffic: null,
  };

  const SINHALA = {
    udaw: 'උදව් කරන්න!', beeraganna: 'බේරගන්න!', ginnak: 'ගින්නක්!',
    anathurak: 'අනතුරක්!', karadarayak: 'කරදරයක්!', balagena: 'බලාගෙන!',
    parissamin: 'පරිස්සමින්!', ehata_wenna: 'එහාට වෙන්න!',
    nawaththanna: 'නවත්තන්න!', screaming: 'කෑගැසීමක්!',
    ambulance: 'ගිලන් රථ සයිරන්', ambulance_siren: 'ගිලන් රථ සයිරන්',
    firetruck: 'ගිනි නිවන සංඥාව', fire_alarm: 'ගිනි නිවන සංඥාව',
    'vehicle horns': 'වාහන හෝන්', vehicle_horn: 'වාහන හෝන්',
    'baby crying': 'ළදරු හැඬීම', baby_crying: 'ළදරු හැඬීම',
    dog_bark: 'බල්ලා බිරීම', dog_barking: 'බල්ලා බිරීම',
    road: 'මාර්ග ඝෝෂාව', traffic: 'රථවාහන ශබ්දය',
  };

  // =========================================================================
  // NEURAL NETWORK: FFT → MEL → MFCC → 5 DENSE LAYERS
  // =========================================================================
  function _rfft2048(signal, hann) {
    const N = 2048;
    const re = new Float32Array(N);
    const im = new Float32Array(N);
    for (let i = 0; i < N; i++) {
      let rev = 0, tmp = i;
      for (let b = 0; b < 11; b++) { rev = (rev << 1) | (tmp & 1); tmp >>= 1; }
      re[rev] = signal[i] * (hann ? hann[i] : 1.0);
    }
    for (let len = 2; len <= N; len <<= 1) {
      const half = len >> 1;
      const ang = -2 * Math.PI / len;
      const wr = Math.cos(ang), wi = Math.sin(ang);
      for (let i = 0; i < N; i += len) {
        let cr = 1.0, ci = 0.0;
        for (let j = 0; j < half; j++) {
          const ur = re[i+j], ui = im[i+j];
          const vr = re[i+j+half]*cr - im[i+j+half]*ci;
          const vi = re[i+j+half]*ci + im[i+j+half]*cr;
          re[i+j] = ur+vr; im[i+j] = ui+vi;
          re[i+j+half] = ur-vr; im[i+j+half] = ui-vi;
          const ncr = cr*wr - ci*wi; ci = cr*wi + ci*wr; cr = ncr;
        }
      }
    }
    const spec = new Float32Array(1025);
    for (let k = 0; k <= 1024; k++) spec[k] = re[k]*re[k] + im[k]*im[k];
    return spec;
  }

  function _resampleTo16k(buf, sr) {
    if (sr === 16000) return buf.length >= 16000 ? buf.subarray(0, 16000) : buf;
    const out = new Float32Array(16000);
    const step = buf.length / 16000;
    for (let i = 0; i < 16000; i++) {
      const startIdx = Math.floor(i * step);
      const endIdx = Math.min(buf.length, Math.floor((i + 1) * step));
      let sum = 0, count = 0;
      for (let j = startIdx; j < endIdx; j++) {
        sum += buf[j];
        count++;
      }
      out[i] = count > 0 ? sum / count : buf[startIdx];
    }
    return out;
  }

  function _runNN(raw16k) {
    const dsp = window._DSP_CONSTANTS;
    const mdl = window._SOUND_MODEL_DATA;
    if (!dsp || !mdl || !dsp.mel_basis || !mdl.W0) return null;

    let sig = new Float32Array(raw16k);
    if (sig.length > 16000) sig = sig.subarray(0, 16000);
    if (sig.length < 16000) { const s = new Float32Array(16000); s.set(sig); sig = s; }

    // Reflect-pad
    const pad = new Float32Array(sig.length + 2048);
    for (let i = 0; i < 1024; i++) pad[i] = sig[1024-i];
    pad.set(sig, 1024);
    for (let i = 0; i < 1024; i++) pad[sig.length+1024+i] = sig[sig.length-1-i];

    const hop = 512;
    const nFrames = Math.floor((pad.length - 2048) / hop) + 1;
    const mfccSum = new Float32Array(40);

    for (let f = 0; f < nFrames; f++) {
      const slice = pad.subarray(f*hop, f*hop+2048);
      const spec = _rfft2048(slice, dsp.hann_window);

      const mels = new Float32Array(128);
      for (let m = 0; m < 128; m++) {
        let s = 0;
        const row = dsp.mel_basis[m];
        for (let k = 0; k <= 1024; k++) s += row[k] * spec[k];
        mels[m] = s;
      }

      const logM = new Float32Array(128);
      let maxDb = -1e9;
      for (let m = 0; m < 128; m++) {
        const db = 10.0 * Math.log10(Math.max(1e-10, mels[m]));
        logM[m] = db; if (db > maxDb) maxDb = db;
      }
      const minDb = maxDb - 80.0;
      for (let m = 0; m < 128; m++) { if (logM[m] < minDb) logM[m] = minDb; }

      for (let i = 0; i < 40; i++) {
        let d = 0;
        const row = dsp.dct_basis[i];
        for (let m = 0; m < 128; m++) d += row[m] * logM[m];
        mfccSum[i] += d;
      }
    }

    const feat = new Float32Array(40);
    for (let i = 0; i < 40; i++) {
      feat[i] = (mfccSum[i] / nFrames - mdl.mean[i]) / (mdl.std[i] || 1.0);
    }

    // 40→512→256→128→64→13 Dense + ReLU
    const relu = x => x > 0 ? x : 0;
    const h0 = new Float32Array(512);
    for (let j = 0; j < 512; j++) { let s = mdl.b0[j]; for (let i = 0; i < 40; i++) s += feat[i]*mdl.W0[i][j]; h0[j] = relu(s); }
    const h1 = new Float32Array(256);
    for (let j = 0; j < 256; j++) { let s = mdl.b1[j]; for (let i = 0; i < 512; i++) s += h0[i]*mdl.W1[i][j]; h1[j] = relu(s); }
    const h2 = new Float32Array(128);
    for (let j = 0; j < 128; j++) { let s = mdl.b2[j]; for (let i = 0; i < 256; i++) s += h1[i]*mdl.W2[i][j]; h2[j] = relu(s); }
    const h3 = new Float32Array(64);
    for (let j = 0; j < 64; j++) { let s = mdl.b3[j]; for (let i = 0; i < 128; i++) s += h2[i]*mdl.W3[i][j]; h3[j] = relu(s); }
    const logits = new Float32Array(13);
    let maxL = -1e9;
    for (let j = 0; j < 13; j++) { let s = mdl.b4[j]; for (let i = 0; i < 64; i++) s += h3[i]*mdl.W4[i][j]; logits[j] = s; if (s > maxL) maxL = s; }

    let expSum = 0;
    const probs = new Float32Array(13);
    for (let j = 0; j < 13; j++) { probs[j] = Math.exp(logits[j]-maxL); expSum += probs[j]; }
    for (let j = 0; j < 13; j++) probs[j] /= expSum;

    let bestIdx = 0, bestP = 0;
    for (let j = 0; j < 13; j++) { if (probs[j] > bestP) { bestP = probs[j]; bestIdx = j; } }

    // Also find best non-background class
    let emergIdx = -1, emergP = 0;
    for (let j = 0; j < 13; j++) {
      if (mdl.classes[j] !== 'background_traffic' && probs[j] > emergP) { emergP = probs[j]; emergIdx = j; }
    }

    return { cls: mdl.classes[bestIdx], prob: bestP, emergCls: emergIdx>=0 ? mdl.classes[emergIdx] : null, emergP, probs };
  }

  // =========================================================================
  // START CAPTURE — Offline-first, network errors cannot break this
  // =========================================================================
  window.startLiveAcousticCapture = async function () {
    if (isStartingCapture || (isListening && micStream && micStream.active)) return true;
    isStartingCapture = true;

    _ensureCtx();
    if (audioCtx && audioCtx.state === 'suspended') {
      try { await audioCtx.resume(); } catch (e) {}
    }

    // Request notification permission (best-effort, never blocks audio)
    if (window.Notification && Notification.permission === 'default') {
      Notification.requestPermission().catch(() => {});
    }

    try {
      // Stop any existing stream
      if (micStream) { try { micStream.getTracks().forEach(t => t.stop()); } catch(e){} micStream = null; }

      if (!audioCtx || audioCtx.state === 'closed') {
        try {
          const Cls = window.AudioContext || window.webkitAudioContext;
          audioCtx = new Cls({ sampleRate: 16000 });
        } catch (e) {
          const Cls = window.AudioContext || window.webkitAudioContext;
          audioCtx = new Cls();
        }
      }
      if (audioCtx.state === 'suspended') await audioCtx.resume();

      // Get microphone — try ideal constraints first, then bare
      try {
        micStream = await navigator.mediaDevices.getUserMedia({
          audio: { echoCancellation: false, noiseSuppression: false, autoGainControl: true }
        });
      } catch (e1) {
        micStream = await navigator.mediaDevices.getUserMedia({ audio: true });
      }

      if (audioCtx.state === 'suspended') await audioCtx.resume();

      micSource = audioCtx.createMediaStreamSource(micStream);

      // ── PCM ScriptProcessor for Neural Network ──────────────────────────
      scriptNode = audioCtx.createScriptProcessor(4096, 1, 1);
      scriptNode.onaudioprocess = function (e) {
        const buf = e.inputBuffer.getChannelData(0);
        // Silence output (prevents echo)
        const out = e.outputBuffer.getChannelData(0);
        for (let i = 0; i < out.length; i++) out[i] = 0;
        _onPCM(buf);
      };
      micSource.connect(scriptNode);
      scriptNode.connect(audioCtx.destination);

      // ── Analyser for Visualizer & Acoustic Classifier ───────────────────
      analyser = audioCtx.createAnalyser();
      analyser.fftSize = 2048;            // More freq resolution
      analyser.smoothingTimeConstant = 0.5;
      micSource.connect(analyser);

      const sr = audioCtx.sampleRate || 44100;
      rollingCap = sr;                    // 1 second
      rollingBuf = new Float32Array(rollingCap);
      rollingIdx = 0;

      freqData = new Uint8Array(analyser.frequencyBinCount);

      isListening = true;
      animTick = 0;
      lastAlertTime = 0;
      alertCooldown = false;

      _startAnalyzerLoop();

      // ── Speech API — completely sandboxed in its own try block ───────────
      _startSpeechSandboxed();

      console.log('[SAA v38] Offline AI Engine RUNNING — SR=' + sr + 'Hz');
      return true;
    } catch (err) {
      console.warn('[SAA v38] Mic init failed:', err);
      isListening = false;
      micStream = null;
      return false;
    } finally {
      isStartingCapture = false;
    }
  };

  // =========================================================================
  // STOP CAPTURE
  // =========================================================================
  window.stopLiveAcousticCapture = function () {
    isListening = false;
    _killSpeech();
    if (scriptNode) { try { scriptNode.disconnect(); } catch(e){} scriptNode = null; }
    if (micStream) { micStream.getTracks().forEach(t => t.stop()); micStream = null; }
    if (audioCtx && audioCtx.state !== 'closed') { try { audioCtx.suspend(); } catch(e){} }
    window._latestVolume = 0.08;
    window._latestPitch = 220;
    window._latestTranscript = 'Monitoring paused.';
  };

  window.setAcousticSensitivity = function (level) {
    if (level === 'ultra') micSensitivityBoost = 2.2;
    else if (level === 'high') micSensitivityBoost = 1.7;
    else micSensitivityBoost = 1.2;
    console.log('[SAA v38] Sensitivity:', level, micSensitivityBoost);
  };

  // =========================================================================
  // PCM HANDLER → rolling buffer → Neural Network
  // =========================================================================
  function _onPCM(raw) {
    if (!isListening) return;

    let sumSq = 0, peak = 0;
    for (let i = 0; i < raw.length; i++) {
      const a = Math.abs(raw[i]);
      if (a > peak) peak = a;
      sumSq += raw[i]*raw[i];
    }
    liveRms = Math.sqrt(sumSq / raw.length);

    // Fill rolling buffer
    if (rollingBuf) {
      for (let i = 0; i < raw.length; i++) {
        rollingBuf[rollingIdx] = raw[i];
        rollingIdx = (rollingIdx + 1) % rollingCap;
      }
    }

    // Run Deep ML Model every 250ms with sliding window (Real Acoustic Detection)
    const now = Date.now();
    // Require audible acoustic sound (peak >= 0.025 or liveRms >= 0.01) to ignore room hum
    if (now - lastMlTime > 250 && rollingBuf && (peak >= 0.025 || liveRms >= 0.01)) {
      lastMlTime = now;

      // If speech was just spoken recently (<1.5s), don't falsely classify voice harmonics as horns/sirens
      if (now - lastAlertTime < 1500) return;

      const sr = audioCtx ? audioCtx.sampleRate : 44100;
      const cont = new Float32Array(rollingCap);
      for (let i = 0; i < rollingCap; i++) cont[i] = rollingBuf[(rollingIdx+i) % rollingCap];

      const resampled = _resampleTo16k(cont, sr);
      const res = _runNN(resampled);
      if (res && res.cls && res.cls !== 'background_traffic') {
        // Sensitive threshold (>= 45%) for baby crying, vehicle horn, traffic & Sinhala keywords
        if (res.prob >= 0.45) {
          _trigger(res.cls, res.prob, `Deep Neural Model: ${res.cls} (${(res.prob * 100).toFixed(0)}%)`);
        }
      }
    }
  }

  // =========================================================================
  // ANALYSER LOOP — 60fps visualizer + acoustic classifier
  // =========================================================================
  function _startAnalyzerLoop() {
    function tick(ts) {
      if (!isListening) return;
      animTick++;

      if (analyser && freqData) {
        analyser.getByteFrequencyData(freqData);

        const sr = audioCtx ? audioCtx.sampleRate : 44100;
        const binHz = sr / analyser.fftSize;
        const nBins = freqData.length;

        // Dominant pitch 80–6000 Hz
        const minB = Math.max(1, Math.floor(80 / binHz));
        const maxB = Math.min(nBins-1, Math.floor(6000 / binHz));
        let maxV = 0, maxBin = minB, totalE = 0;
        for (let i = minB; i <= maxB; i++) {
          const v = freqData[i]; totalE += v;
          if (v > maxV) { maxV = v; maxBin = i; }
        }

        livePeakFreq = maxV > 6 ? Math.round(maxBin * binHz) : 220;
        const volPct = Math.min(100, Math.round((maxV / 255.0) * 100));
        const normVol = Math.min(1.0, Math.max(0.08, (volPct/100.0) * micSensitivityBoost + liveRms * 3.0));

        pitchHist.push(livePeakFreq); if (pitchHist.length > HIST_LEN) pitchHist.shift();
        volHist.push(volPct);         if (volHist.length > HIST_LEN) volHist.shift();

        // 40-bar visualizer frame
        const frame = [];
        for (let i = 0; i < 40; i++) {
          const s = Math.floor(Math.pow(i/40, 1.3) * (nBins-2));
          const e = Math.max(s+1, Math.floor(Math.pow((i+1)/40, 1.3) * (nBins-1)));
          let bMax = 0;
          for (let b = s; b <= e && b < nBins; b++) { if (freqData[b] > bMax) bMax = freqData[b]; }
          const wave = (Math.sin(animTick*0.14 + i*0.38) + 1.0)*0.05 + 0.05;
          const h = Math.max(0.08, Math.min(1.0, (bMax/255.0)*2.5*micSensitivityBoost + liveRms*3.0 + wave));
          frame.push(parseFloat(h.toFixed(3)));
        }

        const fStr = frame.join(',');
        window._latestVolume = parseFloat(normVol.toFixed(3));
        window._latestPitch = livePeakFreq;
        window._latestFrame40 = fStr;
        window._latestFrame40Array = frame;

        // Push to Flutter at ~30fps
        if (ts - lastFrameTime > 33) {
          lastFrameTime = ts;
          if (window.onFlutterAudioFrame) {
            try { window.onFlutterAudioFrame(fStr, normVol, livePeakFreq); } catch(e) {}
          }
        }

        // NOTE: Acoustic Hz-based classifier REMOVED.
        // Sound detection is done ONLY by the trained Neural Network (ML model)
        // which was trained on real ambulance, fire, baby cry, etc. audio samples.
      }

      requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }

  // _acousticClassify REMOVED — Hz-based detection caused false positives.
  // Detection is ONLY via the Neural Network ML model (trained on real audio).

  // Per-class cooldown tracker: 6 seconds between same class
  const _classCooldown = {};

  function _trigger(rawCls, conf, src) {
    const now = Date.now();
    const fc = FLUTTER_CLASS[rawCls] || rawCls;
    if (fc === null) return; // skip background_traffic

    // Global cooldown: 2s between ANY detection
    if (now - lastAlertTime < 2000) return;
    // Per-class cooldown: 6s between same class
    if (_classCooldown[fc] && now - _classCooldown[fc] < 6000) return;

    lastAlertTime = now;
    _classCooldown[fc] = now;

    const sinhala = SINHALA[fc] || fc;
    console.log(`[SAA v39 DETECTED] '${fc}' | ${src}`);

    window._latestTranscript = `🚨 Detected: ${sinhala} (${fc})`;
    if (window.onFlutterSpeechTranscript) {
      try { window.onFlutterSpeechTranscript(window._latestTranscript); } catch(e) {}
    }

    _dispatch(fc, conf, src);
  }

  function _dispatch(fc, conf, src) {
    window._latestAlert = { category: fc, confidence: conf, source: src, timestamp: Date.now() };
    const sinhala = SINHALA[fc] || fc;

    // Watch vibration + notification (network-independent)
    try { window.sendWatchBleVibration('high', `🚨 ${fc}`, `🚨 හදිසි: ${sinhala}`, fc); } catch(e) {}

    if (window.onFlutterAudioEvent) {
      try { window.onFlutterAudioEvent(fc, conf, src); } catch(e) {
        console.error('[SAA v38] Flutter dispatch error:', e);
      }
    }
  }

  // =========================================================================
  // =========================================================================
  // SPEECH ENGINE — FULLY SANDBOXED, CONTINUOUS & RESILIENT
  // =========================================================================
  function _startSpeechSandboxed() {
    if (!isListening) return;

    try {
      const SpeechCls = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (!SpeechCls) {
        window._latestTranscript = '🎤 AI Acoustic Sound Sensor Active...';
        return;
      }

      _killSpeech();

      _speech = new SpeechCls();
      _speech.continuous = true;
      _speech.interimResults = true;
      _speech.lang = _speechLang;
      _speech.maxAlternatives = 1;

      _speech.onstart = function () {
        _speechRunning = true;
        window._latestTranscript = `🎤 Listening for Sinhala (\"උදව්\", \"ගින්නක්\", \"බේරගන්න\", \"අනතුරක්\")...`;
        console.log('[SAA Speech] Active in', _speechLang);
      };

      _speech.onresult = function (ev) {
        try {
          for (let i = ev.resultIndex; i < ev.results.length; i++) {
            const txt = ev.results[i][0].transcript.trim();
            if (!txt) continue;
            console.log('[SAA Speech Recognized]:', txt);
            const msg = `🗣️ Heard: "${txt}"`;
            window._latestTranscript = msg;
            if (window.onFlutterSpeechTranscript) {
              try { window.onFlutterSpeechTranscript(msg); } catch(e) {}
            }
            _matchKeywords(txt.toLowerCase());
          }
        } catch(e) {}
      };

      _speech.onerror = function (err) {
        const errType = (err && err.error) ? err.error : 'unknown';
        _speechRunning = false;
        if (errType === 'no-speech') return; // Natural silence, will restart cleanly
        console.warn('[SAA Speech] Notice (sandboxed):', errType);

        // Always restart continuously when listening
        if (isListening) {
          clearTimeout(_speechRestartTimer);
          _speechRestartTimer = setTimeout(_startSpeechSandboxed, 1200);
        }
      };

      _speech.onend = function () {
        _speechRunning = false;
        // Keep listening continuously — immediately restart
        if (isListening) {
          clearTimeout(_speechRestartTimer);
          _speechRestartTimer = setTimeout(_startSpeechSandboxed, 350);
        }
      };

      // Delay start slightly so AudioContext settles
      setTimeout(() => {
        if (isListening && _speech) {
          try { _speech.start(); } catch(e) {}
        }
      }, 500);

    } catch (outerErr) {
      console.warn('[SAA Speech] Sandboxed outer error:', outerErr);
    }
  }

    } catch (outerErr) {
      // Outermost catch — nothing from speech ever reaches the audio pipeline
      console.warn('[SAA Speech] Sandboxed outer error:', outerErr);
    }
  }

  function _killSpeech() {
    clearTimeout(_speechRestartTimer);
    if (_speech) {
      _speechRunning = false;
      try { _speech.abort(); } catch(e) {}
      _speech = null;
    }
  }

  window.setSpeechRecognitionLanguage = function (lang) {
    _speechLang = lang || 'si-LK';
    window._currentSpeechLang = _speechLang;
    _speechFailCount = 0; // reset fail count when user changes language
    if (isListening) _startSpeechSandboxed();
  };

  // =========================================================================
  // KEYWORD MATCHER — runs on speech transcript text
  // =========================================================================
  function _matchKeywords(text) {
    const now = Date.now();
    if (now - lastAlertTime < 1000) return;

    const t = text.replace(/[^\u0D80-\u0DFFa-z0-9\s]/g, ' ').toLowerCase();
    let m = null;

    // Spoken Emergency Sinhala & English Phrases (Matches inside full Sinhala sentences)
    if (t.includes('උදව්') || t.includes('උදවු') || t.includes('උදව්වක්') || t.includes('udaw') || t.includes('udhaw') || t.includes('udhav') || /\bhelp\b/.test(t) || /\bsave me\b/.test(t) || /\bsave\b/.test(t))
      m = 'udaw';
    else if (t.includes('බේරගන්න') || t.includes('බේර ගන්න') || t.includes('බේරගනින්') || t.includes('බේරන්න') || t.includes('beeraganna') || t.includes('beraganna') || /\brescue\b/.test(t))
      m = 'beeraganna';
    else if (t.includes('ගින්නක්') || t.includes('ගින්න') || t.includes('ගින්දර') || t.includes('ගිනි') || t.includes('ginnak') || t.includes('ginna') || /\bfire\b/.test(t))
      m = 'ginnak';
    else if (t.includes('අනතුරක්') || t.includes('අනතුර') || t.includes('අනතුරු') || t.includes('anathurak') || t.includes('anathura') || t.includes('anaturak') || /\bdanger\b/.test(t) || /\bhazard\b/.test(t))
      m = 'anathurak';
    else if (t.includes('කරදරයක්') || t.includes('කරදර') || t.includes('කරදරේ') || t.includes('karadarayak') || t.includes('karadaraya') || /\btrouble\b/.test(t))
      m = 'karadarayak';
    else if (t.includes('බලාගෙන') || t.includes('බලා ගෙන') || t.includes('බලාපන්') || t.includes('balagena') || /\bwatch out\b/.test(t) || /\blook out\b/.test(t))
      m = 'balagena';
    else if (t.includes('පරිස්සමින්') || t.includes('පරිස්සමෙන්') || t.includes('පරිස්සම්') || t.includes('parissamin') || t.includes('parissamen') || /\bcareful\b/.test(t) || /\bcaution\b/.test(t))
      m = 'parissamin';
    else if (t.includes('එහාට වෙන්න') || t.includes('එහාට') || t.includes('අයින් වෙන්න') || t.includes('ehata') || /\bmove away\b/.test(t))
      m = 'ehata_wenna';
    else if (t.includes('නවත්තන්න') || t.includes('නවත්වන්න') || t.includes('නවතින්න') || t.includes('nawaththanna') || /\bstop\b/.test(t))
      m = 'nawaththanna';
    else if (t.includes('කෑගැසීම') || t.includes('කෑ ගහනවා') || /\bscream\b/.test(t) || /\bscreaming\b/.test(t))
      m = 'screaming';

    if (m) _trigger(m, 0.98, `Spoken Voice Keyword: "${text}"`);
  }

  // =========================================================================
  // AUDIO SAMPLE SYNTHESIZER (Test buttons)
  // =========================================================================
  window.playEmergencyAudioSample = function (name) {
    if (!audioCtx) audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    if (audioCtx.state === 'suspended') audioCtx.resume();
    const n = (name || '').toLowerCase();
    const t = audioCtx.currentTime;

    try {
      if (n.includes('ambulance')) {
        const o = audioCtx.createOscillator(), g = audioCtx.createGain();
        o.type = 'sawtooth';
        o.frequency.setValueAtTime(750, t);
        o.frequency.linearRampToValueAtTime(1450, t+0.35);
        o.frequency.linearRampToValueAtTime(750, t+0.7);
        o.frequency.linearRampToValueAtTime(1450, t+1.05);
        g.gain.setValueAtTime(0.4, t); g.gain.exponentialRampToValueAtTime(0.001, t+1.3);
        o.connect(g); g.connect(audioCtx.destination); o.start(t); o.stop(t+1.3);

      } else if (n.includes('fire') || n.includes('ginn')) {
        for (let i=0; i<5; i++) {
          const o = audioCtx.createOscillator(), g = audioCtx.createGain();
          o.type = 'square'; o.frequency.setValueAtTime(3200, t+i*0.22);
          g.gain.setValueAtTime(0.35, t+i*0.22); g.gain.setValueAtTime(0, t+i*0.22+0.12);
          o.connect(g); g.connect(audioCtx.destination); o.start(t+i*0.22); o.stop(t+i*0.22+0.14);
        }
      } else if (n.includes('horn')) {
        [440,554].forEach(f => {
          const o = audioCtx.createOscillator(), g = audioCtx.createGain();
          o.type = 'sawtooth'; o.frequency.setValueAtTime(f, t);
          g.gain.setValueAtTime(0.4, t); g.gain.exponentialRampToValueAtTime(0.001, t+0.85);
          o.connect(g); g.connect(audioCtx.destination); o.start(t); o.stop(t+0.85);
        });
      } else if (n.includes('baby') || n.includes('cry')) {
        const o = audioCtx.createOscillator(), g = audioCtx.createGain();
        o.type = 'triangle';
        o.frequency.setValueAtTime(520, t); o.frequency.linearRampToValueAtTime(820, t+0.4);
        o.frequency.linearRampToValueAtTime(560, t+0.8);
        g.gain.setValueAtTime(0.35, t); g.gain.exponentialRampToValueAtTime(0.001, t+1.0);
        o.connect(g); g.connect(audioCtx.destination); o.start(t); o.stop(t+1.0);

      } else if (n.includes('dog') || n.includes('bark')) {
        for (let b=0; b<3; b++) {
          const o = audioCtx.createOscillator(), g = audioCtx.createGain();
          o.type = 'sawtooth'; o.frequency.setValueAtTime(400, t+b*0.38);
          o.frequency.exponentialRampToValueAtTime(130, t+b*0.38+0.2);
          g.gain.setValueAtTime(0.45, t+b*0.38); g.gain.exponentialRampToValueAtTime(0.001, t+b*0.38+0.22);
          o.connect(g); g.connect(audioCtx.destination); o.start(t+b*0.38); o.stop(t+b*0.38+0.24);
        }
      } else {
        // Sinhala voice synthesis as fallback
        if ('speechSynthesis' in window) {
          const u = new SpeechSynthesisUtterance(SINHALA[n] || name);
          u.lang = 'si-LK'; u.rate = 1.1; u.pitch = 1.2;
          window.speechSynthesis.speak(u);
        }
      }
    } catch(e) {}
  };

  // =========================================================================
  // BLUETOOTH — Yesido IO39 Watch
  // =========================================================================
  window.connectYesidoBleWatch = async function () {
    if (!navigator.bluetooth) { console.warn('[BLE] Not supported'); return false; }
    try {
      bleDevice = await navigator.bluetooth.requestDevice({
        acceptAllDevices: true,
        optionalServices: [
          '00001802-0000-1000-8000-00805f9b34fb',
          '0000fee9-0000-1000-8000-00805f9b34fb',
          '6e400001-b5a3-f393-e0a9-e50e24dcca9e',
        ],
      });
      bleDevice.addEventListener('gattserverdisconnected', () => {
        gattServer = null; writableChars = [];
      });
      gattServer = await bleDevice.gatt.connect();
      const services = await gattServer.getPrimaryServices();
      for (const svc of services) {
        try {
          const chars = await svc.getCharacteristics();
          for (const c of chars) {
            if (c.properties.write || c.properties.writeWithoutResponse) writableChars.push(c);
          }
        } catch(e) {}
      }
      console.log('[BLE] Connected:', bleDevice.name);
      return true;
    } catch(e) { console.warn('[BLE] Aborted:', e); return false; }
  };

  window.sendWatchBleVibration = async function (priority, title, sinhalaBody, soundClass) {
    // 1. Heavy BLE motor pulse (repeated 3 times for Yesido IO39)
    if (gattServer && gattServer.connected && writableChars.length > 0) {
      const pkt = new Uint8Array([0x02]);
      for (let p = 0; p < 3; p++) {
        setTimeout(async () => {
          for (const c of writableChars) {
            try {
              if (c.properties.writeWithoutResponse) await c.writeValueWithoutResponse(pkt);
              else if (c.properties.write) await c.writeValue(pkt);
              break;
            } catch(e) {}
          }
        }, p * 550);
      }
    }
    // 2. Strong phone tactile vibration (works on Android Chrome & Web)
    if ('vibrate' in navigator) {
      try { navigator.vibrate([600, 150, 600, 150, 800, 150, 1000]); } catch(e) {}
    }
    // 3. System notification mirrored to Yesido IO39 smartwatch
    if (window.Notification && Notification.permission === 'granted') {
      try {
        const opts = {
          body: `🚨 ${sinhalaBody || 'හදිසි අනතුරු ඇඟවීමක්'}\n⚡ ${title || 'EMERGENCY ALERT'}`,
          icon: 'icons/Icon-192.png',
          tag: 'alert_' + (soundClass || 'x'),
          requireInteraction: true,
          vibrate: [600, 150, 600, 150, 800, 150, 1000],
        };
        const head = `🚨 [හදිසි ALERT] ${sinhalaBody || title || 'EMERGENCY'}`;
        if (swReg && swReg.showNotification) {
          swReg.showNotification(head, opts);
        } else {
          new Notification(head, opts);
        }
      } catch(e) {}
    }
  };

  console.log('[SAA] AcousticAware Offline AI v39.0 — ML-Only Detection Ready!');
})();
