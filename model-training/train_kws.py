import os
import csv
import numpy as np
import librosa
import tensorflow as tf
from tensorflow.keras import layers, models
from sklearn.model_selection import train_test_split

# Configuration
DATASET_PATH = "dataset"
CSV_PATH = "emergency_sounds_dataset.csv"
AUDIO_DIR = "./audio_files/"
MODEL_TFLITE_PATH = "sound_model.tflite"
MODEL_H_PATH = "sound_model.h"
SAMPLE_RATE = 16000
DURATION = 1.0
N_MFCC = 40

CLASSES = [
    "fire_alarm",
    "vehicle_horn",
    "baby_crying",
    "ambulance",
    "udaw",
    "karadarayak",
    "ehaata_wenna",
    "balaagena",
    "ginnak",
    "beeraganna",
    "background_noise"
]

def extract_features(file_path):
    """
    Loads an audio file and extracts the mean MFCC features (40-element 1D vector).
    Matches user dataset extraction pattern for maximum robustness.
    """
    try:
        y, sr = librosa.load(file_path, sr=SAMPLE_RATE, res_type='kaiser_fast')
        mfccs = librosa.feature.mfcc(y=y, sr=sr, n_mfcc=N_MFCC)
        mfccs_scaled_features = np.mean(mfccs.T, axis=0)
        return mfccs_scaled_features
    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return None

def load_data():
    X = []
    y = []
    
    # 1. Check if user provided metadata CSV exists
    if os.path.exists(CSV_PATH):
        print(f"Loading metadata from {CSV_PATH}...")
        try:
            with open(CSV_PATH, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    file_name = os.path.join(AUDIO_DIR, str(row['filename']))
                    class_label = str(row['class_name']).strip().lower()
                    
                    if class_label in CLASSES:
                        label_idx = CLASSES.index(class_label)
                        features = extract_features(file_name)
                        if features is not None:
                            X.append(features)
                            y.append(label_idx)
        except Exception as e:
            print(f"Error reading CSV metadata: {e}")

    # 2. Also load directory-structured dataset from 'dataset/'
    if len(X) == 0:
        print(f"Loading audio dataset from directory structure '{DATASET_PATH}'...")
        for label_idx, label_name in enumerate(CLASSES):
            class_dir = os.path.join(DATASET_PATH, label_name)
            if not os.path.exists(class_dir):
                print(f"Warning: Directory '{class_dir}' does not exist. Skipping.")
                continue
                
            files = [f for f in os.listdir(class_dir) if f.endswith('.wav') or f.endswith('.mp3') or f.endswith('.ogg')]
            print(f"Processing {len(files)} files for class: {label_name}")
            
            for f in files:
                file_path = os.path.join(class_dir, f)
                features = extract_features(file_path)
                if features is not None:
                    X.append(features)
                    y.append(label_idx)
                    
    return np.array(X), np.array(y)

def build_model(input_shape, num_classes):
    """
    Robust Neural Network architecture for 40-element mean MFCC vectors.
    """
    model = models.Sequential([
        layers.Input(shape=input_shape),
        layers.Dense(256, activation='relu'),
        layers.BatchNormalization(),
        layers.Dropout(0.3),
        layers.Dense(128, activation='relu'),
        layers.BatchNormalization(),
        layers.Dropout(0.3),
        layers.Dense(64, activation='relu'),
        layers.Dropout(0.2),
        layers.Dense(num_classes, activation='softmax')
    ])
    return model

def convert_to_tflite(model):
    print("Converting model to TensorFlow Lite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    return tflite_model

def save_as_c_header(tflite_model, output_path):
    print(f"Generating C++ Header File at '{output_path}'...")
    bytes_data = bytes(tflite_model)
    hex_lines = []
    
    for i in range(0, len(bytes_data), 12):
        chunk = bytes_data[i:i+12]
        hex_vals = ', '.join([f"0x{b:02x}" for b in chunk])
        hex_lines.append(f"  {hex_vals}")
        
    c_content = f"""// Auto-generated TFLite Model Header File
// Model Size: {len(bytes_data)} bytes

#ifndef SOUND_MODEL_H
#define SOUND_MODEL_H

const unsigned char g_sound_model[] = {{
{',\n'.join(hex_lines)}
}};

const unsigned int g_sound_model_len = {len(bytes_data)};

#endif // SOUND_MODEL_H
"""
    with open(output_path, 'w') as f:
        f.write(c_content)
    print("C++ header file written successfully.")

def main():
    X, y = load_data()
    
    if len(X) == 0:
        print("Error: No data loaded. Please run 'prepare_dataset.py' first.")
        return
        
    print(f"Loaded {X.shape[0]} samples. Feature shape: {X.shape[1:]}")
    
    # Standardize data scale
    mean = np.mean(X, axis=0)
    std = np.std(X, axis=0) + 1e-8
    
    np.save("mean.npy", mean)
    np.save("std.npy", std)
    print("Saved training mean.npy and std.npy statistics.")
    
    X_normalized = (X - mean) / std
    
    X_train, X_test, y_train, y_test = train_test_split(X_normalized, y, test_size=0.2, random_state=42)
    
    input_shape = (N_MFCC,) # (40,)
    num_classes = len(CLASSES)
    model = build_model(input_shape, num_classes)
    
    model.summary()
    
    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    print("Training neural network...")
    epochs = 25
    batch_size = 16
    
    history = model.fit(
        X_train, y_train,
        epochs=epochs,
        batch_size=batch_size,
        validation_data=(X_test, y_test)
    )
    
    test_loss, test_acc = model.evaluate(X_test, y_test)
    print(f"Test accuracy: {test_acc:.4f}")
    
    model.save("sound_model.keras")
    
    tflite_model = convert_to_tflite(model)
    with open(MODEL_TFLITE_PATH, 'wb') as f:
        f.write(tflite_model)
    print(f"Saved TensorFlow Lite model to '{MODEL_TFLITE_PATH}'")
    
    save_as_c_header(tflite_model, MODEL_H_PATH)
    
    print("\nAll training and conversion steps completed successfully!")

if __name__ == "__main__":
    main()
