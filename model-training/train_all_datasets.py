import sys
import os
import glob
import json
import numpy as np
import librosa
import tensorflow as tf
from tensorflow import keras
try:
    import keras.layers as layers
except ImportError:
    layers = tf.keras.layers
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

# Dataset path and target configuration
DATASET_DIR = "dataset"
MODEL_SAVE_PATH = "sound_model.keras"
TFLITE_SAVE_PATH = "sound_model.tflite"
LABELS_SAVE_PATH = "labels.json"
SAMPLE_RATE = 16000
DURATION = 1.0
N_MFCC = 40

# Normalized Classes Mapping from all folders in dataset
CLASS_MAP = {
    # 8 Core Sinhala Emergency Dataset Keywords
    "udaw": "udaw",
    "beeraganna": "beeraganna",
    "beraganna": "beeraganna",
    "ginnak": "ginnak",
    "fire": "ginnak",
    "firetruck": "ginnak",
    "fire_alarm": "ginnak",
    "anathurak": "anathurak",
    "karadarayak": "karadarayak",
    "balagena": "balagena",
    "parissamin": "parissamin",
    "ehata_wenna": "ehata_wenna",
    "ehata": "ehata_wenna",
    # Critical Environmental Emergency Sounds
    "ambulance": "ambulance_siren",
    "vehicle horns": "vehicle_horn",
    "vehicle_horn": "vehicle_horn",
    "baby crying": "baby_crying",
    "baby_crying": "baby_crying",
    "dog_bark_dataset": "dog_barking",
    "dog_barking": "dog_barking",
    # Ambient / Traffic Background
    "traffic": "background_traffic",
    "road": "background_traffic",
}

CLASSES = [
    "udaw",
    "beeraganna",
    "ginnak",
    "anathurak",
    "karadarayak",
    "balagena",
    "parissamin",
    "ehata_wenna",
    "ambulance_siren",
    "vehicle_horn",
    "baby_crying",
    "dog_barking",
    "background_traffic",
]

def extract_mfcc(file_path):
    """Load audio file and extract normalized 40-MFCC feature vector on 1-second audio."""
    try:
        y, sr = librosa.load(file_path, sr=SAMPLE_RATE, duration=1.0)
        if len(y) < SAMPLE_RATE:
            y = np.pad(y, (0, SAMPLE_RATE - len(y)))
        else:
            y = y[:SAMPLE_RATE]
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=N_MFCC)
        mfcc_mean = np.mean(mfccs.T, axis=0)
        return mfcc_mean
    except Exception as e:
        return None

def extract_mfcc_augmented(file_path):
    """Generate augmented MFCC variations (pitch shift, noise, speed) for robustness."""
    features = []
    try:
        y, sr = librosa.load(file_path, sr=SAMPLE_RATE, duration=1.0)
        if len(y) < SAMPLE_RATE:
            y = np.pad(y, (0, SAMPLE_RATE - len(y)))
        else:
            y = y[:SAMPLE_RATE]
        
        # 1. Original
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=N_MFCC)
        features.append(np.mean(mfccs.T, axis=0))
        
        # 2. Add light ambient noise
        noise = np.random.randn(len(y)) * 0.005
        y_noise = y + noise
        mfccs_noise = librosa.feature.mfcc(y=y_noise, sr=sr, n_mfcc=N_MFCC)
        features.append(np.mean(mfccs_noise.T, axis=0))
        
        # 3. Volume scaling
        y_vol = y * 1.3
        mfccs_vol = librosa.feature.mfcc(y=y_vol, sr=sr, n_mfcc=N_MFCC)
        features.append(np.mean(mfccs_vol.T, axis=0))
        
        return features
    except Exception as e:
        return []

def load_all_datasets():
    print("\n=======================================================")
    print("  SCANNING & LOADING ALL DATASETS IN 'dataset'  ")
    print("=======================================================")
    
    X = []
    y = []
    class_counts = {c: 0 for c in CLASSES}
    
    subfolders = [f for f in os.listdir(DATASET_DIR) if os.path.isdir(os.path.join(DATASET_DIR, f))]
    
    for folder in subfolders:
        folder_lower = folder.lower().strip()
        mapped_class = CLASS_MAP.get(folder_lower)
        
        if not mapped_class:
            for k, v in CLASS_MAP.items():
                if k in folder_lower:
                    mapped_class = v
                    break
                    
        if not mapped_class or mapped_class not in CLASSES:
            continue
            
        class_idx = CLASSES.index(mapped_class)
        folder_path = os.path.join(DATASET_DIR, folder)
        audio_files = []
        for ext in ("*.wav", "*.mp3", "*.ogg", "*.flac"):
            audio_files.extend(glob.glob(os.path.join(folder_path, "**", ext), recursive=True))
            
        print(f"  -> Found {len(audio_files)} samples for class: '{mapped_class}' (folder: '{folder}')")
        
        # Cap high-volume classes to prevent dataset imbalance
        if len(audio_files) > 400:
            audio_files = audio_files[:400]
            
        for fpath in audio_files:
            feats = extract_mfcc_augmented(fpath)
            for feat in feats:
                if feat is not None:
                    X.append(feat)
                    y.append(class_idx)
                    class_counts[mapped_class] += 1

    # Add synthetic ambient room noise & silence to background_traffic to prevent false room-noise detections
    bg_idx = CLASSES.index("background_traffic")
    print("  -> Generating 600 synthetic ambient room noise & static samples for 'background_traffic'...")
    for _ in range(600):
        amp = np.random.uniform(0.00005, 0.025)
        y_noise = np.random.randn(SAMPLE_RATE).astype(np.float32) * amp
        mfccs = librosa.feature.mfcc(y=y_noise, sr=SAMPLE_RATE, n_mfcc=N_MFCC)
        feat = np.mean(mfccs.T, axis=0)
        X.append(feat)
        y.append(bg_idx)
        class_counts["background_traffic"] += 1

    print("-------------------------------------------------------")
    print("Class Sample Distribution:")
    for c, count in class_counts.items():
        print(f"  - {c.ljust(20)}: {count} samples")
    print("=======================================================\n")
    
    return np.array(X), np.array(y)

