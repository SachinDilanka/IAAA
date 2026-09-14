/* 
  ===================================================================
  AcousticAware DEAF Emergency Sound System & Laptop Microphone AI
  ===================================================================
*/

// GLOBAL STATE & SYSTEM HANDLERS
let audioCtx = null;
let micStream = null;
let micSource = null;
let analyser = null;
let waveDataArray = null;
let freqDataArray = null;
let isMicActive = false;
let isBleConnected = false;
let gattServer = null;
let allAlertCharacteristics = [];
let alertCooldownActive = false;
let soundSequenceIndex = 0;
let recognitionCount = 0;

// 15 SUPPORTED EMERGENCY SOUNDS & PRIORITY MAP (INCLUDING 7 SINHALA KEYWORD DATASET)
const PRIORITY_MAP = {
  "fire_alarm": { 
    name: "🔥 FIRE ALARM SIREN", 
    sinhala: "🔥 ගිනි අනතුරු සංඥාව", 
    level: "HIGH", 
    color: "#ff3b30", 
    vibrationPattern: "3 Heavy Pulses (500ms x 3)",
    text: "Piercing Smoke Detector Siren! Evacuate immediately.",
    sinhalaText: "ගිනි අනතුරු සංඥාවක් හඳුනාගන්නා ලදී! වහාම ආරක්ෂිත ස්ථානයකට යන්න." 
  },
  "ambulance": { 
    name: "🚑 AMBULANCE SIREN", 
    sinhala: "🚑 ගිලන් රථ අනතුරු සංඥාව", 
    level: "HIGH", 
    color: "#ff3b30", 
    vibrationPattern: "3 Heavy Pulses (500ms x 3)",
    text: "Emergency vehicle approaching! Yield right of way.",
    sinhalaText: "ගිලන් රථයක් ළඟා වේ! හදිසි රථයට ඉඩ දෙන්න." 
  },
  "udaw": { 
    name: "🆘 \"උදව් කරන්න\" (UDAW - HELP)", 
    sinhala: "🆘 හදිසි උපකාර ඉල්ලීම: 'උදව් කරන්න!'", 
    level: "HIGH", 
    color: "#ff3b30", 
    vibrationPattern: "3 Heavy Pulses (500ms x 3)",
    text: "Help distress voice call spoken nearby!",
    sinhalaText: "උදව් ඉල්ලීමේ හඬක් හඳුනාගන්නා ලදී! වහාම උපකාර කරන්න." 
  },
  "beeraganna": { 
    name: "🆘 \"බේරගන්න\" (BEERAGANNA - RESCUE ME)", 
    sinhala: "🆘 හදිසි විපත් සංඥාව: 'බේරගන්න!'", 
    level: "HIGH", 
    color: "#ff3b30", 
    vibrationPattern: "3 Heavy Pulses (500ms x 3)",
    text: "Urgent 'Rescue Me / Save Me' distress keyword spoken nearby!",
    sinhalaText: "'බේරගන්න' යන හදිසි විපත් හඬක් හඳුනාගන්නා ලදී! වහාම පරීක්ෂා කරන්න." 
  },
  "ginnak": { 
    name: "🔥 \"ගින්නක්\" (GINNAK - FIRE SPEECH)", 
    sinhala: "🔥 හදිසි වචනය: 'ගින්නක්!'", 
    level: "HIGH", 
    color: "#ff3b30", 
    vibrationPattern: "3 Heavy Pulses (500ms x 3)",
    text: "Fire hazard keyword detected in spoken voice!",
    sinhalaText: "'ගින්නක්' යන වචනය හඳුනාගන්නා ලදී! අවට ගින්නක් ඇත්දැයි බලන්න." 
  },
  "ginna": { 
    name: "🔥 \"ගින්නක්\" (GINNAK - FIRE SPEECH)", 
    sinhala: "🔥 හදිසි වචනය: 'ගින්නක්!'", 
    level: "HIGH", 
    color: "#ff3b30", 
    vibrationPattern: "3 Heavy Pulses (500ms x 3)",
    text: "Fire hazard keyword detected in spoken voice!",
    sinhalaText: "'ගින්නක්' යන වචනය හඳුනාගන්නා ලදී! අවට ගින්නක් ඇත්දැයි බලන්න." 
  },
  "anathurak": { 
    name: "⚠️ \"අනතුරක්\" (ANATHURAK - DANGER)", 
    sinhala: "⚠️ හදිසි අනතුරු වචනය: 'අනතුරක්!'", 
    level: "HIGH", 
    color: "#ff3b30", 
    vibrationPattern: "3 Heavy Pulses (500ms x 3)",
    text: "Urgent Danger / Hazard warning keyword spoken nearby!",
    sinhalaText: "'අනතුරක්' යන හදිසි අනතුරු ඇඟවීමේ වචනය හඳුනාගන්නා ලදී! ප්‍රවේශම් වන්න." 
  },
  "karadarayak": { 
    name: "⚠️ \"කරදරයක්\" (KARADARAYAK - TROUBLE)", 
    sinhala: "⚠️ අනතුරු ඇඟවීම: 'කරදරයක්'", 
    level: "MEDIUM", 
    color: "#ff9500", 
    vibrationPattern: "2 Moderate Pulses (300ms x 2)",
    text: "Trouble / distress keyword detected in spoken voice.",
    sinhalaText: "'කරදරයක්' යන විපත් වචනය හඳුනාගන්නා ලදී. අවධානයෙන් සිටින්න." 
  },
  "balagena": { 
    name: "👁️ \"බලාගෙන\" (BALAGENA - WATCH OUT)", 
    sinhala: "👁️ ප්‍රවේශම් වන්න: 'බලාගෙන'", 
    level: "MEDIUM", 
    color: "#ff9500", 
    vibrationPattern: "2 Moderate Pulses (300ms x 2)",
    text: "Watch out caution keyword spoken nearby.",
    sinhalaText: "'බලාගෙන' යන ප්‍රවේශම් වීමේ වචනය හඳුනාගන්නා ලදී." 
  },
  "parissamin": { 
    name: "⚠️ \"පරිස්සමින්\" (PARISSAMIN - BE CAREFUL)", 
    sinhala: "⚠️ ප්‍රවේශම් වන්න: 'පරිස්සමින්'", 
    level: "MEDIUM", 
    color: "#ff9500", 
    vibrationPattern: "2 Moderate Pulses (300ms x 2)",
    text: "Caution keyword 'Be careful' detected.",
    sinhalaText: "'පරිස්සමින්' යන අවවාදාත්මක වචනය හඳුනාගන්නා ලදී." 
  },
  "ehaata_wenna": { 
    name: "🚷 \"එහාට වෙන්න\" (EHATA - MOVE AWAY)", 
    sinhala: "🚷 නියෝගය: 'එහාට වෙන්න'", 
    level: "MEDIUM", 
    color: "#ff9500", 
    vibrationPattern: "2 Moderate Pulses (300ms x 2)",
    text: "Move away caution command detected.",
    sinhalaText: "'එහාට වෙන්න' යන වචනය හඳුනාගන්නා ලදී." 
  },
  "baby_crying": { 
    name: "👶 BABY CRYING", 
    sinhala: "👶 ළදරුවෙකුගේ හැඬීම", 
    level: "MEDIUM", 
    color: "#ff9500", 
    vibrationPattern: "2 Moderate Pulses (300ms x 2)",
    text: "Infant crying acoustics detected nearby.",
    sinhalaText: "ළදරුවෙකු හඬන ශබ්දයක් හඳුනාගන්නා ලදී." 
  },
  "screaming": { 
    name: "😱 SCREAMING / SHOUTING", 
    sinhala: "😱 පුද්ගලයෙකුගේ කෑගැසීමක්", 
    level: "HIGH", 
    color: "#ff3b30", 
    vibrationPattern: "3 Heavy Pulses (500ms x 3)",
    text: "Human distress scream / shouting acoustic spike!",
    sinhalaText: "කෑගැසීමේ ශබ්දයක් හඳුනාගන්නා ලදී!" 
  },
  "vehicle_horn": { 
    name: "🚗 CAR HORN BLAST", 
    sinhala: "🚗 රථවාහන හෝන් ශබ්දය", 
    level: "HIGH", 
    color: "#ff3b30", 
    vibrationPattern: "3 Heavy Pulses (500ms x 3)",
    text: "Vehicle horn acoustic impulse detected.",
    sinhalaText: "වාහන හෝන් ශබ්දයක් හඳුනාගන්නා ලදී." 
  },
  "dog_bark": { 
    name: "🐕 DOG BARKING", 
    sinhala: "🐕 බල්ලෙකුගේ බිරුම", 
    level: "LOW", 
    color: "#34c759", 
    vibrationPattern: "1 Gentle Tap (150ms)",
    text: "Canine barking sound detected in room.",
    sinhalaText: "බල්ලෙකු බුරන ශබ්දයක් හඳුනාගන්නා ලදී." 
  },
  "dog_barking": { 
    name: "🐕 DOG BARKING", 
    sinhala: "🐕 බල්ලෙකුගේ බිරුම", 
    level: "LOW", 
    color: "#34c759", 
    vibrationPattern: "1 Gentle Tap (150ms)",
    text: "Canine barking sound detected in room.",
    sinhalaText: "බල්ලෙකු බුරන ශබ්දයක් හඳුනාගන්නා ලදී." 
  },
  "firetruck": { 
    name: "🔥 FIRE TRUCK SIREN", 
    sinhala: "🔥 ගිනි නිවන රථ අනතුරු සංඥාව", 
    level: "HIGH", 
    color: "#ff3b30", 
    vibrationPattern: "3 Heavy Pulses (500ms x 3)",
    text: "Fire engine / emergency alarm siren approaching!",
    sinhalaText: "ගිනි නිවන රථ සංඥාවක් හඳුනාගන්නා ලදී!" 
  },
  "vehicle horns": { 
    name: "🚗 VEHICLE HORN BLAST", 
    sinhala: "🚗 රථවාහන හෝන් ශබ්දය", 
    level: "HIGH", 
    color: "#ff3b30", 
    vibrationPattern: "3 Heavy Pulses (500ms x 3)",
    text: "Vehicle horn acoustic impulse detected.",
    sinhalaText: "වාහන හෝන් ශබ්දයක් හඳුනාගන්නා ලදී." 
  },
  "baby crying": { 
    name: "👶 BABY CRYING", 
    sinhala: "👶 ළදරුවෙකුගේ හැඬීම", 
    level: "MEDIUM", 
    color: "#ff9500", 
    vibrationPattern: "2 Moderate Pulses (300ms x 2)",
    text: "Infant crying acoustics detected nearby.",
    sinhalaText: "ළදරුවෙකු හඬන ශබ්දයක් හඳුනාගන්නා ලදී." 
  },
  "road": { 
    name: "🛣️ ROAD NOISE", 
    sinhala: "🛣️ මාර්ග ඝෝෂාව", 
    level: "LOW", 
    color: "#34c759", 
    vibrationPattern: "1 Gentle Tap (150ms)",
    text: "Continuous ambient road acoustic noise detected.",
    sinhalaText: "මාර්ග ඝෝෂාව හඳුනාගන්නා ලදී." 
  },
  "traffic": { 
    name: "🚦 TRAFFIC MOVEMENT", 
    sinhala: "🚦 රථවාහන ගමනාගමනය", 
    level: "LOW", 
    color: "#34c759", 
    vibrationPattern: "1 Gentle Tap (150ms)",
    text: "Traffic movement and engine noise detected.",
    sinhalaText: "රථවාහන ගමනාගමන ශබ්ද හඳුනාගන්නා ලදී." 
  }
};

