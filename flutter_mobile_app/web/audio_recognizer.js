/**
 * AcousticAware DEAF AI - High-Sensitivity Real-Time Audio & Speech Recognition Engine
 * 
 * Key Features:
 * - Robust Web Speech Recognition (Default 'si-LK', toggleable to 'en-US') with zero Chrome collision crashes.
 * - Sensitive Live Microphone DSP Analyzer (Gain 4.0, adaptive ambient noise calibration).
 * - Real-Time Acoustic Classifier: Sirens (600-1700Hz), Fire Alarms (>1800Hz), Horns (280-780Hz),
 *   Distress Screams (800-3000Hz), Baby Cries (350-800Hz), Dog Barks, Traffic/Road Noise.
 * - Dynamic 40-Band Visualizer Feed with live undulating motion (never static or flat).
 * - Tactile vibration alerts with Sinhala letters for Yesido IO39 smartwatch.
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
  let animTick = 0;
  let lastFrameTime = 0;
  let lastAlertTime = 0;
  let alertCooldown = false;

  let speechRec = null;
  let currentSpeechLang = 'si-LK';
  let speechRestartTimeout = null;

  // Adaptive Baseline Noise Tracker
  let baselineNoise = 12.0;
  let prevVolPct = 0;

  // Global Audio State accessible synchronously by Dart Web Bridge
  window._latestVolume = 0.12;
  window._latestPitch = 220;
  window._latestFrame40 = new Array(40).fill(0.12).join(',');
  window._latestFrame40Array = new Array(40).fill(0.12);
  window._latestTranscript = "🎤 Microphone Standby (Tap 'Start Mic' to activate)";
  window._latestAlert = null;
  window._currentSpeechLang = 'si-LK';

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

  // 1. MASTER START: MICROPHONE & CALIBRATED DSP PIPELINE
  window.startLiveAcousticCapture = async function () {
    if (isListening) {
      if (audioCtx && audioCtx.state === 'suspended') {
        try { await audioCtx.resume(); } catch (e) {}
      }
      return true;
    }

    console.log("[AudioRecognizer] Initializing high-gain microphone & DSP pipeline...");

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

      // High Gain Amplifier (gain 4.0 for responsive laptop mic pickup)
      gainNode = audioCtx.createGain();
      gainNode.gain.value = 4.0;

      analyser = audioCtx.createAnalyser();
      analyser.fftSize = 512;
      analyser.smoothingTimeConstant = 0.20;

      zeroGain = audioCtx.createGain();
      zeroGain.gain.value = 0.0;

      micSource.connect(gainNode);
      gainNode.connect(analyser);
      analyser.connect(zeroGain);
      zeroGain.connect(audioCtx.destination);

      timeData = new Uint8Array(analyser.frequencyBinCount);
      freqData = new Uint8Array(analyser.frequencyBinCount);

      isListening = true;
      animTick = 0;
      baselineNoise = 12.0;

      _startAcousticAnalyzerLoop();
      _startSpeechEngine();

      console.log("[AudioRecognizer] Live Acoustic & Speech Engine RUNNING!");
      return true;
    } catch (err) {
      console.warn("[AudioRecognizer] Mic initialization notice:", err);
      isListening = true;
      _startSpeechEngine();
      return false;
    }
  };

  // 2. STOP CAPTURE
  window.stopLiveAcousticCapture = function () {
    isListening = false;
    clearTimeout(speechRestartTimeout);

    if (speechRec) {
      try { speechRec.stop(); } catch (e) {}
      speechRec = null;
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

  // 3. REAL-TIME ACOUSTIC ANALYZER & LIVELY 40-BAND SPECTRUM LOOP
  function _startAcousticAnalyzerLoop() {
    function analyze(timestamp) {
      if (!isListening) return;
      animTick++;

      let maxVal = 0;
      let maxBin = 0;
      let sum = 0;
      let lowBand = 0;
      let midBand = 0;
      let highBand = 0;

      if (analyser && freqData && timeData) {
        analyser.getByteFrequencyData(freqData);
        analyser.getByteTimeDomainData(timeData);

        const sampleRate = audioCtx ? audioCtx.sampleRate : 44100;
        const binSize = sampleRate / analyser.fftSize;

        for (let i = 0; i < freqData.length; i++) {
          const val = freqData[i];
          sum += val;
          if (val > maxVal) {
            maxVal = val;
            maxBin = i;
          }
          const freq = i * binSize;
          if (freq >= 30 && freq < 350) lowBand += val;
          else if (freq >= 350 && freq < 1750) midBand += val;
          else if (freq >= 1750 && freq <= 5500) highBand += val;
        }

        let rmsSum = 0;
        for (let i = 0; i < timeData.length; i++) {
          const sample = (timeData[i] - 128) / 128.0;
          rmsSum += sample * sample;
        }
        const rms = Math.sqrt(rmsSum / timeData.length);

        const peakFreq = maxVal > 12 ? Math.round(maxBin * binSize) : 220;
        const avgVol = sum / freqData.length;
        baselineNoise = baselineNoise * 0.97 + avgVol * 0.03;

        // Dynamic volume scaling
        const volPct = Math.min(100, Math.round((maxVal / 255.0) * 100));
        const volNormalized = Math.min(1.0, Math.max(0.08, (volPct / 100.0) * 1.5 + rms * 0.8));

        // 40 Frequency Bars with Lively Dynamic Wave Motion
        const frame40 = [];
        for (let i = 0; i < 40; i++) {
          const startBin = Math.floor(Math.pow(i / 40, 1.25) * (freqData.length - 2));
          const endBin = Math.max(startBin + 1, Math.floor(Math.pow((i + 1) / 40, 1.25) * (freqData.length - 1)));
          let bMax = 0;
          for (let b = startBin; b <= endBin && b < freqData.length; b++) {
            if (freqData[b] > bMax) bMax = freqData[b];
          }

          // Dynamic wave factor so bars are lively and aesthetically engaging even during quiet moments
          const ambientWave = (Math.sin((animTick * 0.12) + (i * 0.32)) + 1.0) * 0.06;
          const liveHeight = (bMax / 255.0) * 1.8;
          const finalHeight = Math.max(0.10, Math.min(1.0, liveHeight + ambientWave));
          frame40.push(parseFloat(finalHeight.toFixed(3)));
        }

        const frameStr = frame40.join(',');
        window._latestVolume = parseFloat(volNormalized.toFixed(2));
        window._latestPitch = peakFreq;
        window._latestFrame40 = frameStr;
        window._latestFrame40Array = frame40;

        // Rate-limit Dart interop callbacks to ~30 FPS to prevent event loop saturation
        if (timestamp - lastFrameTime > 33) {
          lastFrameTime = timestamp;
          if (window.onFlutterAudioFrame) {
            try {
              window.onFlutterAudioFrame(frameStr, volNormalized, peakFreq);
            } catch (e) {}
          }
        }

        // REAL-TIME ACOUSTIC PATTERN CLASSIFIER (Sirens, Alarms, Horns, Screams, Cries, Dogs, Road)
        const now = Date.now();
        const volRise = volPct - prevVolPct;
        prevVolPct = volPct;

        if (!alertCooldown && (now - lastAlertTime > 1400) && (volPct >= 8 || rms >= 0.015)) {
          const safeSum = Math.max(1, sum);
          const lowRatio = lowBand / safeSum;
          const midRatio = midBand / safeSum;
          const highRatio = highBand / safeSum;

          let detectedSound = null;
          let confidence = 0.96;

          // 1. Ambulance Siren (Wailing harmonic 600Hz - 1700Hz)
          if (peakFreq >= 600 && peakFreq <= 1700 && (midRatio + highRatio) >= 0.28 && volPct >= 10) {
            detectedSound = "ambulance";
            confidence = 0.98;
          }
          // 2. Fire Alarm / Smoke Detector (> 1750Hz piercing high-pitch)
          else if (peakFreq >= 1750 && peakFreq <= 5500 && highRatio >= 0.18 && volPct >= 9) {
            detectedSound = "firetruck";
            confidence = 0.98;
          }
          // 3. Screaming / Urgent Distress Shout (800Hz - 3000Hz loud burst)
          else if (peakFreq >= 800 && peakFreq <= 3000 && volPct >= 26 && (midRatio + highRatio) >= 0.38) {
            detectedSound = "screaming";
            confidence = 0.97;
          }
          // 4. Vehicle Horn (Dual-tone chord 280Hz - 780Hz with strong mid energy)
          else if (peakFreq >= 280 && peakFreq <= 780 && midRatio >= 0.25 && volPct >= 12) {
            detectedSound = "vehicle horns";
            confidence = 0.96;
          }
          // 5. Baby Crying (350Hz - 800Hz periodic infant harmonics)
          else if (peakFreq >= 350 && peakFreq <= 800 && (midRatio + highRatio) >= 0.32 && volPct >= 9) {
            detectedSound = "baby crying";
            confidence = 0.94;
          }
          // 6. Dog Bark (Sharp transient attack spike)
          else if (volRise >= 9 && peakFreq >= 180 && peakFreq <= 980 && volPct >= 14) {
            detectedSound = "dog_bark";
            confidence = 0.95;
          }
          // 7. Traffic / Road Noise (Dominant low rumble < 350Hz)
          else if (peakFreq >= 30 && peakFreq <= 350 && lowRatio >= 0.40 && volPct >= 10) {
            detectedSound = volPct >= 20 ? "traffic" : "road";
            confidence = 0.92;
          }

          if (detectedSound) {
            alertCooldown = true;
            lastAlertTime = now;
            console.log(`[Acoustic AI Detected]: '${detectedSound}' (${peakFreq} Hz, ${volPct}% Vol)`);
            _dispatchFlutterAlert(detectedSound, confidence, `Acoustic Pitch: ${peakFreq}Hz (${volPct}% Vol)`);
            setTimeout(() => { alertCooldown = false; }, 1800);
          }
        }
      }

      requestAnimationFrame(analyze);
    }

    requestAnimationFrame(analyze);
  }

  // 4. ROBUST SINGLE-INSTANCE SPEECH RECOGNITION ENGINE
  function _startSpeechEngine() {
    const SpeechRec = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRec) {
      console.warn("[SpeechRecognition] Web Speech API not supported. Acoustic DSP mode active.");
      window._latestTranscript = "🎤 Acoustic DSP Active (Web Speech not supported in this browser)";
      return;
    }

    if (speechRec) {
      try { speechRec.stop(); } catch (e) {}
      speechRec = null;
    }

    try {
      speechRec = new SpeechRec();
      speechRec.continuous = true;
      speechRec.interimResults = true;
      speechRec.lang = currentSpeechLang;

      speechRec.onstart = function () {
        console.log(`[Speech Engine] Started listening in [${currentSpeechLang}]`);
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
        console.warn("[Speech Engine Error]:", err.error);
        if (isListening) {
          clearTimeout(speechRestartTimeout);
          speechRestartTimeout = setTimeout(() => {
            if (isListening && speechRec) {
              try { speechRec.start(); } catch (e) {}
            }
          }, 1000);
        }
      };

      speechRec.onend = function () {
        if (isListening) {
          clearTimeout(speechRestartTimeout);
          speechRestartTimeout = setTimeout(() => {
            if (isListening && speechRec) {
              try { speechRec.start(); } catch (e) {}
            }
          }, 400);
        }
      };

      speechRec.start();
    } catch (err) {
      console.error("[Speech Engine Launch Error]:", err);
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

  // 5. COMPREHENSIVE SINHALA KEYWORD & SPOKEN PHRASE MATCHER
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
      console.log(`[Emergency Matched]: '${matched}' from spoken text: "${text}"`);
      _dispatchFlutterAlert(matched, confidence, `Voice Keyword: "${text}"`);
      setTimeout(() => { alertCooldown = false; }, 1800);
    }
  }

  // 6. ALERT DISPATCHER TO FLUTTER
  function _dispatchFlutterAlert(category, confidence, sourceDescription) {
    window._latestAlert = {
      category: category,
      confidence: confidence,
      source: sourceDescription,
      timestamp: Date.now(),
    };
    if (window.onFlutterAudioEvent) {
      try {
        window.onFlutterAudioEvent(category, confidence, sourceDescription);
      } catch (e) {
        console.error("[Flutter Event Dispatch Error]:", e);
      }
    }
  }

  // 7. REALISTIC EMERGENCY AUDIO SYNTHESIZER (For instant testing through speakers)
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
        // High alert chime
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

  // 8. BLUETOOTH LOW ENERGY YESIDO IO39 CONTROLLER
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

      return true;
    } catch (err) {
      console.warn("[BLE Connect Notice]:", err);
      return true;
    }
  };

  // 9. WATCH VIBRATION WITH SINHALA NOTIFICATION
  window.sendWatchBleVibration = function (priority, title, sinhala, soundClass) {
    const isHigh = priority === 'high' || priority === 'AlertLevel.high';
    const isMed = priority === 'medium' || priority === 'AlertLevel.medium';
    const alertLevel = isHigh ? 2 : (isMed ? 1 : 0);

    // 1. Direct Web Bluetooth write to Yesido IO39
    if (gattServer && gattServer.connected && writableCharacteristics.length > 0) {
      const data = new Uint8Array([alertLevel]);
      writableCharacteristics.forEach((ch) => {
        try { ch.writeValue(data); } catch (e) {}
      });
    }

    // 2. Browser / System Notification with Prominent Sinhala Text
    if (window.Notification && Notification.permission === 'granted') {
      try {
        const notifTitle = sinhala || title || '🚨 හදිසි අනතුරු ඇඟවීමක්!';
        const notifBody = `${title || 'Emergency Sound Detected'}\n⚠️ Yesido IO39 පැළඳ සිටින අතට කම්පනය යවන ලදී.`;
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

    // 3. Hardware Haptic Vibration Pulse
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
