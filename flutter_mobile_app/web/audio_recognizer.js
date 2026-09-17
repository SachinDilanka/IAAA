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
        audioCtx = new Cls();
      } catch (e) {}
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
    const ratio = (buf.length - 1) / 15999;
    for (let i = 0; i < 16000; i++) {
      const s = i * ratio, lo = Math.floor(s), hi = Math.min(lo+1, buf.length-1);
      out[i] = buf[lo] * (1 - (s-lo)) + buf[hi] * (s-lo);
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
        const Cls = window.AudioContext || window.webkitAudioContext;
        audioCtx = new Cls();
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

    // Run NN every 150ms — threshold very low (0.0008) so whispers are caught
    const now = Date.now();
    if (now - lastMlTime > 150 && rollingBuf && (peak >= 0.0008 || liveRms >= 0.0003)) {
      lastMlTime = now;

      const sr = audioCtx ? audioCtx.sampleRate : 44100;
      // Linearize rolling buffer into continuous array
      const cont = new Float32Array(rollingCap);
      for (let i = 0; i < rollingCap; i++) cont[i] = rollingBuf[(rollingIdx+i) % rollingCap];

      const resampled = _resampleTo16k(cont, sr);
      const res = _runNN(resampled);
      if (res) {
        // Fire if top class is not background AND prob >= 0.12 (very sensitive)
        if (res.cls && res.cls !== 'background_traffic' && res.prob >= 0.12) {
          _trigger(res.cls, res.prob, `ML Model: ${res.cls} (${(res.prob*100).toFixed(0)}%)`);
        } else if (res.emergCls && res.emergP >= 0.12) {
          _trigger(res.emergCls, res.emergP, `ML Emerg: ${res.emergCls} (${(res.emergP*100).toFixed(0)}%)`);
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

        // Acoustic Classifier — runs every frame, very cheap FFT heuristics
        _acousticClassify(volPct, livePeakFreq, binHz, nBins);
      }

      requestAnimationFrame(tick);
    }
    requestAnimationFrame(tick);
  }

  function _acousticClassify(volPct, peakHz, binHz, nBins) {
    if (alertCooldown) return;
    const now = Date.now();
    if (now - lastAlertTime < 900) return;

    // Very low threshold so faint sounds are still caught
    if (volPct < 4 && liveRms < 0.003) return;

    // Band energy
    let eLow=0, eMid=0, eHigh=0, eUltra=0;
    for (let i=0; i<nBins; i++) {
      const f = i*binHz, v = freqData[i];
      if (f>=80  && f<650)   eLow   += v;
      else if (f>=650 && f<1600) eMid  += v;
      else if (f>=1600&& f<3500) eHigh += v;
      else if (f>=3500&& f<=6000)eUltra+= v;
    }

    // Pitch dynamics
    let minP=99999, maxP=0;
    for (const p of pitchHist) { if(p<minP) minP=p; if(p>maxP) maxP=p; }
    const pitchDelta = maxP - minP;

    const volRise = volHist.length >= 4
      ? volHist[volHist.length-1] - volHist[Math.max(0, volHist.length-5)]
      : 0;

    let matched = null, conf = 0.96, src = '';

    // A. AMBULANCE SIREN — sweeping 650–1700 Hz
    if (pitchDelta >= 200 && minP >= 600 && maxP <= 1800 && eMid > eLow*0.6 && volPct >= 8) {
      matched = 'ambulance'; conf = 0.98;
      src = `Acoustic Siren (${pitchDelta}Hz sweep @ ${peakHz}Hz)`;
    }
    // B. FIRE ALARM — piercing 2400–5000 Hz
    else if (peakHz >= 2400 && peakHz <= 5000 && (eUltra > eLow || eHigh > eLow) && volPct >= 8) {
      matched = 'firetruck'; conf = 0.98;
      src = `Acoustic Fire Alarm (${peakHz}Hz)`;
    }
    // C. VEHICLE HORN — 350–950 Hz sharp burst
    else if (((peakHz>=330&&peakHz<=640)||(peakHz>=700&&peakHz<=980)) && eLow>200 && volPct>=14 && volRise>=3) {
      matched = 'vehicle horns'; conf = 0.97;
      src = `Acoustic Horn (${peakHz}Hz burst)`;
    }
    // D. BABY CRY — 450–950 Hz wail with moderate pitch variation
    else if (peakHz>=420 && peakHz<=980 && pitchDelta>=80 && pitchDelta<230 && volPct>=8 && eMid>eUltra*1.2) {
      matched = 'baby crying'; conf = 0.96;
      src = `Acoustic Baby Cry (${peakHz}Hz wail)`;
    }
    // E. DOG BARK — sharp transient, 200–1200 Hz
    else if ((volRise>=10 || liveRms>=0.025) && peakHz>=200 && peakHz<=1200) {
      matched = 'dog_bark'; conf = 0.96;
      src = `Acoustic Dog Bark (${peakHz}Hz transient)`;
    }
    // F. ROAD TRAFFIC — low rumble 80–450 Hz, sustained
    else if (peakHz>=80 && peakHz<=450 && eLow>(eMid+eHigh)*1.6 && volPct>=10) {
      matched = 'road'; conf = 0.94;
      src = `Acoustic Road Rumble (${peakHz}Hz)`;
    }
    // G. HUMAN VOICE / SINHALA KEYWORDS
    else if (volPct >= 15 && (eLow > 150 || eMid > 150)) {
      if (peakHz >= 700 && peakHz <= 2800 && volPct >= 22) {
        matched = 'screaming'; conf = 0.97;
        src = `Acoustic Scream (${peakHz}Hz)`;
      } else if (volRise >= 5 && peakHz >= 200 && peakHz <= 800) {
        // Classify by formant: udaw=low, ginnak=high, others=mid
        if (peakHz < 380)      { matched = 'udaw';      src = `Voice Formant udaw (${peakHz}Hz)`; }
        else if (peakHz > 650) { matched = 'ginnak';    src = `Voice Formant ginnak (${peakHz}Hz)`; }
        else                   { matched = 'anathurak'; src = `Voice Formant anathurak (${peakHz}Hz)`; }
        conf = 0.95;
      }
    }

    if (matched) _trigger(matched, conf, src);
  }

  // =========================================================================
  // TRIGGER — deduplicated, cooldown-guarded
  // =========================================================================
  function _trigger(rawCls, conf, src) {
    const now = Date.now();
    if (alertCooldown || (now - lastAlertTime < 900)) return;

    alertCooldown = true;
    lastAlertTime = now;

    const fc = FLUTTER_CLASS[rawCls] || rawCls;
    if (fc === null) { alertCooldown = false; return; } // skip background_traffic

    const sinhala = SINHALA[fc] || fc;
    console.log(`[SAA v38 DETECTED] '${fc}' | ${src}`);

    window._latestTranscript = `🚨 Detected: ${sinhala} (${fc})`;
    if (window.onFlutterSpeechTranscript) {
      try { window.onFlutterSpeechTranscript(window._latestTranscript); } catch(e) {}
    }

    _dispatch(fc, conf, src);

    setTimeout(() => { alertCooldown = false; }, 1000);
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
  // SPEECH ENGINE — FULLY SANDBOXED, network errors never escape
  // =========================================================================
  function _startSpeechSandboxed() {
    // If already failed too many times due to network, don't retry
    if (_speechFailCount >= MAX_SPEECH_FAILS) {
      window._latestTranscript = '🎤 Offline AI Active (Listening for Sinhala sounds & keywords)...';
      return;
    }

    try {
      const SpeechCls = window.SpeechRecognition || window.webkitSpeechRecognition;
      if (!SpeechCls) {
        window._latestTranscript = '🎤 Offline AI Active (Listening for Sinhala sounds & keywords)...';
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
        _speechFailCount = 0;
        window._latestTranscript = `🎤 Listening for Sinhala (\"උදව්\", \"ගින්නක්\", \"අනතුරක්\"...)`;
        console.log('[SAA Speech] Started in', _speechLang);
      };

      _speech.onresult = function (ev) {
        // This runs even without network for some browsers — process safely
        try {
          for (let i = ev.resultIndex; i < ev.results.length; i++) {
            const txt = ev.results[i][0].transcript.trim();
            if (!txt) continue;
            console.log('[SAA Speech]', txt);
            const msg = `🗣️ Heard: "${txt}"`;
            window._latestTranscript = msg;
            if (window.onFlutterSpeechTranscript) {
              try { window.onFlutterSpeechTranscript(msg); } catch(e) {}
            }
            _matchKeywords(txt.toLowerCase());
          }
        } catch(e) {} // never propagate
      };

      _speech.onerror = function (err) {
        // SANDBOX: catch ALL errors — network, permission, everything
        const errType = (err && err.error) ? err.error : 'unknown';
        console.warn('[SAA Speech] Error (sandboxed):', errType);

        _speechRunning = false;

        // Network errors count as failures
        if (errType === 'network' || errType === 'service-not-allowed' || errType === 'not-allowed') {
          _speechFailCount++;
        }
        if (errType === 'no-speech') return; // not a real error, ignore

        if (_speechFailCount >= MAX_SPEECH_FAILS) {
          console.log('[SAA Speech] Too many network failures, running 100% offline.');
          window._latestTranscript = '🎤 Offline AI Active (Sinhala sounds & keywords detected automatically)...';
          return; // don't restart
        }

        // Restart after short delay — errors are swallowed
        if (isListening) {
          clearTimeout(_speechRestartTimer);
          _speechRestartTimer = setTimeout(_startSpeechSandboxed, 4000);
        }
      };

      _speech.onend = function () {
        _speechRunning = false;
        if (isListening && _speechFailCount < MAX_SPEECH_FAILS) {
          clearTimeout(_speechRestartTimer);
          _speechRestartTimer = setTimeout(_startSpeechSandboxed, 2000);
        }
      };

      // Delay start so AudioContext settles first
      setTimeout(() => {
        if (isListening && _speech) {
          try { _speech.start(); } catch(e) {
            // Already started or permission error — sandbox
            console.warn('[SAA Speech] start() error (sandboxed):', e.message || e);
          }
        }
      }, 800);

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
    if (now - lastAlertTime < 900) return;

    const t = text.replace(/[^\u0D80-\u0DFFa-z0-9\s]/g, ' ');
    let m = null;

    if (t.includes('උදව්') || t.includes('උදව') || t.includes('udaw') || t.includes('help') || t.includes('save'))
      m = 'udaw';
    else if (t.includes('බේරගන්න') || t.includes('බේරන්න') || t.includes('beeraganna') || t.includes('rescue'))
      m = 'beeraganna';
    else if (t.includes('ගින්නක්') || t.includes('ගින්න') || t.includes('ගිනි') || t.includes('ginnak') || t.includes('fire') || t.includes('smoke'))
      m = 'ginnak';
    else if (t.includes('අනතුරක්') || t.includes('අනතුර') || t.includes('anathurak') || t.includes('danger') || t.includes('emergency'))
      m = 'anathurak';
    else if (t.includes('කරදරයක්') || t.includes('කරදර') || t.includes('karadarayak') || t.includes('trouble'))
      m = 'karadarayak';
    else if (t.includes('බලාගෙන') || t.includes('balagena') || t.includes('watch out') || t.includes('look out'))
      m = 'balagena';
    else if (t.includes('පරිස්සමින්') || t.includes('පරිස්සමෙන්') || t.includes('parissamin') || t.includes('careful') || t.includes('caution'))
      m = 'parissamin';
    else if (t.includes('එහාට') || t.includes('ehata') || t.includes('move away'))
      m = 'ehata_wenna';
    else if (t.includes('නවත්තන්න') || t.includes('nawaththanna') || t.includes('stop'))
      m = 'nawaththanna';
    else if (t.includes('කෑගැසීම') || t.includes('scream'))
      m = 'screaming';
    else if (t.includes('ambulance') || t.includes('ගිලන් රථ'))
      m = 'ambulance';
    else if (t.includes('firetruck') || t.includes('fire truck') || t.includes('ගිනි නිවන') || t.includes('fire alarm'))
      m = 'firetruck';
    else if (t.includes('horn') || t.includes('හෝන්') || t.includes('honk'))
      m = 'vehicle horns';
    else if (t.includes('baby') || t.includes('crying') || t.includes('ළදරු'))
      m = 'baby crying';
    else if (t.includes('dog') || t.includes('bark') || t.includes('බල්ලා'))
      m = 'dog_bark';
    else if (t.includes('traffic') || t.includes('road') || t.includes('මාර්ග'))
      m = 'traffic';

    if (m) _trigger(m, 0.99, `Speech Keyword: "${text}"`);
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
    // 1. BLE motor pulse
    if (gattServer && gattServer.connected && writableChars.length > 0) {
      const pkt = new Uint8Array([0x02]);
      for (const c of writableChars) {
        try {
          if (c.properties.writeWithoutResponse) await c.writeValueWithoutResponse(pkt);
          else if (c.properties.write) await c.writeValue(pkt);
          break;
        } catch(e) {}
      }
    }
    // 2. Phone vibration (works on Android)
    if ('vibrate' in navigator) {
      try { navigator.vibrate([400,150,400,150,600]); } catch(e) {}
    }
    // 3. System notification
    if (window.Notification && Notification.permission === 'granted') {
      try {
        const opts = {
          body: sinhalaBody || '',
          icon: 'icons/Icon-192.png',
          tag: 'alert_' + (soundClass || 'x'),
          requireInteraction: true,
          vibrate: [400,150,400,150,600],
        };
        if (swReg && swReg.showNotification) {
          swReg.showNotification(`🚨 ${sinhalaBody || 'හදිසි!'}`, opts);
        } else {
          new Notification(`🚨 ${sinhalaBody || 'හදිසි!'}`, opts);
        }
      } catch(e) {}
    }
  };

  console.log('[SAA] AcousticAware Offline AI v38.0 — Ready!');
})();
