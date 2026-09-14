import os
import wave
import math
import struct
import random

# Configuration
SAMPLE_RATE = 16000
DURATION_SEC = 1.0
NUM_SAMPLES_PER_CLASS = 150

CLASSES = [
    # Environmental Sounds
    "fire_alarm",
    "ambulance_siren",
    "vehicle_horn",
    "baby_crying",
    "dog_barking",
    # Sinhala Emergency Keywords
    "udaw",
    "udaw_karanna",
    "anathurak",
    "karadarayak",
    "parissamin",
    "ehata_wenna",
    "balagena",
    "nawaththanna",
    "ginna",
    # Negative Background Class
    "background_other"
]

def generate_sine_wave(freq, duration, amplitude=0.5):
    num_samples = int(duration * SAMPLE_RATE)
    return [amplitude * math.sin(2.0 * math.pi * freq * (i / SAMPLE_RATE)) for i in range(num_samples)]

def generate_noise(duration, amplitude=0.1):
    num_samples = int(duration * SAMPLE_RATE)
    return [amplitude * (random.random() * 2.0 - 1.0) for _ in range(num_samples)]

def generate_chirp(start_freq, end_freq, duration, amplitude=0.5):
    num_samples = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        freq = start_freq + (end_freq - start_freq) * (t / (2 * duration))
        samples.append(amplitude * math.sin(2.0 * math.pi * freq * t))
    return samples

def apply_soft_clipping(audio):
    clipped = []
    for x in audio:
        if x > 0.7:
            clipped.append(0.7 + (x - 0.7) / (1 + (x - 0.7)**2))
        elif x < -0.7:
            clipped.append(-0.7 + (x + 0.7) / (1 + (x + 0.7)**2))
        else:
            clipped.append(x)
    return clipped

