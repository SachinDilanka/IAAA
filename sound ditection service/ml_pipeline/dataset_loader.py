import os
import glob
import numpy as np
import librosa
import soundfile as sf

TARGET_SR = 16000
TARGET_DURATION = 1.0  # 1 second window
TARGET_SAMPLES = int(TARGET_SR * TARGET_DURATION)  # 16000 samples
N_MELS = 64
N_FFT = 1024
HOP_LENGTH = 512

CLASS_MAPPING = {
    'sinhala_udaw_': ('Udaw', 'high'),
    'sinhala_anathurak_': ('Anathurak', 'high'),
    'sinhala_beraganna_': ('Beraganna', 'high'),
    'sinhala_ginnak_': ('Ginnak', 'high'),
    'ambulance': ('Ambulance Siren', 'high'),
    'vehicle horns': ('Vehicle Horns', 'high'),
    'sinhala_karadarayak_': ('Karadarayak', 'medium'),
    'sinhala_balagena_': ('Balaagena', 'medium'),
    'sinhala_ehata_wenna_': ('Ehata Wenna', 'medium'),
    'baby crying': ('Baby Crying', 'medium'),
    'dog_bark_dataset': ('Dog Barking', 'medium'),
    'sinhala_parissamin_': ('Parissamin', 'low'),
    'road': ('Road Sounds', 'low'),
    'traffic': ('Traffic Noise', 'low'),
}

LABELS = sorted(list(CLASS_MAPPING.keys()))

def extract_mel_spectrogram(audio):
    if len(audio) < TARGET_SAMPLES:
        pad_width = TARGET_SAMPLES - len(audio)
        audio = np.pad(audio, (0, pad_width), mode='constant')
    else:
        audio = audio[:TARGET_SAMPLES]
        
    mel_spec = librosa.feature.melspectrogram(
        y=audio,
        sr=TARGET_SR,
        n_fft=N_FFT,
        hop_length=HOP_LENGTH,
        n_mels=N_MELS
    )
    log_mel = librosa.power_to_db(mel_spec, ref=np.max)
    # Normalize to [0, 1]
    log_mel_norm = (log_mel - log_mel.min()) / (log_mel.max() - log_mel.min() + 1e-6)
    return log_mel_norm

def load_dataset(dataset_dir):
    X = []
    y = []
    
    print(f"Loading dataset from: {dataset_dir}")
    for idx, folder_name in enumerate(LABELS):
        folder_path = os.path.join(dataset_dir, folder_name)
        if not os.path.exists(folder_path):
            print(f"Warning: Directory not found: {folder_path}")
            continue
            
        wav_files = glob.glob(os.path.join(folder_path, "**", "*.wav"), recursive=True)
        print(f"Loading category {folder_name} ({CLASS_MAPPING[folder_name][0]}): {len(wav_files)} files...")
        
        for wav_path in wav_files:
            try:
                audio, sr = librosa.load(wav_path, sr=TARGET_SR, mono=True)
                # Slicing 1-sec windows for longer clips to multiply dataset
                if len(audio) >= TARGET_SAMPLES:
                    num_chunks = max(1, len(audio) // TARGET_SAMPLES)
                    for i in range(num_chunks):
                        chunk = audio[i * TARGET_SAMPLES : (i + 1) * TARGET_SAMPLES]
                        if len(chunk) == TARGET_SAMPLES:
                            spec = extract_mel_spectrogram(chunk)
                            X.append(spec)
                            y.append(idx)
                else:
                    spec = extract_mel_spectrogram(audio)
                    X.append(spec)
                    y.append(idx)
            except Exception as e:
                pass

    X = np.array(X, dtype=np.float32)
    # Expand dims for 2D CNN (freq, time, channel=1)
    X = np.expand_dims(X, axis=-1)
    y = np.array(y, dtype=np.int64)
    
    print(f"Dataset loaded. Total samples: {X.shape[0]}, Feature shape: {X.shape[1:]}")
    return X, y, LABELS