const ALL_KEYS = Object.keys(PRIORITY_MAP);

// 1. MASTER UNLOCK & LAPTOP MICROPHONE START
async function startAcousticSystem() {
  console.log("[AcousticAware Master Engine] Starting laptop microphone listening...");
  
  if (window.Notification && Notification.permission !== "granted") {
    try { await Notification.requestPermission(); } catch(e){}
  }

  try {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
      await audioCtx.resume();
    }
  } catch (e) {}

  await toggleMicrophone();

  const masterBtn = document.getElementById("btn-master-mic");
  const micHint = document.getElementById("mic-hint-text");
  if (masterBtn) {
    masterBtn.innerHTML = '<span style="font-size: 1.4rem;">🔴</span> LAPTOP MICROPHONE LIVE & DETECTING IN REAL-TIME';
    masterBtn.style.background = "linear-gradient(135deg, #10b981 0%, #059669 100%)";
    masterBtn.style.color = "#ffffff";
    masterBtn.style.borderColor = "#34d399";
    masterBtn.style.boxShadow = "0 0 25px rgba(16, 185, 129, 0.6)";
  }
  if (micHint) {
    micHint.innerHTML = "✅ <strong>Laptop Microphone ACTIVE!</strong> Speak words (e.g. <em>'උදව්', 'ගින්නක්', 'කරදරයක්', 'Help', 'Fire'</em>) or make sounds near your mic.";
    micHint.style.color = "#34d399";
  }
}
window.startAcousticSystem = startAcousticSystem;

