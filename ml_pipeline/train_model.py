import os
import json
import numpy as np
import tensorflow as tf
from sklearn.model_selection import train_test_split
from dataset_loader import load_dataset, CLASS_MAPPING

def build_model(input_shape, num_classes):
    inputs = tf.keras.Input(shape=input_shape)
    
    x = tf.keras.layers.Conv2D(32, (3, 3), padding='same', activation='relu')(inputs)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.MaxPooling2D((2, 2))(x)
    
    x = tf.keras.layers.Conv2D(64, (3, 3), padding='same', activation='relu')(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.MaxPooling2D((2, 2))(x)
    
    x = tf.keras.layers.Conv2D(128, (3, 3), padding='same', activation='relu')(x)
    x = tf.keras.layers.BatchNormalization()(x)
    x = tf.keras.layers.GlobalAveragePooling2D()(x)
    
    x = tf.keras.layers.Dense(128, activation='relu')(x)
    x = tf.keras.layers.Dropout(0.3)(x)
    
    outputs = tf.keras.layers.Dense(num_classes, activation='softmax')(x)
    
    model = tf.keras.Model(inputs=inputs, outputs=outputs, name="DeafSoundClassifier")
    return model

def main():
    dataset_dir = "d:\\Audio\\dataset"
    models_dir = "d:\\Audio\\ml_pipeline\\models"
    os.makedirs(models_dir, exist_ok=True)
    
    X, y, labels = load_dataset(dataset_dir)
    
    X_train, X_val, y_train, y_val = train_test_split(X, y, test_size=0.2, random_state=42, stratify=y)
    
    print(f"Train shape: {X_train.shape}, Val shape: {X_val.shape}")
    
    input_shape = X_train.shape[1:]
    num_classes = len(labels)
    
    model = build_model(input_shape, num_classes)
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    
    model.summary()
    
    callbacks = [
        tf.keras.callbacks.EarlyStopping(monitor='val_loss', patience=7, restore_best_weights=True),
        tf.keras.callbacks.ReduceLROnPlateau(monitor='val_loss', factor=0.5, patience=3)
    ]
    
    history = model.fit(
        X_train, y_train,
        validation_data=(X_val, y_val),
        epochs=25,
        batch_size=32,
        callbacks=callbacks
    )
    
    val_loss, val_acc = model.evaluate(X_val, y_val)
    print(f"\nFinal Validation Accuracy: {val_acc * 100:.2f}%")
    
    # Save Keras Model
    keras_model_path = os.path.join(models_dir, "sound_classifier.h5")
    model.save(keras_model_path)
    print(f"Keras model saved to {keras_model_path}")
    
    # Convert to TFLite
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()
    
    tflite_path = os.path.join(models_dir, "sound_classifier.tflite")
    with open(tflite_path, "wb") as f:
        f.write(tflite_model)
    print(f"TFLite model saved to {tflite_path} (Size: {len(tflite_model) / 1024:.2f} KB)")
    
    # Save Labels & Priority metadata JSON
    labels_file = os.path.join(models_dir, "labels.txt")
    metadata_file = os.path.join(models_dir, "sound_metadata.json")
    
    label_info = []
    with open(labels_file, "w") as f:
        for idx, key in enumerate(labels):
            display_name, priority = CLASS_MAPPING[key]
            f.write(f"{display_name}\n")
            label_info.append({
                "id": idx,
                "key": key,
                "name": display_name,
                "priority": priority
            })
            
    with open(metadata_file, "w") as f:
        json.dump(label_info, f, indent=2)
        
    print(f"Labels saved to {labels_file}")
    print(f"Metadata saved to {metadata_file}")

if __name__ == "__main__":
    main()

