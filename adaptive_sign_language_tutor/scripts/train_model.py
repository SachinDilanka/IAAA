import os
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

FIXED_SEQUENCE_LENGTH = 30  # Standardize all gesture clips to 30 frames
FEATURE_DIM = 126           # 2 hands * 21 landmarks * 3 coords (x, y, z)

def pad_or_truncate(sequence, target_length=FIXED_SEQUENCE_LENGTH):
    """Resample sequence matrix uniformly to exact target frame count."""
    num_frames = len(sequence)
    if num_frames == 0:
        return np.zeros((target_length, FEATURE_DIM))
    
    indices = np.linspace(0, num_frames - 1, target_length).astype(int)
    return np.array(sequence)[indices]

def load_dataset(json_dir):
    X, y = [], []
    if not os.path.exists(json_dir):
        print(f"Directory not found: {json_dir}")
        return np.array(X), np.array(y)

    print(f"Loading reference gesture files from: {json_dir}...")
    
    for root, _, files in os.walk(json_dir):
        for file in sorted(files):
            if not file.endswith(".json"):
                continue

            relative_parts = os.path.relpath(root, json_dir).split(os.sep)
            if len(relative_parts) < 2:
                print(f"Skipping JSON outside a gesture class folder: {file}")
                continue
            gesture_type, sample_name = relative_parts[-2:]
            label = sample_name
            for variant in ("_first_way", "_second_way"):
                if label.endswith(variant):
                    label = label[: -len(variant)]
                    break
            label = f"{gesture_type}_{label}"

            file_path = os.path.join(root, file)
            with open(file_path, "r", encoding="utf-8") as f:
                try:
                    data = json.load(f)
                except (OSError, json.JSONDecodeError) as e:
                    print(f"Skipping corrupted file {file_path}: {e}")
                    continue

            sequence_features = []
            for frame in data:
                frame_vec = np.zeros(FEATURE_DIM)
                hands = frame.get('hands', [])

                for hand_idx, hand in enumerate(hands[:2]):
                    landmarks = hand.get('landmarks', [])
                    for lm in landmarks:
                        lm_id = lm.get('id', 0)
                        offset = (hand_idx * 21 + lm_id) * 3
                        if offset + 2 < FEATURE_DIM:
                            frame_vec[offset] = lm.get('x', 0.0)
                            frame_vec[offset + 1] = lm.get('y', 0.0)
                            frame_vec[offset + 2] = lm.get('z', 0.0)

                sequence_features.append(frame_vec)

            if sequence_features:
                padded_seq = pad_or_truncate(sequence_features)
                X.append(padded_seq)
                y.append(label)
        
    return np.array(X), np.array(y)

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    gestures_dir = os.path.join(script_dir, "..", "dataset", "landmarks")
    output_dir = os.path.join(script_dir, "..", "assets", "models")
    
    os.makedirs(output_dir, exist_ok=True)

    X, y = load_dataset(gestures_dir)
    
    if len(X) == 0:
        print("No training data found. Please run scripts/batch_extract.py first!")
        return

    # Encode labels
    label_encoder = LabelEncoder()
    y_encoded = label_encoder.fit_transform(y)
    classes = list(label_encoder.classes_)
    num_classes = len(classes)
    
    print(f"\nFound {len(X)} samples across {num_classes} gesture classes: {classes}\n")

    # Split dataset
    test_size = 0.2 if len(X) >= 5 else 0.0
    if test_size > 0:
        X_train, X_test, y_train, y_test = train_test_split(
            X, y_encoded, test_size=test_size, random_state=42
        )
    else:
        X_train, y_train = X, y_encoded
        X_test, y_test = X, y_encoded

    # Build LSTM Model
    model = models.Sequential([
        layers.Input(shape=(FIXED_SEQUENCE_LENGTH, FEATURE_DIM)),
        layers.LSTM(64, return_sequences=True),
        layers.Dropout(0.2),
        layers.LSTM(64),
        layers.Dropout(0.2),
        layers.Dense(32, activation='relu'),
        layers.Dense(num_classes, activation='softmax')
    ])

    model.compile(
        optimizer='adam',
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    model.summary()

    # Train
    epochs = 30 if len(X) > 10 else 10
    model.fit(X_train, y_train, epochs=epochs, batch_size=4, validation_data=(X_test, y_test))

    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    # Enable Select TF ops if needed for LSTM operations
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,
        tf.lite.OpsSet.SELECT_TF_OPS
    ]
    converter._experimental_lower_tensor_list_ops = False

    tflite_model = converter.convert()

    tflite_path = os.path.join(output_dir, "sign_language_model.tflite")
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)

    print(f"\nModel successfully generated and saved to: {tflite_path}")
    print(f"Class labels order: {classes}")

if __name__ == "__main__":
    main()