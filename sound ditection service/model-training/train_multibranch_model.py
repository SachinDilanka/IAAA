import os
import glob
import wave
import json
import numpy as np
import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, confusion_matrix
from prepare_dataset import create_synthetic_dataset, CLASSES, SAMPLE_RATE, DURATION_SEC

# Configuration
DATASET_DIR = "dataset"
MODEL_SAVE_PATH = "sound_model.keras"
TFLITE_SAVE_PATH = "sound_model.tflite"
LABELS_SAVE_PATH = "labels.json"
N_MELS = 64
FRAME_LENGTH = 512
FRAME_STEP = 256

def load_wav(file_path):
    with wave.open(file_path, 'rb') as w:
        frames = w.readframes(w.getnframes())
        audio = np.frombuffer(frames, dtype=np.int16).astype(np.float32) / 32768.0
    return audio

def compute_mel_spectrogram(audio):
    stft = tf.signal.stft(
        audio,
        frame_length=FRAME_LENGTH,
        frame_step=FRAME_STEP,
        fft_length=FRAME_LENGTH
    )
    spectrogram = tf.abs(stft)
    
    num_spectrogram_bins = FRAME_LENGTH // 2 + 1
    linear_to_mel_weight_matrix = tf.signal.linear_to_mel_weight_matrix(
        N_MELS, num_spectrogram_bins, SAMPLE_RATE, 80.0, 7600.0
    )
    mel_spectrogram = tf.tensordot(spectrogram, linear_to_mel_weight_matrix, 1)
    mel_spectrogram.set_shape(spectrogram.shape[:-1].concatenate(linear_to_mel_weight_matrix.shape[-1:]))
    
    log_mel = tf.math.log(mel_spectrogram + 1e-6)
    return log_mel.numpy()

def prepare_data():
    if not os.path.exists(DATASET_DIR):
        create_synthetic_dataset(DATASET_DIR)
        
    X, y = [], []
    print("Extracting Log-Mel Spectrogram features...")
    
    for label_idx, class_name in enumerate(CLASSES):
        class_dir = os.path.join(DATASET_DIR, class_name)
        wav_files = glob.glob(os.path.join(class_dir, "*.wav"))
        
        for wav_path in wav_files:
            audio = load_wav(wav_path)
            mel_spec = compute_mel_spectrogram(audio)
            X.append(mel_spec)
            y.append(label_idx)
            
    X = np.array(X, dtype=np.float32)
    y = np.array(y, dtype=np.int64)
    
    # Expand dimensions for 2D Conv (batch, time, mel, channels=1)
    X = np.expand_dims(X, axis=-1)
    
    return X, y

def build_cnn_model(input_shape, num_classes):
    inputs = keras.Input(shape=input_shape)
    
    x = layers.Conv2D(32, (3, 3), padding='same', activation='relu')(inputs)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling2D((2, 2))(x)
    x = layers.Dropout(0.2)(x)
    
    x = layers.Conv2D(64, (3, 3), padding='same', activation='relu')(x)
    x = layers.BatchNormalization()(x)
    x = layers.MaxPooling2D((2, 2))(x)
    x = layers.Dropout(0.3)(x)
    
    x = layers.Conv2D(128, (3, 3), padding='same', activation='relu')(x)
    x = layers.BatchNormalization()(x)
    x = layers.GlobalAveragePooling2D()(x)
    x = layers.Dropout(0.3)(x)
    
    x = layers.Dense(128, activation='relu')(x)
    outputs = layers.Dense(num_classes, activation='softmax')(x)
    
    model = keras.Model(inputs=inputs, outputs=outputs, name="OfflineSoundClassifier")
    return model

def main():
    X, y = prepare_data()
    print(f"Data prepared: X shape = {X.shape}, y shape = {y.shape}")
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    
    input_shape = X_train.shape[1:]
    num_classes = len(CLASSES)
    
    model = build_cnn_model(input_shape, num_classes)
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    model.summary()
    
    print("Training Lightweight CNN model...")
    callbacks = [
        keras.callbacks.EarlyStopping(monitor='val_accuracy', patience=15, restore_best_weights=True),
        keras.callbacks.ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=5)
    ]
    
    history = model.fit(
        X_train, y_train,
        validation_data=(X_test, y_test),
        epochs=30,
        batch_size=16,
        callbacks=callbacks
    )
    
    print("\n--- Model Evaluation on Test Set ---")
    test_loss, test_acc = model.evaluate(X_test, y_test, verbose=0)
    print(f"Test Accuracy: {test_acc * 100:.2f}% | Test Loss: {test_loss:.4f}")
    
    y_pred_probs = model.predict(X_test)
    y_pred = np.argmax(y_pred_probs, axis=1)
    
    print("\n--- Classification Report ---")
    print(classification_report(
        y_test, y_pred,
        labels=np.arange(len(CLASSES)),
        target_names=CLASSES,
        zero_division=0
    ))
    
    # Save Keras model
    model.save(MODEL_SAVE_PATH)
    print(f"Saved Keras model to '{MODEL_SAVE_PATH}'")
    
    # Save Labels JSON
    labels_dict = {i: name for i, name in enumerate(CLASSES)}
    with open(LABELS_SAVE_PATH, 'w') as f:
        json.dump(labels_dict, f, indent=2)
    print(f"Saved labels dictionary to '{LABELS_SAVE_PATH}'")
    
    # Convert to TFLite Float16
    print("\nConverting model to TensorFlow Lite (TFLite)...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    tflite_model = converter.convert()
    
    with open(TFLITE_SAVE_PATH, 'wb') as f:
        f.write(tflite_model)
    print(f"Successfully exported TFLite model to '{TFLITE_SAVE_PATH}' ({len(tflite_model)} bytes)")

    # Auto-copy to Flutter App and Live Python Detector
    import shutil
    targets = [
        "../flutter_mobile_app/assets/models",
        "../live-python-detector",
    ]
    for target in targets:
        if os.path.exists(target):
            shutil.copy(TFLITE_SAVE_PATH, os.path.join(target, "sound_model.tflite"))
            shutil.copy(LABELS_SAVE_PATH, os.path.join(target, "labels.json"))
            print(f"   🚀 Auto-deployed new model to '{target}'")

if __name__ == "__main__":
    main()
