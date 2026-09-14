import os
import wave
import math
import struct
import random

SAMPLE_RATE = 16000

def soft_clip(x):
    # Soft distortion to simulate real speaker saturation and casing resonance
    if x > 0.8:
        return 0.8 + (x - 0.8) / (1 + (x - 0.8) * (x - 0.8))
    elif x < -0.8:
        return -0.8 + (x + 0.8) / (1 + (x + 0.8) * (x + 0.8))
    return x

def save_wav(filename, audio_data):
    filepath = os.path.join(os.path.dirname(__file__), filename)
    with wave.open(filepath, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        for val in audio_data:
            # Apply soft clipping and convert to 16-bit
            val = soft_clip(val)
            val = max(-1.0, min(1.0, val))
            packed = struct.pack('<h', int(val * 32767))
            w.writeframesraw(packed)
    print(f"Synthesized realistic sound: {filename}")

def main():
    dest_dir = os.path.dirname(__file__)

    # 1. REAL-LIFE VEHICLE HORN (Metallic dual-tone chord with harmonics and clipper distortion)
    # Mimics a real-world high-gain metal diaphragm horn blast
    horn_audio = []
    duration = 2.0
    num_samples = int(duration * SAMPLE_RATE)
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Core dual tones
        s1 = math.sin(2.0 * math.pi * 410 * t)
        s2 = math.sin(2.0 * math.pi * 470 * t)
        # Harmonics
        h1 = 0.5 * math.sin(2.0 * math.pi * 820 * t)
        h2 = 0.4 * math.sin(2.0 * math.pi * 940 * t)
        h3 = 0.2 * math.sin(2.0 * math.pi * 1230 * t)
        # Slight high frequency chassis rattle noise
        n = 0.05 * (random.random() * 2 - 1)
        
        val = (s1 + s2 + h1 + h2 + h3 + n) * 0.35
        horn_audio.append(val)
    save_wav("test_horn.wav", horn_audio)

    # 2. REAL-LIFE AMBULANCE SIREN (Continuous wailing yelp/phaser sweeps with rich harmonics)
    # Slow LFO wail for 1s, then fast LFO yelp for 1s
    siren_audio = []
    duration = 2.5
    num_samples = int(duration * SAMPLE_RATE)
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # LFO: Pitch sweeps from 650Hz to 1450Hz
        if t < 1.25:
            # Slow sweep (1Hz LFO)
            lfo = 0.5 * (1.0 + math.sin(2.0 * math.pi * 0.8 * t - math.pi / 2))
        else:
            # Fast sweep / Yelp (3Hz LFO)
            lfo = 0.5 * (1.0 + math.sin(2.0 * math.pi * 2.8 * t))
            
        freq = 650 + 800 * lfo
        
        # Phase integration
        # For simplicity in synthesis, we calculate instantaneous phase
        val = math.sin(2.0 * math.pi * freq * t)
        # Add 2nd and 3rd harmonics for typical siren sharp buzz
        val += 0.4 * math.sin(2.0 * math.pi * 2 * freq * t)
        val += 0.2 * math.sin(2.0 * math.pi * 3 * freq * t)
        
        siren_audio.append(val * 0.3)
    save_wav("test_ambulance.wav", siren_audio)

    # 3. REAL-LIFE BABY CRYING (Formant-swept wails with vocal tremolo and gasps)
    # Mimics human vocal chord modulation
    cry_audio = []
    duration = 2.5
    num_samples = int(duration * SAMPLE_RATE)
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        
        # Periodic cry cycle: 0.7s cry, 0.1s gasp, 0.7s cry...
        cycle = t % 0.8
        if cycle > 0.7:
            # Gasp (vocal intake breath noise)
            val = 0.08 * (random.random() * 2 - 1)
        else:
            # Crying pitch starts high, falls slightly
            # Sweep frequency between 480Hz and 750Hz
            pitch_lfo = math.sin(2.0 * math.pi * (1.0 / 0.7) * cycle)
            freq = 500 + 180 * max(0.0, pitch_lfo)
            
            # Formant harmonics (mimicking throat and mouth resonances)
            f0 = math.sin(2.0 * math.pi * freq * t)
            f1 = 0.6 * math.sin(2.0 * math.pi * 2 * freq * t)
            f2 = 0.3 * math.sin(2.0 * math.pi * 3 * freq * t)
            f3 = 0.15 * math.sin(2.0 * math.pi * 4 * freq * t)
            
            # Human crying tremolo (vibrato/tremble of vocal chords at 7.5Hz)
            tremolo = 0.7 + 0.3 * math.sin(2.0 * math.pi * 7.5 * t)
            
            # Amplitude fade out at the end of each cry breath
            envelope = math.sin(math.pi * (cycle / 0.7))
            
            val = (f0 + f1 + f2 + f3) * tremolo * envelope * 0.22
            
        cry_audio.append(val)
    save_wav("test_baby_crying.wav", cry_audio)

    # 4. REAL-LIFE FIRE ALARMS (Temporal-3 Pulse Beeps & Industrial continuous sirens)
    # First 1.2s: standard smoke alarm T-3 pattern (0.3s beep, 0.1s gap) at 3200Hz
    # Next 1.3s: industrial continuous electronic alarm sweep
    fire_audio = []
    duration = 2.5
    num_samples = int(duration * SAMPLE_RATE)
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        if t < 1.25:
            # Standard Temporal 3 Smoke Alarm beep: 0.25s on, 0.15s off
            cycle = t % 0.4
            if cycle < 0.25:
                val = 0.4 * math.sin(2.0 * math.pi * 3150 * t)
                # Make it a piercing square-like beep
                val = 0.4 if val >= 0 else -0.4
            else:
                val = 0.0
        else:
            # Industrial horn siren: alternating 800Hz / 1000Hz beeps
            cycle = (t - 1.25) % 0.5
            freq = 950 if cycle < 0.25 else 750
            val = 0.35 * math.sin(2.0 * math.pi * freq * t)
            
        fire_audio.append(val)
    save_wav("test_fire_alarm.wav", fire_audio)

    # 5. REAL-LIFE SCREAMING (Loud wideband throat noise + pitch sweep)
    scream_audio = []
    duration = 1.8
    num_samples = int(duration * SAMPLE_RATE)
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        # Noise component
        n = 0.25 * (random.random() * 2 - 1)
        # Pitch chirp (screech)
        chirp_freq = 1100 + 1300 * (t / duration)
        c = 0.35 * math.sin(2.0 * math.pi * chirp_freq * t)
        
        # Vocal modulation envelope
        envelope = math.sin(math.pi * (t / duration))
        
        scream_audio.append((n + c) * envelope * 0.35)
    save_wav("test_screaming.wav", scream_audio)

if __name__ == "__main__":
    main()
