# AcousticAware: Offline Real-Time Sound & Sinhala Emergency Keyword Awareness System for Deaf Individuals

**AcousticAware** is a comprehensive, multi-platform assistive ecosystem designed for deaf and hard-of-hearing individuals. It provides 100% offline, real-time awareness of critical environmental sounds and spoken Sinhala emergency keywords through tactile skin haptics, dual-language visual guidance, and wearable smartwatch alert delivery.

---

## 🏛️ System Architecture & Repository Modules

The workspace is organized into four clean, modular, production-ready components:

```
sound-alert-system/
├── flutter_mobile_app/      # Cross-platform Flutter mobile & web application
├── live-python-detector/    # Python real-time microphone classifier with terminal HUD
├── model-training/          # Audio dataset synthesis & deep learning training pipeline
└── esp32-firmware/          # TTGO T-Wristband ESP32 BLE vibration & TFT firmware
```

### 1. 📱 `flutter_mobile_app/` (Flutter Mobile & Web App)
- **Real-Time Classification Engine**: Sliding audio window inference with offline confidence filtering.
- **Side Overlay Alert System**: Responsive floating side toast with urgency glow, countdown progress bar, and swipe-to-dismiss gesture.
- **Interactive AI Avatar**: Visual state machine with dual Sinhala and English action guidance banners.
- **Smartwatch Notification Gateway**: Transmits mirrored emergency alerts to the **Yesido IO39** smartwatch via system notification channels and companion apps (e.g., XO FIT).
- **Haptic Vibration Engine**: Multi-tiered vibration patterns (High, Medium, Low urgency).
- **Offline History Storage**: Persistent local database using `shared_preferences`.

### 2. 🐍 `live-python-detector/` (Python Microphone Classifier)
- Direct microphone audio stream processing via `sounddevice` and `librosa`.
- 40-element MFCC feature extraction and normalization (`mean.npy`, `std.npy`).
- Real-time ANSI terminal HUD dashboard with live volume metering, dominant pitch analysis, and horizontal probability bars.

### 3. 🧠 `model-training/` (Deep Learning Pipeline)
- `prepare_dataset.py`: Synthesizes audio samples across 16 emergency sound and Sinhala keyword classes.
- `train_multibranch_model.py`: 2D CNN model trained on 64-band Log-Mel spectrograms, exported to Float16 `.tflite` and `labels.json`.
- `train_kws.py`: Dense neural classifier exporting `.keras`, `.tflite`, and embedded C++ headers (`sound_model.h`) for microcontrollers.

### 4. ⌚ `esp32-firmware/` (TTGO T-Wristband Wearable Firmware)
- Standalone C++/Arduino firmware for LilyGO TTGO T-Wristband (ESP32).
- BLE GATT Server receiver (`SERVICE_UUID: 4fafc201-1fb5-459e-8fcc-c5c9c331914b`).
- 100% PWM vibration motor drive (duty cycle 255/255) executing continuous incoming call ringing cadence (1500ms ON / 50ms OFF).
- ST7735 TFT color display rendering warning banners.

---

## 🔊 Supported Sound Classes & Sinhala Keywords

| Category | Class / Keyword | Sinhala Translation | Urgency Level | Tactile Action |
|---|---|---|---|---|
| **Emergency Sound** | `fire_alarm` / `ginna` | ගින්නක් / ගින්න | **HIGH** | Continuous Call-Style Pulse |
| **Emergency Sound** | `ambulance_siren` | ගිලන් රථ අනතුරු සංඥාව | **HIGH** | Continuous Call-Style Pulse |
| **Emergency Sound** | `screaming` | කෑගැසීමක් | **HIGH** | Continuous Call-Style Pulse |
| **Emergency Sound** | `vehicle_horn` | රථවාහන හෝන් ශබ්දය | **HIGH** | Strong Warning Vibration |
| **Sinhala Keyword** | `udaw` / `udaw_karanna` | උදව් / උදව් කරන්න | **HIGH** | Continuous Call-Style Pulse |
| **Sinhala Keyword** | `anathurak` | අනතුරක් | **HIGH** | Continuous Call-Style Pulse |
| **Sinhala Keyword** | `nawaththanna` | නවත්තන්න | **HIGH** | Continuous Call-Style Pulse |
| **Sinhala Keyword** | `beeraganna` | බේරගන්න | **HIGH** | Continuous Call-Style Pulse |
| **Environmental** | `baby_crying` | ළදරුවෙකුගේ හැඬීම | **MEDIUM** | Double Warning Pulse |
| **Sinhala Keyword** | `parissamin` | පරිස්සමින් | **MEDIUM** | Double Warning Pulse |
| **Sinhala Keyword** | `karadarayak` | කරදරයක් | **MEDIUM** | Double Warning Pulse |
| **Sinhala Keyword** | `ehata_wenna` | එහාට වෙන්න | **MEDIUM** | Double Warning Pulse |
| **Sinhala Keyword** | `balagena` | බලාගෙන | **MEDIUM** | Double Warning Pulse |
| **Environmental** | `dog_barking` | බල්ලෙකුගේ බිරුම | **LOW** | Single Gentle Pulse |
| **Negative Class** | `background_other` | සාමාන්‍ය පසුබිම් ශබ්ද | **NONE** | No Vibration (Standby) |

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK**: `>=3.0.0`
- **Python**: `3.9+` with `tensorflow`, `numpy`, `librosa`, `sounddevice`
- **Arduino IDE / PlatformIO**: For ESP32 firmware compilation

---

### Running the Flutter Mobile App

#### Option A: On Android Phone (USB / Wireless Debugging)
```bash
cd flutter_mobile_app
flutter run
```

#### Option B: In Chrome Browser (Quick Testing)
```bash
cd flutter_mobile_app
flutter run -d chrome
```

---

### Running the Python Live Classifier
```bash
cd live-python-detector
python live_audio_classifier.py
```

---

### Training the Machine Learning Models
```bash
cd model-training
pip install -r requirements.txt
python prepare_dataset.py
python train_multibranch_model.py
```