// 2. MICROPHONE STREAM & AUDIO ANALYZER SETUP
async function toggleMicrophone() {
  console.log("[Microphone Engine] Capturing live audio stream from laptop mic...");
  const statusMic = document.getElementById("status-mic");

  try {
    if (!audioCtx) {
      audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    }
    if (audioCtx.state === 'suspended') {
      await audioCtx.resume();
    }

    if (!micStream && navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
      try {
        micStream = await navigator.mediaDevices.getUserMedia({ audio: true });
      } catch (e1) {
        try {
          micStream = await navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: false } });
        } catch (e2) {}
      }
    }

    if (!analyser && micStream) {
      try {
        micSource = audioCtx.createMediaStreamSource(micStream);
        analyser = audioCtx.createAnalyser();
        analyser.fftSize = 512;
        analyser.smoothingTimeConstant = 0.15;
        micSource.connect(analyser);

        const silentGain = audioCtx.createGain();
        silentGain.gain.value = 0;
        analyser.connect(silentGain);
        silentGain.connect(audioCtx.destination);

        const bufferLength = analyser.frequencyBinCount;
        waveDataArray = new Uint8Array(bufferLength);
        freqDataArray = new Uint8Array(bufferLength);
      } catch (err) {
        console.error("[Mic Source Error]:", err);
      }
    }

    isMicActive = true;

    if (statusMic) {
      statusMic.className = "status-pill active";
      statusMic.innerHTML = '<span class="indicator"></span> Laptop Mic: LIVE';
      statusMic.style.borderColor = "#10b981";
      statusMic.style.color = "#10b981";
    }

    initSpeechKws();
    startWaveformRender();
    startAudioAnalyzerLoop();
  } catch (err) {
    console.error("[Mic Init Error]:", err);
  }
}
window.toggleMicrophone = toggleMicrophone;