def save_wav(filepath, audio_data):
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with wave.open(filepath, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        for val in audio_data:
            val = max(-1.0, min(1.0, val))
            packed = struct.pack('<h', int(val * 32767))
            w.writeframesraw(packed)

def create_synthetic_dataset(base_dir="dataset"):
    print(f"Creating highly diverse dataset in '{base_dir}' across {len(CLASSES)} classes...")
    
    for label in CLASSES:
        print(f"Generating {NUM_SAMPLES_PER_CLASS} samples for class: '{label}'")
        class_dir = os.path.join(base_dir, label)
        
        for idx in range(NUM_SAMPLES_PER_CLASS):
            audio = []
            var = random.uniform(0.85, 1.15)
            
            if label == "fire_alarm":
                alarm_type = idx % 3
                if alarm_type == 0:
                    pulse_len = 0.20 * var
                    gap_len = 0.10 * var
                    beep = generate_sine_wave(3150 * var, pulse_len, amplitude=0.6)
                    silence = [0.0] * int(gap_len * SAMPLE_RATE)
                    audio = (beep + silence) * 3
                elif alarm_type == 1:
                    t_samples = int(SAMPLE_RATE * DURATION_SEC)
                    for s in range(t_samples):
                        t = s / SAMPLE_RATE
                        val = 0.4 * math.sin(2.0 * math.pi * 3300 * var * t)
                        audio.append(0.38 if val >= 0 else -0.38)
                else:
                    f1 = generate_sine_wave(950 * var, 0.25, amplitude=0.5)
                    f2 = generate_sine_wave(1400 * var, 0.25, amplitude=0.5)
                    audio = (f1 + f2) * 2
                    
            elif label == "ambulance_siren":
                siren_type = idx % 3
                t_samples = int(SAMPLE_RATE * DURATION_SEC)
                if siren_type == 0:
                    for s in range(t_samples):
                        t = s / SAMPLE_RATE
                        lfo = 0.5 * (1.0 + math.sin(2.0 * math.pi * 1.0 * var * t))
                        freq = 600 + 1000 * lfo
                        audio.append(0.35 * (math.sin(2.0 * math.pi * freq * t) + 0.4 * math.sin(2.0 * math.pi * 2 * freq * t)))
                elif siren_type == 1:
                    for s in range(t_samples):
                        t = s / SAMPLE_RATE
                        lfo = 0.5 * (1.0 + math.sin(2.0 * math.pi * 3.8 * var * t))
                        freq = 700 + 1200 * lfo
                        audio.append(0.35 * (math.sin(2.0 * math.pi * freq * t) + 0.3 * math.sin(2.0 * math.pi * 2 * freq * t)))
                else:
                    for s in range(t_samples):
                        t = s / SAMPLE_RATE
                        freq = 720.0 * var if int(t * 4) % 2 == 0 else 480.0 * var
                        audio.append(0.4 * (math.sin(2.0 * math.pi * freq * t) + 0.3 * math.sin(2.0 * math.pi * 3 * freq * t)))
                        
            elif label == "vehicle_horn":
                horn_type = idx % 3
                if horn_type == 0:
                    w1 = generate_sine_wave(410 * var, DURATION_SEC, amplitude=0.45)
                    w2 = generate_sine_wave(520 * var, DURATION_SEC, amplitude=0.35)
                    audio = [a + b for a, b in zip(w1, w2)]
                elif horn_type == 1:
                    t_samples = int(SAMPLE_RATE * DURATION_SEC)
                    for s in range(t_samples):
                        t = s / SAMPLE_RATE
                        audio.append(0.5 * math.sin(2.0 * math.pi * 180 * var * t) + 0.3 * math.sin(2.0 * math.pi * 360 * var * t))
                else:
                    audio = generate_sine_wave(1100 * var, DURATION_SEC, amplitude=0.55)
                audio = apply_soft_clipping(audio)

            elif label == "baby_crying":
                cry_type = idx % 3
                t_samples = int(SAMPLE_RATE * DURATION_SEC)
                if cry_type == 0:
                    for s in range(t_samples):
                        t = s / SAMPLE_RATE
                        lfo = math.sin(2.0 * math.pi * 1.8 * var * t)
                        freq = 550 + 750 * max(0.0, lfo)
                        audio.append(0.3 * math.sin(2.0 * math.pi * freq * t) * (0.7 + 0.3 * math.sin(2.0 * math.pi * 8.5 * t)))
                else:
                    for s in range(t_samples):
                        t = s / SAMPLE_RATE
                        env = math.sin(2.0 * math.pi * 1.2 * var * t)
                        freq = 480 + 350 * max(0.0, env)
                        audio.append(0.35 * math.sin(2.0 * math.pi * freq * t))

            elif label == "dog_barking":
                # Dog Barking: Short 0.15s pitch bursts (250-600 Hz) with quiet gaps
                pulse_len = 0.15 * var
                gap_len = 0.20 * var
                bark = generate_chirp(250 * var, 550 * var, pulse_len, amplitude=0.5)
                silence = [0.0] * int(gap_len * SAMPLE_RATE)
                audio = (bark + silence) * 3

            elif label == "screaming":
                noise = generate_noise(DURATION_SEC, amplitude=0.25)
                chirp = generate_chirp(1000 * var, 2500 * var, DURATION_SEC, amplitude=0.35)
                audio = [n + c for n, c in zip(noise, chirp)]

            # Sinhala Keyword Spotting (Synthetic Speech Formant Approximations)
            elif label == "udaw":
                v1 = generate_sine_wave(250 * var, 0.4, amplitude=0.4)
                consonant = generate_noise(0.1, amplitude=0.08)
                v2 = generate_sine_wave(700 * var, 0.5, amplitude=0.4)
                audio = v1 + consonant + v2

            elif label == "udaw_karanna":
                v1 = generate_sine_wave(250 * var, 0.25, amplitude=0.4)
                v2 = generate_sine_wave(700 * var, 0.25, amplitude=0.4)
                k1 = generate_sine_wave(350 * var, 0.25, amplitude=0.35)
                k2 = generate_sine_wave(450 * var, 0.25, amplitude=0.35)
                audio = v1 + v2 + k1 + k2

            elif label == "anathurak":
                a1 = generate_sine_wave(400 * var, 0.25, amplitude=0.35)
                a2 = generate_sine_wave(500 * var, 0.25, amplitude=0.35)
                a3 = generate_sine_wave(600 * var, 0.25, amplitude=0.35)
                a4 = generate_sine_wave(350 * var, 0.25, amplitude=0.35)
                audio = a1 + a2 + a3 + a4

            elif label == "karadarayak":
                s1 = generate_sine_wave(300 * var, 0.25, amplitude=0.3)
                s2 = generate_sine_wave(450 * var, 0.25, amplitude=0.3)
                s3 = generate_sine_wave(350 * var, 0.25, amplitude=0.3)
                s4 = generate_sine_wave(500 * var, 0.25, amplitude=0.3)
                audio = s1 + s2 + s3 + s4

            elif label == "parissamin":
                p1 = generate_sine_wave(450 * var, 0.25, amplitude=0.35)
                p2 = generate_sine_wave(650 * var, 0.25, amplitude=0.35)
                p3 = generate_sine_wave(550 * var, 0.25, amplitude=0.35)
                p4 = generate_sine_wave(350 * var, 0.25, amplitude=0.35)
                audio = p1 + p2 + p3 + p4

            elif label == "ehata_wenna":
                s1 = generate_sine_wave(600 * var, 0.2, amplitude=0.3)
                s2 = generate_sine_wave(700 * var, 0.2, amplitude=0.3)
                s3 = generate_sine_wave(500 * var, 0.3, amplitude=0.3)
                s4 = generate_sine_wave(400 * var, 0.3, amplitude=0.3)
                audio = s1 + s2 + s3 + s4

            elif label == "balagena":
                s1 = generate_chirp(400 * var, 450 * var, 0.25, amplitude=0.3)
                s2 = generate_sine_wave(300 * var, 0.25, amplitude=0.3)
                s3 = generate_chirp(300 * var, 500 * var, 0.25, amplitude=0.3)
                s4 = generate_sine_wave(400 * var, 0.25, amplitude=0.3)
                audio = s1 + s2 + s3 + s4

            elif label == "nawaththanna":
                n1 = generate_sine_wave(350 * var, 0.25, amplitude=0.35)
                n2 = generate_sine_wave(550 * var, 0.25, amplitude=0.35)
                n3 = generate_sine_wave(450 * var, 0.25, amplitude=0.35)
                n4 = generate_sine_wave(300 * var, 0.25, amplitude=0.35)
                audio = n1 + n2 + n3 + n4

            elif label == "ginna":
                g1 = generate_sine_wave(500 * var, 0.4, amplitude=0.4)
                g2 = generate_noise(0.2, amplitude=0.2)
                g3 = generate_sine_wave(400 * var, 0.4, amplitude=0.4)
                audio = g1 + g2 + g3

            elif label == "background_other":
                bg_type = idx % 4
                if bg_type == 0:
                    audio = generate_noise(DURATION_SEC, amplitude=0.08)
                elif bg_type == 1:
                    w1 = generate_sine_wave(50, DURATION_SEC, amplitude=0.08)
                    w2 = generate_sine_wave(100, DURATION_SEC, amplitude=0.04)
                    audio = [x + y for x, y in zip(w1, w2)]
                elif bg_type == 2:
                    # Fan / AC hum + speech chatter simulation
                    noise = generate_noise(DURATION_SEC, amplitude=0.05)
                    speech = generate_sine_wave(180 * var, DURATION_SEC, amplitude=0.04)
                    audio = [n + s for n, s in zip(noise, speech)]
                else:
                    audio = [0.0] * int(SAMPLE_RATE * DURATION_SEC)
                    for c in range(5):
                        click_idx = random.randint(0, len(audio)-1)
                        audio[click_idx] = random.uniform(-0.15, 0.15)
            
            # Standardize length to exactly 1.0 second
            expected_samples = int(SAMPLE_RATE * DURATION_SEC)
            audio = audio[:expected_samples]
            if len(audio) < expected_samples:
                audio = audio + [0.0] * (expected_samples - len(audio))
                
            # Add general background noise
            bg_noise = generate_noise(DURATION_SEC, amplitude=0.02)
            audio = [a + n for a, n in zip(audio, bg_noise)]
            
            filename = f"sample_{idx:03d}.wav"
            save_wav(os.path.join(class_dir, filename), audio)
            
    print(f"Dataset generation complete for all {len(CLASSES)} classes!")

if __name__ == "__main__":
    create_synthetic_dataset()
