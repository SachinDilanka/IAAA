# AcousticAware: Real-Time Sound & Sinhala Emergency Keyword Awareness System for Deaf Individuals

[![GitHub Branch](https://img.shields.io/badge/Branch-Sound--Detection--Module-blue?logo=github)](https://github.com/SachinDilanka/IAAA/tree/Sound-Detection-Module)
[![Flutter](https://img.shields.io/badge/Flutter-3.2.0+-02569B?logo=flutter)](https://flutter.dev)
[![TensorFlow](https://img.shields.io/badge/TensorFlow-DNN%20(95.20%25)-FF6F00?logo=tensorflow)](https://tensorflow.org)

> **Official Repository Branch:**  
> 🔗 [https://github.com/SachinDilanka/IAAA/tree/Sound-Detection-Module](https://github.com/SachinDilanka/IAAA/tree/Sound-Detection-Module)

**AcousticAware** is an assistive acoustic awareness system designed for deaf and hard-of-hearing individuals. The system continuously monitors environmental sounds and spoken Sinhala speech, identifies critical emergency sounds and Sinhala distress keywords using a **Deep Neural Network (DNN)**, and delivers multi-sensory alerts via mobile visual displays, camera LED flash patterns, and phone haptic vibration feedback.

---

## 🏛️ System Architecture & Repository Structure

```
AcousticAware/
├── deaf_sound_alert_app/      # Cross-platform Flutter mobile application
│   ├── lib/ai/ & services/    # Live audio capture, DSP MFCC extraction & DNN inference
│   ├── lib/screens/           # Dashboard, Waveform Visualizer, Sound Config, History
│   └── assets/models/         # Quantized DNN model (sound_model.tflite) & DSP constants
│
├── model-training/            # Deep Neural Network (DNN) training & evaluation pipeline
│   ├── train_all_datasets.py  # Model architecture, training, and TFLite quantization script
│   ├── classification_report.txt # Official evaluation metrics (95.20% test accuracy)
│   ├── mean.npy / std.npy     # 40-MFCC feature standardization matrices
│   └── sound_model.tflite     # Trained 5-layer DNN model (~780 KB)
│
└── dataset/                   # Raw audio datasets (.wav) across 15 sound classes
```

---

## 🧠 Deep Neural Network (DNN) Model Architecture

The core sound recognition and keyword spotting pipeline uses a **5-Layer Deep Neural Network (DNN)** trained on **40 Mel-Frequency Cepstral Coefficients (MFCCs)**.

### 1. Acoustic Feature Extraction (DSP)
* **Sampling Rate:** 16,000 Hz (16 kHz audio)
* **Analysis Window:** 1.0 second (16,000 samples)
* **FFT Window Size:** 2,048 samples
* **Hop Length:** 512 samples (75% overlap)
* **Filterbank:** 128 triangular Mel-scale filters
* **Output Coefficients:** 40 MFCCs with Z-Score feature standardization:
  $$\hat{X} = \frac{X - \mu}{\sigma + \epsilon}$$

### 2. Deep Neural Network (DNN) Layers
```
Input Feature Vector [40 MFCCs]
       │
       ▼
[Dense Layer 1: 512 Units, ReLU Activation] ──► Dropout (0.25)
       │
       ▼
[Dense Layer 2: 256 Units, ReLU Activation] ──► Dropout (0.20)
       │
       ▼
[Dense Layer 3: 128 Units, ReLU Activation] ──► Dropout (0.15)
       │
       ▼
[Dense Layer 4:  64 Units, ReLU Activation]
       │
       ▼
[Output Dense:   14 Units, Softmax Multi-Class]
```

* **Total Trainable Parameters:** **194,382 parameters**
* **Optimizer:** Adam ($\text{learning rate} = 0.0008$)
* **Loss Function:** `sparse_categorical_crossentropy`
* **Batch Size:** 32 | **Max Epochs:** 60 with Early Stopping (`patience=12`)
* **Quantized Deployment Size:** **~780 KB** (`sound_model.tflite`)

### 3. Model Performance & Evaluation
Evaluated on **1,769 unseen test audio samples** (Stratified 85% Train / 15% Test split):
* **Overall Test Accuracy:** **95.20%**
* **Macro F1-Score:** **94.65%**
* **Weighted F1-Score:** **95.13%**

---

## 🔊 Supported Sound Classes & Priority Tiers

The system detects **14 distinct acoustic classes** divided into Sinhala Emergency Keywords, Environmental Hazards, and Ambient Background Noise:

| # | Class Name | Sound / Keyword Description | Category | Priority Tier | Alert Response |
|---|---|---|---|---|---|
| **00** | `udaw` | උදව් (Help / Distress Cry) | Sinhala Keyword | **CRITICAL** | Strobe Flashlight + Heavy Phone Vibration |
| **01** | `beeraganna` | බේරාගන්න (Save Me) | Sinhala Keyword | **CRITICAL** | Strobe Flashlight + Heavy Phone Vibration |
| **02** | `ginnak` | ගින්නක් (Fire Emergency) | Sinhala Keyword | **CRITICAL** | Strobe Flashlight + Heavy Phone Vibration |
| **03** | `anathurak` | අනතුරක් (Danger / Accident) | Sinhala Keyword | **HIGH** | Double Pulse Flash + Fast Phone Vibration |
| **04** | `karadarayak` | කරදරයක් (Trouble) | Sinhala Keyword | **MEDIUM** | Moderate Pulse Vibration |
| **05** | `balagena` | බලාගෙන (Watch Out) | Sinhala Keyword | **MEDIUM** | Moderate Pulse Vibration |
| **06** | `parissamin` | පරිස්සමින් (Be Careful) | Sinhala Keyword | **LOW** | Gentle Single Vibration |
| **07** | `ehata wenna` | එහාට වෙන්න (Move Aside) | Sinhala Keyword | **MEDIUM** | Moderate Pulse Vibration |
| **08** | `ambulance_siren` | Ambulance Siren | Environmental | **CRITICAL** | Strobe Flashlight + Heavy Phone Vibration |
| **09** | `fire_alarm` | Fire Truck / Fire Alarm | Environmental | **CRITICAL** | Strobe Flashlight + Heavy Phone Vibration |
| **10** | `vehicle_horn` | Car / Vehicle Horn | Environmental | **HIGH** | Double Pulse Flash + Fast Phone Vibration |
| **11** | `baby_crying` | Baby Crying | Environmental | **MEDIUM** | Moderate Double Pulse Vibration |
| **12** | `dog_barking` | Dog Barking | Environmental | **MEDIUM** | Moderate Pulse Vibration |
| **13** | `background_traffic` | Ambient Road / Traffic Noise | Environmental | **LOW** | Informational Screen Log |

---

## 📱 Mobile Application Features

* **Real-Time Sound Classification:** 1.0-second sliding audio window evaluated via on-device TFLite neural inference.
* **Continuous Audio Waveform Visualizer:** 40-band real-time audio spectrum responding continuously to ambient volume and pitch.
* **Instant Visual Alerts:** Heads-up alert banners displaying sound name, priority badge, and emergency category with zero latency.
* **Camera LED Strobe:** Synchronized rapid flashlight flashing patterns for deaf visual alerting in bright or noisy environments.
* **Haptic Vibration Engine:** Multi-tier vibration pulses calibrated to danger level (Critical, High, Medium, Low).
* **Detection History Log:** Persistent local storage tracking every detected alert with timestamps and confidence scores.
* **Customizable Sound Settings:** Ability to enable/disable specific sounds and adjust individual priority levels.

---

## 🚀 Getting Started

### 1. Cloning the Repository Branch
```bash
# Clone the repository and checkout the Sound-Detection-Module branch
git clone -b Sound-Detection-Module https://github.com/SachinDilanka/IAAA.git
cd IAAA
```

### 2. Prerequisites
* **Flutter SDK:** `>=3.2.0`
* **Android Device:** Android 8.0+ (API 26+)
* **Python:** `3.9+` (for model training only)

---

### 3. Building & Running the Mobile Application
```bash
# Navigate to the mobile app directory
cd deaf_sound_alert_app

# Install Flutter dependencies
flutter pub get

# Run on connected Android smartphone
flutter run
```

---

### 4. Training the Deep Neural Network (DNN) Model
To train or evaluate the 5-layer DNN on custom audio:
```bash
# Navigate to the model training directory
cd model-training

# Install Python audio & ML dependencies
pip install librosa tensorflow scikit-learn numpy

# Train DNN classifier & export quantized TFLite model
python train_all_datasets.py
```
Evaluation metrics, confusion matrices, and classification reports will output to `classification_report.txt`.