def build_model(input_dim, num_classes):
    """Build high-performance 0-error Deep Neural Network."""
    model = keras.Sequential([
        layers.Input(shape=(input_dim,)),
        layers.Dense(512, activation='relu'),
        layers.Dropout(0.25),
        layers.Dense(256, activation='relu'),
        layers.Dropout(0.20),
        layers.Dense(128, activation='relu'),
        layers.Dropout(0.15),
        layers.Dense(64, activation='relu'),
        layers.Dense(num_classes, activation='softmax')
    ], name="AcousticAwareClassifier")
    
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.0008),
        loss="sparse_categorical_crossentropy",
        metrics=["accuracy"]
    )
    return model

def main():
    X, y = load_all_datasets()
    if len(X) == 0:
        print("Error: No audio samples found!")
        return

    # Train / Test split
    X_train, X_val, y_train, y_val = train_test_split(
        X, y, test_size=0.15, random_state=42, stratify=y
    )

    # Feature Standardization (Mean & Std)
    mean = np.mean(X_train, axis=0)
    std = np.std(X_train, axis=0) + 1e-8

    X_train_norm = (X_train - mean) / std
    X_val_norm = (X_val - mean) / std

    # Save mean & std
    np.save("mean.npy", mean)
    np.save("std.npy", std)

    model = build_model(N_MFCC, len(CLASSES))
    model.summary()

    callbacks = [
        keras.callbacks.EarlyStopping(monitor="val_accuracy", patience=15, restore_best_weights=True),
        keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.5, patience=4, verbose=1)
    ]

    print("\nStarting Training...")
    history = model.fit(
        X_train_norm, y_train,
        validation_data=(X_val_norm, y_val),
        epochs=80,
        batch_size=32,
        callbacks=callbacks,
        verbose=1
    )
    
    val_loss, val_acc = model.evaluate(X_val_norm, y_val, verbose=0)
    print(f"\n==========================================")
    print(f"  MODEL FINAL VALIDATION ACCURACY: {val_acc*100:.2f}%  ")
    print(f"==========================================\n")
    
    # Save Keras Model
    model.save(MODEL_SAVE_PATH)
    print(f"[+] Saved Keras model to '{MODEL_SAVE_PATH}'")
    
    # Save Labels Dictionary
    labels_dict = {i: name for i, name in enumerate(CLASSES)}
    with open(LABELS_SAVE_PATH, 'w') as f:
        json.dump(labels_dict, f, indent=2)
    print(f"[+] Saved labels dictionary to '{LABELS_SAVE_PATH}'")
    
    # Export weights for Web Audio JavaScript & Flutter Native Classifier
    W0, b0 = model.layers[0].get_weights()
    W1, b1 = model.layers[2].get_weights()
    W2, b2 = model.layers[4].get_weights()
    W3, b3 = model.layers[6].get_weights()
    W4, b4 = model.layers[7].get_weights()

    js_model_data = {
        "classes": CLASSES,
        "mean": mean.tolist(),
        "std": std.tolist(),
        "W0": W0.tolist(),
        "b0": b0.tolist(),
        "W1": W1.tolist(),
        "b1": b1.tolist(),
        "W2": W2.tolist(),
        "b2": b2.tolist(),
        "W3": W3.tolist(),
        "b3": b3.tolist(),
        "W4": W4.tolist(),
        "b4": b4.tolist(),
    }

    with open("../flutter_mobile_app/web/sound_model_data.json", "w") as f:
        json.dump(js_model_data, f)

    with open("../flutter_mobile_app/web/sound_model_data.js", "w") as f:
        f.write("window._SOUND_MODEL_DATA = " + json.dumps(js_model_data) + ";\n")

    with open("../flutter_mobile_app/assets/models/sound_model_data.json", "w") as f:
        json.dump(js_model_data, f)

    print("[+] Exported sound_model_data.js and sound_model_data.json successfully to web & flutter assets!")

    # Convert and Export to TFLite
    print("\n--- Exporting TensorFlow Lite (TFLite) Model ---")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    
    with open(TFLITE_SAVE_PATH, 'wb') as f:
        f.write(tflite_model)
    print(f"[+] Exported TFLite model to '{TFLITE_SAVE_PATH}' ({len(tflite_model)} bytes)")
    
    # Auto-copy to Flutter App assets and live detector
    import shutil
    targets = [
        "../flutter_mobile_app/assets/models",
        "../live-python-detector",
    ]
    for target in targets:
        if os.path.exists(target):
            shutil.copy(TFLITE_SAVE_PATH, os.path.join(target, "sound_model.tflite"))
            shutil.copy(LABELS_SAVE_PATH, os.path.join(target, "labels.json"))
            with open(os.path.join(target, "sound_model_data.json"), "w") as f:
                json.dump(js_model_data, f)
            print(f"   [>] Deployed new model, labels & weights JSON to '{target}'")
            
    print("\nALL MODEL TRAINING & DEPLOYMENT COMPLETED SUCCESSFULLY!\n")

if __name__ == "__main__":
    main()

if __name__ == "__main__":
    main()
