import os
import json
import numpy as np
import tensorflow as tf
from tensorflow.keras import layers, models
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder

FIXED_SEQUENCE_LENGTH = 30  # Pad or interpolate all gestures to 30 frames
FEATURE_DIM = 126            # 2 hands * 21 joints * 3 coords (x,y,z)

def pad_or_truncate(sequence, target_length=FIXED_SEQUENCE_LENGTH):
    """Ensure all sequence matrices have the exact same length."""
    num_frames = len(sequence)
    if num_frames == 0:
        return np.zeros((target_length, FEATURE_DIM))
    
    indices = np.linspace(0, num_frames - 1, target_length).astype(int)
    return np.array(sequence)[indices]

def load_dataset(json_dir):
    X, y = [], []
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
                except (OSError, json.JSONDecodeError) as error:
                    print(f"Skipping corrupted file {file_path}: {error}")
                    continue

            sequence_features = []
            for frame in data:
                frame_vec = np.zeros(FEATURE_DIM)
                hands = frame.get("hands", [])

                for hand_idx, hand in enumerate(hands[:2]):
                    landmarks = hand.get("landmarks", [])
                    for landmark in landmarks:
                        landmark_id = landmark["id"]
                        offset = (hand_idx * 21 + landmark_id) * 3
                        if offset + 2 < FEATURE_DIM:
                            frame_vec[offset] = landmark["x"]
                            frame_vec[offset + 1] = landmark["y"]
                            frame_vec[offset + 2] = landmark["z"]

                sequence_features.append(frame_vec)

            if sequence_features:
                padded_seq = pad_or_truncate(sequence_features)
                X.append(padded_seq)
                y.append(label)
        
    return np.array(X), np.array(y)

script_dir = os.path.dirname(os.path.abspath(__file__))
project_dir = os.path.dirname(script_dir)
landmarks_dir = os.path.join(project_dir, "dataset", "landmarks")
X, y = load_dataset(landmarks_dir)
if len(X) < 2:
    raise ValueError(
        f"Expected at least two extracted gesture samples under '{landmarks_dir}'."
    )

label_encoder = LabelEncoder()
y_encoded = label_encoder.fit_transform(y)
num_classes = len(np.unique(y_encoded))

X_train, X_test, y_train, y_test = train_test_split(
    X, y_encoded, test_size=0.2, random_state=42
)

# 2. Build LSTM Neural Network Model
model = models.Sequential([
    layers.Input(shape=(FIXED_SEQUENCE_LENGTH, FEATURE_DIM)),
    layers.LSTM(64, return_sequences=True),
    layers.Dropout(0.3),
    layers.LSTM(64),
    layers.Dropout(0.3),
    layers.Dense(32, activation='relu'),
    layers.Dense(num_classes, activation='softmax')
])

model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])
model.summary()

# 3. Train Model
model.fit(X_train, y_train, epochs=50, batch_size=8, validation_data=(X_test, y_test))

# 4. Save and Convert to TensorFlow Lite (.tflite) for Flutter
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

model_output_dir = os.path.join(project_dir, "assets", "models")
os.makedirs(model_output_dir, exist_ok=True)
model_output_path = os.path.join(model_output_dir, "sign_language_model.tflite")
with open(model_output_path, 'wb') as f:
    f.write(tflite_model)

print(f"Model successfully trained and saved to {model_output_path}!")