// 3. SINHALA & ENGLISH REAL-TIME SPEECH-TO-TEXT KEYWORD SPOTTING
function initSpeechKws() {
  const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
  const transcriptEl = document.getElementById("live-speech-transcript");
  if (!SpeechRecognition) {
    if (transcriptEl) transcriptEl.innerText = "Speech Recognition API not supported in this browser (Audio frequency analyzer is active)";
    return;
  }

  function createRecognitionInstance(langCode) {
    try {
      const rec = new SpeechRecognition();
      rec.continuous = true;
      rec.interimResults = true;
      rec.lang = langCode;

      rec.onresult = (event) => {
        for (let i = event.resultIndex; i < event.results.length; i++) {
          const transcript = event.results[i][0].transcript.toLowerCase().trim();
          console.log(`[Live Speech (${langCode})]: "${transcript}"`);
          
          if (transcriptEl) {
            transcriptEl.innerHTML = `"${transcript}" <span style="font-size:0.75rem; color:#94a3b8;">(${langCode})</span>`;
          }

          // 1. 🆘 HELP / UDAW ("උදව්", "udaw", "help", "save")
          if (transcript.includes("උදව්") || transcript.includes("උදවු") || transcript.includes("udaw") || transcript.includes("udau") || transcript.includes("help") || transcript.includes("save")) {
            triggerLiveAlert("udaw", 0.98, "Voice Keyword: 'උදව් / Help'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          } 
          // 2. 🔥 GINNAK / FIRE ("ගින්නක්", "ginnak", "fire")
          else if (transcript.includes("ගින්නක්") || transcript.includes("ගින්න") || transcript.includes("ginnak") || transcript.includes("ginna") || transcript.includes("fire") || transcript.includes("flame")) {
            triggerLiveAlert("ginna", 0.97, "Voice Keyword: 'ගින්නක් / Fire'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
          // 3. ⚠️ ANATHURAK ("අනතුරක්", "anathurak", "danger", "hazard")
          else if (transcript.includes("අනතුරක්") || transcript.includes("අනතුර") || transcript.includes("anathurak") || transcript.includes("anaturak") || transcript.includes("danger") || transcript.includes("hazard")) {
            triggerLiveAlert("anathurak", 0.98, "Voice Keyword: 'අනතුරක් / Danger'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
          // 4. ⚠️ KARADARAYAK ("කරදරයක්", "karadarayak", "trouble", "problem")
          else if (transcript.includes("කරදරයක්") || transcript.includes("කරදර") || transcript.includes("karadarayak") || transcript.includes("karadare") || transcript.includes("trouble") || transcript.includes("problem")) {
            triggerLiveAlert("karadarayak", 0.95, "Voice Keyword: 'කරදරයක් / Trouble'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
          // 5. 🛡️ BEERAGANNA ("බේරගන්න", "beeraganna", "rescue")
          else if (transcript.includes("බේරගන්න") || transcript.includes("බේර ගන්න") || transcript.includes("beeraganna") || transcript.includes("beraganna") || transcript.includes("rescue")) {
            triggerLiveAlert("beeraganna", 0.97, "Voice Keyword: 'බේරගන්න / Rescue'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          } 
          // 6. 👁️ BALAGENA ("බලාගෙන", "balagena", "watch out")
          else if (transcript.includes("බලාගෙන") || transcript.includes("බලා ගෙන") || transcript.includes("balagena") || transcript.includes("watch out") || transcript.includes("look out")) {
            triggerLiveAlert("balagena", 0.95, "Voice Keyword: 'බලාගෙන / Watch Out'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
          // 7. ⚠️ PARISSAMIN ("පරිස්සමින්", "parissamin", "careful")
          else if (transcript.includes("පරිස්සමින්") || transcript.includes("පරිස්සමෙන්") || transcript.includes("parissamin") || transcript.includes("careful") || transcript.includes("caution")) {
            triggerLiveAlert("parissamin", 0.95, "Voice Keyword: 'පරිස්සමින් / Careful'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
          // 8. 🚑 AMBULANCE ("ambulance", "ඇම්බියුලන්ස්")
          else if (transcript.includes("ambulance") || transcript.includes("ඇම්බියුලන්ස්") || transcript.includes("ambulans")) {
            triggerLiveAlert("ambulance", 0.98, "Speech: 'Ambulance Siren'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
          // 9. 🔥 FIRETRUCK ("firetruck", "fire alarm", "ගිනි නිවන")
          else if (transcript.includes("firetruck") || transcript.includes("fire truck") || transcript.includes("fire alarm") || transcript.includes("ගිනි නිවන")) {
            triggerLiveAlert("firetruck", 0.98, "Speech: 'Firetruck / Alarm'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
          // 10. 🚗 VEHICLE HORNS ("vehicle horn", "car horn", "horn", "හෝන්")
          else if (transcript.includes("horn") || transcript.includes("vehicle horn") || transcript.includes("car horn") || transcript.includes("හෝන්") || transcript.includes("honk")) {
            triggerLiveAlert("vehicle horns", 0.96, "Speech: 'Vehicle Horn'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
          // 11. 👶 BABY CRYING ("baby crying", "baby", "ළදරු", "හැඬීම")
          else if (transcript.includes("baby") || transcript.includes("crying") || transcript.includes("ළදරු") || transcript.includes("හැඬීම")) {
            triggerLiveAlert("baby crying", 0.94, "Speech: 'Baby Crying'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
          // 12. 🐕 DOG BARK ("dog bark", "dog", "bark", "බල්ලා", "බිරුම")
          else if (transcript.includes("dog") || transcript.includes("bark") || transcript.includes("බල්ලා") || transcript.includes("බිරුම")) {
            triggerLiveAlert("dog_bark", 0.95, "Speech: 'Dog Barking'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
          // 13. 🛣️ ROAD ("road", "highway", "පාර", "මාර්ග")
          else if (transcript.includes("road") || transcript.includes("highway") || transcript.includes("street") || transcript.includes("පාර") || transcript.includes("මාර්ග")) {
            triggerLiveAlert("road", 0.91, "Speech: 'Road Noise'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
          // 14. 🚦 TRAFFIC ("traffic", "jam", "ට්‍රැෆික්")
          else if (transcript.includes("traffic") || transcript.includes("jam") || transcript.includes("ට්‍රැෆික්")) {
            triggerLiveAlert("traffic", 0.91, "Speech: 'Traffic Movement'");
            alertCooldownActive = true;
            setTimeout(() => { alertCooldownActive = false; }, 2000);
            break;
          }
        }
      };

      rec.onerror = () => {
        setTimeout(() => { if (isMicActive) try { rec.start(); } catch(e){} }, 800);
      };
      rec.onend = () => {
        if (isMicActive) setTimeout(() => { try { rec.start(); } catch(e){} }, 400);
      };

      rec.start();
    } catch(e){}
  }

  createRecognitionInstance('si-LK');
  createRecognitionInstance('en-US');
}

let baselineNoise = 18;

// 4. REAL-TIME ACOUSTIC FREQUENCY & VOLUME DETECTOR LOOP
function startAudioAnalyzerLoop() {
  setInterval(() => {
    if (!isMicActive || !analyser || !waveDataArray || !freqDataArray) return;

    analyser.getByteTimeDomainData(waveDataArray);
    let rmsSum = 0;
    for (let i = 0; i < waveDataArray.length; i++) {
      const sample = (waveDataArray[i] - 128) / 128.0;
      rmsSum += sample * sample;
    }
    const rms = Math.sqrt(rmsSum / waveDataArray.length);

    analyser.getByteFrequencyData(freqDataArray);
    let sum = 0;
    let maxVal = 0;
    let maxBin = 0;
    let lowBand = 0;
    let midBand = 0;
    let highBand = 0;

    const sampleRate = (audioCtx ? audioCtx.sampleRate : 44100);
    const binSize = sampleRate / 512;

    for (let i = 0; i < freqDataArray.length; i++) {
      const val = freqDataArray[i];
      sum += val;
      if (val > maxVal) {
        maxVal = val;
        maxBin = i;
      }
      const f = i * binSize;
      if (f >= 40 && f < 350) lowBand += val;
      else if (f >= 350 && f < 1750) midBand += val;
      else if (f >= 1750 && f <= 5000) highBand += val;
    }

    const avgVol = sum / freqDataArray.length;
    const volPct = Math.min(100, Math.round((maxVal / 255) * 100));
    baselineNoise = baselineNoise * 0.96 + avgVol * 0.04;

    const hudVolume = document.getElementById("hud-volume");
    if (hudVolume) hudVolume.innerText = volPct + "%";

    const peakFreq = Math.round(maxBin * binSize);

    // Update real-time pitch display
    const freqEl = document.getElementById("recognized-freq");
    if (freqEl && maxVal > baselineNoise + 10) {
      freqEl.innerText = peakFreq + " Hz";
    }

    // ACOUSTIC FINGERPRINT DETECTION (Strict Temporal Signature Matching)
    const volRise = volPct - (window._prevVolPct || 0);
    window._prevVolPct = volPct;

    const safeSum = Math.max(1, sum);
    const lowRatio = lowBand / safeSum;
    const midRatio = midBand / safeSum;
    const highRatio = highBand / safeSum;

    // Speech isolation guard: If user recently spoke, don't trigger acoustic sounds
    const now = Date.now();
    const isSpeechActive = (now - (window._lastSpeechTime || 0)) < 1800;

    if (!alertCooldownActive && !isSpeechActive && maxVal > baselineNoise + 16 && (volPct >= 18 || rms > 0.025)) {
      let detectedSound = null;
      let confidence = 0.96;

      // 1. Ambulance Siren (Wailing tone 650Hz - 1650Hz)
      if (peakFreq >= 650 && peakFreq <= 1650 && (midRatio + highRatio) >= 0.35 && volPct >= 20) {
        detectedSound = "ambulance";
        confidence = 0.98;
      }
      // 2. Fire Alarm / Firetruck (Piercing high frequency > 1850Hz)
      else if (peakFreq >= 1850 && peakFreq <= 5000 && highRatio >= 0.22 && volPct >= 18) {
        detectedSound = "firetruck";
        confidence = 0.98;
      }
      // 3. Vehicle Horn (Dual-tone chord 300Hz - 700Hz with high mid-energy)
      else if (peakFreq >= 300 && peakFreq <= 700 && midRatio >= 0.30 && volPct >= 22) {
        detectedSound = "vehicle horns";
        confidence = 0.97;
      }
      // 4. Baby Crying (Infant formants 380Hz - 780Hz)
      else if (peakFreq >= 380 && peakFreq <= 780 && (midRatio + highRatio) >= 0.40 && volPct >= 16) {
        detectedSound = "baby crying";
        confidence = 0.94;
      }
      // 5. Dog Bark (Sharp transient attack spike)
      else if (volRise >= 12 && peakFreq >= 220 && peakFreq <= 980 && volPct >= 25) {
        detectedSound = "dog_bark";
        confidence = 0.95;
      }
      // 6. Traffic / Road (Continuous low frequency < 350Hz)
      else if (peakFreq >= 30 && peakFreq <= 350 && lowRatio >= 0.45 && volPct >= 16) {
        detectedSound = volPct >= 30 || lowRatio >= 0.58 ? "traffic" : "road";
        confidence = 0.92;
      }

      if (detectedSound) {
        alertCooldownActive = true;
        console.log(`[Acoustic Classifier] Triggered '${detectedSound}' (${peakFreq}Hz, ${volPct}%)`);
        triggerLiveAlert(detectedSound, confidence, `Acoustic Pitch: ${peakFreq}Hz (${volPct}% Vol)`);
        setTimeout(() => { alertCooldownActive = false; }, 1600);
      }
    }
  }, 70);
}

// 5. LIVE ALERT TRIGGER: PROMINENT ON-SCREEN DISPLAY & YESIDO WATCH DISPATCH
function triggerLiveAlert(soundKey = "udaw", confidence = 0.94, sourceInfo = "Real-Time Sound Classification") {
  const alertData = PRIORITY_MAP[soundKey] || PRIORITY_MAP["udaw"];
  console.log(`[AcousticAware Alert Trigger] ${alertData.name} (${alertData.level})`);

  recognitionCount++;

  // 1. UPDATE RECOGNITION BOX IN WEB SIMULATOR
  const recBox = document.getElementById("live-recognition-box");
  const recTitle = document.getElementById("recognized-title");
  const recSub = document.getElementById("recognized-subtitle");
  const recBadge = document.getElementById("recognition-badge");
  const recConf = document.getElementById("recognized-confidence");
  const recIcon = document.getElementById("recognized-icon");

  if (recBox) {
    recBox.style.borderColor = alertData.color;
    recBox.style.boxShadow = `0 0 30px ${alertData.color}88`;
    recBox.style.background = `rgba(${alertData.level === 'HIGH' ? '255,59,48,0.15' : '0,242,254,0.12'})`;
  }
  if (recBadge) {
    recBadge.style.background = alertData.color;
    recBadge.style.color = "#000000";
    recBadge.innerText = `🚨 ${alertData.level} EMERGENCY DETECTED`;
  }
  if (recTitle) {
    recTitle.innerText = alertData.name;
    recTitle.style.color = alertData.color;
  }
  if (recSub) {
    recSub.innerText = alertData.sinhala;
  }
  if (recConf) {
    recConf.innerText = `${(confidence * 100).toFixed(0)}%`;
    recConf.style.color = alertData.color;
  }

  // Update Live Speech Transcript Box
  const transcriptEl = document.getElementById("live-speech-transcript");
  if (transcriptEl) {
    transcriptEl.innerHTML = `🚨 <strong>DETECTED:</strong> <span style="color:${alertData.color}; font-weight:900;">${alertData.name}</span> (${alertData.sinhala})`;
  }


  // Set Sound Icon
  if (recIcon) {
    const iconMatch = alertData.name.match(/[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]/u);
    recIcon.innerText = iconMatch ? iconMatch[0] : "🚨";
  }

  // 2. APPEND TO LIVE DETECTION HISTORY LOG
  appendDetectionLog(alertData, confidence, sourceInfo);

  // 3. UPDATE BIG 3D REAL AVATAR DISPLAY
  const hudSoundName = document.getElementById("hud-sound-name");
  const hudPriorityBadge = document.getElementById("hud-priority-badge");
  const speechTitle = document.getElementById("speech-title");
  const speechText = document.getElementById("speech-text");
  const avatarNeutral = document.getElementById("avatar-img-neutral");
  const avatarAlert = document.getElementById("avatar-img-alert");

  if (hudSoundName) {
    hudSoundName.innerHTML = `<span style="color: ${alertData.color}; font-weight: 900;">${alertData.name}</span>`;
  }
  if (hudPriorityBadge) {
    hudPriorityBadge.style.background = alertData.color;
    hudPriorityBadge.innerText = alertData.level;
  }
  if (speechTitle) {
    speechTitle.innerText = alertData.name;
    speechTitle.style.color = alertData.color;
  }
  if (speechText) {
    speechText.innerHTML = `<strong>${alertData.sinhalaText}</strong><br><span style="color:#94a3b8; font-size:0.8rem;">${alertData.text}</span>`;
  }

  // Swap Avatar image to alert expression
  if (avatarNeutral && avatarAlert) {
    avatarNeutral.style.opacity = "0";
    avatarAlert.style.opacity = "1";
    setTimeout(() => {
      avatarNeutral.style.opacity = "1";
      avatarAlert.style.opacity = "0";
    }, 4000);
  }

  // 4. UPDATE YESIDO IO39 WATCH SIMULATOR
  const watchBannerTitle = document.getElementById("banner-watch-title");
  const watchBannerSub = document.getElementById("banner-watch-sub");
  const vibeWaves = document.getElementById("vibe-waves");
  if (watchBannerTitle) {
    watchBannerTitle.innerText = `🚨 ${alertData.name}`;
    watchBannerTitle.style.color = alertData.color;
  }
  if (watchBannerSub) {
    watchBannerSub.innerText = `${alertData.sinhala} - Tactile Buzz Dispatched`;
  }
  if (vibeWaves) {
    vibeWaves.classList.add("active");
    setTimeout(() => { vibeWaves.classList.remove("active"); }, 3000);
  }

  // 5. PHONE / LAPTOP VIBRATION (If supported)
  if (navigator.vibrate) {
    try {
      if (alertData.level === "HIGH") {
        navigator.vibrate([1000, 100, 1000, 100, 1000]);
      } else {
        navigator.vibrate([500, 100, 500]);
      }
    } catch(e){}
  }
}
window.triggerLiveAlert = triggerLiveAlert;

// 6. APPEND REAL-TIME DETECTION TO SCROLLABLE EVENT FEED
function appendDetectionLog(alertData, confidence, sourceInfo) {
  const logList = document.getElementById("detection-history-list");
  if (!logList) return;

  const now = new Date();
  const timeStr = now.toLocaleTimeString();

  const item = document.createElement("div");
  item.style.padding = "8px 12px";
  item.style.background = "rgba(15, 23, 42, 0.9)";
  item.style.borderLeft = `4px solid ${alertData.color}`;
  item.style.borderRadius = "8px";
  item.style.display = "flex";
  item.style.justifyContent = "space-between";
  item.style.alignItems = "center";
  item.style.fontSize = "0.82rem";

  item.innerHTML = `
    <div>
      <div style="font-weight: bold; color: #ffffff;">${alertData.name}</div>
      <div style="font-size: 0.72rem; color: #94a3b8;">${sourceInfo} • <span style="color: ${alertData.color}; font-weight: bold;">${(confidence * 100).toFixed(0)}% Conf</span></div>
    </div>
    <div style="text-align: right;">
      <span style="background: ${alertData.color}22; color: ${alertData.color}; font-size: 0.7rem; font-weight: 900; padding: 2px 6px; border-radius: 4px; border: 1px solid ${alertData.color}66;">${alertData.level}</span>
      <div style="font-size: 0.7rem; color: #64748b; margin-top: 2px;">${timeStr}</div>
    </div>
  `;

  // Remove placeholder if present
  if (logList.children.length === 1 && logList.children[0].innerText.includes("No sounds detected")) {
    logList.innerHTML = "";
  }

  logList.insertBefore(item, logList.firstChild);

  // Keep max 15 items in history
  while (logList.children.length > 15) {
    logList.removeChild(logList.lastChild);
  }
}

function clearDetectionLog() {
  const logList = document.getElementById("detection-history-list");
  if (logList) {
    logList.innerHTML = '<div style="font-size: 0.8rem; color: #64748b; text-align: center; padding: 10px;">Log cleared. Listening for sounds...</div>';
  }
}
window.clearDetectionLog = clearDetectionLog;

// 7. WAVEFORM VISUALIZER
function startWaveformRender() {
  const canvas = document.getElementById("waveform-canvas");
  if (!canvas) return;
  const ctx = canvas.getContext("2d");

  function draw() {
    requestAnimationFrame(draw);
    if (!analyser || !freqDataArray) return;

    analyser.getByteFrequencyData(freqDataArray);
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    const barCount = 36;
    const step = Math.floor(freqDataArray.length / barCount);
    const barWidth = canvas.width / barCount - 2;

    for (let i = 0; i < barCount; i++) {
      const val = freqDataArray[i * step] / 255.0;
      const barHeight = val * canvas.height * 0.9;
      const x = i * (barWidth + 2);
      const y = canvas.height - barHeight;

      const grad = ctx.createLinearGradient(0, canvas.height, 0, 0);
      grad.addColorStop(0, '#00f2fe');
      grad.addColorStop(0.7, '#7f00ff');
      grad.addColorStop(1, '#ff3b30');

      ctx.fillStyle = grad;
      ctx.fillRect(x, y, barWidth, barHeight);
    }
  }

  canvas.width = canvas.parentElement.clientWidth || 360;
  canvas.height = canvas.parentElement.clientHeight || 90;
  draw();
}

// 8. THREE.JS 3D AVATAR GLOW & MESH SCENE
let avatar3dMeshGroup = null;
let avatarTorusShield = null;
let avatarTorusOuter = null;

function init3DAvatarScene() {
  const container = document.getElementById("avatar-container");
  const canvas = document.getElementById("avatar-3d-canvas");
  if (!container || !canvas) return;

  try {
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(45, canvas.width / canvas.height, 0.1, 1000);
    camera.position.z = 5.2;

    const renderer = new THREE.WebGLRenderer({ canvas: canvas, alpha: true, antialias: true });
    renderer.setSize(canvas.width, canvas.height);

    avatar3dMeshGroup = new THREE.Group();

    // 1. Concentric Acoustic Aura Rings
    const geometry = new THREE.TorusGeometry(1.65, 0.03, 16, 100);
    const material = new THREE.MeshBasicMaterial({ color: 0x00f2fe, transparent: true, opacity: 0.7 });
    avatarTorusShield = new THREE.Mesh(geometry, material);
    avatar3dMeshGroup.add(avatarTorusShield);

    const outerGeom = new THREE.TorusGeometry(1.95, 0.02, 16, 100);
    const outerMat = new THREE.MeshBasicMaterial({ color: 0x7f00ff, transparent: true, opacity: 0.5 });
    avatarTorusOuter = new THREE.Mesh(outerGeom, outerMat);
    avatar3dMeshGroup.add(avatarTorusOuter);

    // 2. Holographic Halo
    const haloGeom = new THREE.RingGeometry(0.7, 0.74, 32);
    const haloMat = new THREE.MeshBasicMaterial({ color: 0x00e5ff, side: THREE.DoubleSide, transparent: true, opacity: 0.8 });
    const halo = new THREE.Mesh(haloGeom, haloMat);
    halo.position.set(0, 1.4, 0);
    halo.rotation.x = Math.PI / 2.3;
    avatar3dMeshGroup.add(halo);

    scene.add(avatar3dMeshGroup);

    let clock = 0;
    function animate() {
      requestAnimationFrame(animate);
      clock += 0.03;

      if (avatarTorusShield) {
        avatarTorusShield.rotation.z += 0.01;
        avatarTorusShield.rotation.x = Math.sin(clock * 0.5) * 0.15;
      }
      if (avatarTorusOuter) {
        avatarTorusOuter.rotation.z -= 0.008;
      }
      if (avatar3dMeshGroup) {
        avatar3dMeshGroup.position.y = Math.sin(clock * 0.8) * 0.06; // Breathing displacement
      }

      renderer.render(scene, camera);
    }
    animate();
  } catch (e){}
}
window.addEventListener("DOMContentLoaded", () => {
  init3DAvatarScene();
});

// 9. WEB BLUETOOTH GATT (OPTIONAL YESIDO IO39 WATCH DIRECT SYNC)
async function toggleBleConnection() {
  if (!navigator.bluetooth) {
    alert("Web Bluetooth is available in Chrome / Edge over HTTPS or localhost.");
    return;
  }
  try {
    const device = await navigator.bluetooth.requestDevice({
      acceptAllDevices: true,
      optionalServices: ['00001802-0000-1000-8000-00805f9b34fb', 'alert_notification']
    });
    const server = await device.gatt.connect();
    isBleConnected = true;
    const btn = document.getElementById("btn-ble-connect");
    if (btn) btn.innerText = "✅ Watch Connected!";
  } catch (e) {
    console.log("[BLE Notice]:", e);
  }
}
window.toggleBleConnection = toggleBleConnection;
