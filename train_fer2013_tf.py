"""
FER-2013 Facial Emotion Recognition Model Training using TensorFlow / Keras
Dataset paths:
- Train: C:\\Users\\User\\Downloads\\train
- Test:  C:\\Users\\User\\Downloads\\test
"""

import os
import tensorflow as tf
from tensorflow.keras import layers, models

# 1. Dataset Paths
TRAIN_DIR = r"C:\Users\User\Downloads\train"
TEST_DIR = r"C:\Users\User\Downloads\test"
MODEL_SAVE_PATH = "fer2013_keras_model.h5"

IMG_HEIGHT = 48
IMG_WIDTH = 48
BATCH_SIZE = 64
EPOCHS = 15

# 2. Emotion to Sinhala Mapping
SINHALA_EMOTION_MAP = {
    "angry": {"sinhala": "කේන්තියි", "emoji": "😠", "advice": "සිනහවෙමින් සෙමින් අකුරු පුරුදු වෙමු! 😊"},
    "disgust": {"sinhala": "අකමැතියි", "emoji": "😣", "advice": "වෙනත් වචනයක් තෝරාගෙන සතුටින් කරමු! 🌸"},
    "fear": {"sinhala": "බයයි", "emoji": "😨", "advice": "බිය නැති කරමින් සෙමින් උත්සාහ කරමු! 🤗"},
    "happy": {"sinhala": "සතුටුයි", "emoji": "😊", "advice": "විශිෂ්ට සිනහවක්! දිගටම පුහුණු වෙමු! 🌟"},
    "neutral": {"sinhala": "සාමාන්‍යයි", "emoji": "😐", "advice": "මුඛය හොඳින් විවෘත කර ශබ්දය නඟන්න! 👍"},
    "sad": {"sinhala": "දුකයි", "emoji": "🥺", "advice": "කමක් නෑ, සෙමින් නැවත උත්සාහ කරමු! 💖"},
    "surprise": {"sinhala": "පුදුමයි", "emoji": "😮", "advice": "හොඳ අවධානයක්! දැන් ශබ්දය කියමු! 🎈"}
}

def build_model(num_classes=7):
    model = models.Sequential([
        # Data Augmentation & Normalization
        layers.Rescaling(1./255, input_shape=(IMG_HEIGHT, IMG_WIDTH, 1)),
        layers.RandomFlip("horizontal"),
        layers.RandomRotation(0.1),

        # Conv Block 1
        layers.Conv2D(32, (3, 3), padding='same', activation='relu'),
        layers.BatchNormalization(),
        layers.Conv2D(64, (3, 3), padding='same', activation='relu'),
        layers.BatchNormalization(),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),

        # Conv Block 2
        layers.Conv2D(128, (3, 3), padding='same', activation='relu'),
        layers.BatchNormalization(),
        layers.Conv2D(128, (3, 3), padding='same', activation='relu'),
        layers.BatchNormalization(),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),

        # Conv Block 3
        layers.Conv2D(256, (3, 3), padding='same', activation='relu'),
        layers.BatchNormalization(),
        layers.MaxPooling2D((2, 2)),
        layers.Dropout(0.25),

        # Dense Classifier
        layers.Flatten(),
        layers.Dense(512, activation='relu'),
        layers.BatchNormalization(),
        layers.Dropout(0.5),
        layers.Dense(num_classes, activation='softmax')
    ])

    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=0.001),
        loss='sparse_categorical_crossentropy',
        metrics=['accuracy']
    )
    return model

def main():
    print(f"Loading training data from {TRAIN_DIR} ...")
    train_ds = tf.keras.utils.image_dataset_from_directory(
        TRAIN_DIR,
        color_mode='grayscale',
        image_size=(IMG_HEIGHT, IMG_WIDTH),
        batch_size=BATCH_SIZE,
        shuffle=True
    )

    print(f"Loading test data from {TEST_DIR} ...")
    test_ds = tf.keras.utils.image_dataset_from_directory(
        TEST_DIR,
        color_mode='grayscale',
        image_size=(IMG_HEIGHT, IMG_WIDTH),
        batch_size=BATCH_SIZE,
        shuffle=False
    )

    class_names = train_ds.class_names
    print(f"Classes found ({len(class_names)}): {class_names}")

    # Optimize pipeline with prefetching
    train_ds = train_ds.cache().prefetch(buffer_size=tf.data.AUTOTUNE)
    test_ds = test_ds.cache().prefetch(buffer_size=tf.data.AUTOTUNE)

    model = build_model(num_classes=len(class_names))
    model.summary()

    callbacks = [
        tf.keras.callbacks.ModelCheckpoint(MODEL_SAVE_PATH, monitor='val_accuracy', save_best_only=True, verbose=1),
        tf.keras.callbacks.ReduceLROnPlateau(monitor='val_accuracy', factor=0.5, patience=2, verbose=1)
    ]

    print("\nStarting Training ...")
    model.fit(
        train_ds,
        validation_data=test_ds,
        epochs=EPOCHS,
        callbacks=callbacks
    )

    print(f"\nTraining completed! Best model saved to: {MODEL_SAVE_PATH}")

if __name__ == "__main__":
    main()
