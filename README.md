# Little Voices: Emotion-Adaptive Sinhala Speech Therapy System for Children



**Little Voices** is an intelligent, emotion-adaptive Sinhala speech therapy mobile and web application designed for children aged 4–10 with speech delays and articulation disorders. Integrating real-time **Affective Computing** and **Speech Articulation Analysis**, the system non-intrusively tracks a child's facial emotional state (happiness, frustration, fatigue) and vocal patterns using a **Hybrid Convolutional Neural Network - Deep Neural Network (CNN-DNN)** architecture. The system dynamically personalizes therapy exercise difficulty, provides visual biofeedback via an integrated camera mirror, and reinforces learning through the interactive mascot **"පැංචා" (Pancha)** with authentic spoken Sinhala audio feedback.

---

## 🏛️ System Architecture & Repository Structure

```
sinhala_speech_therapy/
├── flutter_app/                       # Cross-platform Flutter client (Android & Web)
│   ├── lib/
│   │   ├── features/practice/         # Letter & Word Practice modules, tools panel
│   │   ├── emotion_camera_web.dart    # Live camera mirror & periodic 5-second frame streaming
│   │   └── l10n/                      # ARB localization files (Sinhala / English)
│   ├── assets/
│   │   ├── models/                    # Quantized TFLite model (emotion_model.tflite & labels.txt)
│   │   └── audio/                     # Pre-recorded clinical Sinhala audio files (.mp3)
│   └── test/                          # Unit and widget test suite
│
├── backend/                           # FastAPI REST API & AI Inference Engine
│   ├── ml/
│   │   ├── emotion_classifier.py      # OpenCV face crop, tensor normalization & TFLite inference
│   │   └── train_emotion_model.py     # CNN-DNN model training pipeline & TFLite quantization
│   ├── main.py                        # FastAPI routes, CORS middleware & static web host
│   ├── seed_data.py                   # Clinical Sinhala articulation dataset & exercise seeder
│   └── therapy.db                     # SQLite database (curriculum, progress & child profile)
│
└── dataset/                           # FER facial emotion dataset (35,000+ images) & audio samples

```

---

## 🧠 Deep Learning Architecture: Hybrid CNN-DNN

The core intelligence combines spatial computer vision for affective tracking and acoustic feature modeling using a **Custom Hybrid CNN-DNN Architecture**. The trained network is exported into an edge-optimized **TensorFlow Lite (`.tflite`)** model for low-latency client and backend inference.

### 1. Data Preprocessing & Feature Extraction Pipeline

* **Facial Input Dimensions:** $48 \times 48 \times 1$ Grayscale image tensors (single-channel).


* **Pixel Normalization (Min-Max):**

$$\hat{X} = \frac{X - X_{min}}{X_{max} - X_{min}} = \frac{X}{255.0}$$


* **Acoustic Input (Speech Articulation):** Real-time audio signals converted into visual **Mel-Spectrograms** (16 kHz sampling rate, 2,048 FFT window, 512 hop length, 128 Mel frequency bands) to extract formant transitions ($F_1, F_2$) and acoustic patterns.


* **Face Localization:** Automated square center-crop geometry with a $10\%$ adaptive bounding margin fallback when Haar Cascade detection is bypassed.

### 2. Neural Network Layer Pipeline

```
Input Tensor [48 × 48 × 1]
       │
       ▼
[Conv2D Block 1: 32 Filters (3×3), ReLU] ──► BatchNormalization ──► MaxPooling2D (2×2) ──► Dropout (0.25)
       │
       ▼
[Conv2D Block 2: 64 Filters (3×3), ReLU] ──► BatchNormalization ──► MaxPooling2D (2×2) ──► Dropout (0.25)
       │
       ▼
[Conv2D Block 3: 128 Filters (3×3), ReLU] ──► BatchNormalization ──► MaxPooling2D (2×2) ──► Dropout (0.25)
       │
       ▼
[Flatten Layer: 2D Spatial Features to 1D Vector]
       │
       ▼
[Dense Layer 1 (DNN): 256 Units, ReLU] ──► BatchNormalization ──► Dropout (0.50)
       │
       ▼
[Dense Layer 2 (DNN): 128 Units, ReLU] ──► BatchNormalization ──► Dropout (0.50)
       │
       ▼
[Output Dense: Softmax Multi-Class Classification]

```

* **Feature Extraction (CNN Part):** `Conv2D`, `BatchNormalization`, and `MaxPooling2D` layers capture subtle facial curves, expressions, and acoustic spectrogram patterns.


* **Classification Head (DNN Part):** Fully connected `Dense` layers evaluate extracted features to produce multi-class probability distributions.


* **Softmax Activation Formula:**

$$P(y = i \mid z) = \frac{e^{z_i - \max(z)}}{\sum_{j=1}^{C} e^{z_j - \max(z)}}$$


* **Loss Function:** `categorical_crossentropy` (evaluating multi-class cross-entropy loss):

$$\mathcal{L} = -\sum_{i=1}^{C} y_i \log(\hat{y}_i)$$


* **Optimizer:** Adam (Adaptive Moment Estimation)
* **Training Schedule:** 30 Epochs executed on Google Colab with an NVIDIA T4 GPU accelerator, regulated by `EarlyStopping` (patience = 5) and `ReduceLROnPlateau`.


* **Quantization & Deployment:** Model converted using `TFLiteConverter` with dynamic range quantization, resulting in the lightweight deployment artifact `emotion_model.tflite`.



---

## 🎯 Clinical Sinhala Articulation Curriculum

The curriculum is structured according to **Van Riper’s Articulation Hierarchy** (Sound $\rightarrow$ Syllable $\rightarrow$ Word). Seeded via `backend/seed_data.py`, it addresses the primary pediatric speech sound disorders identified in Sri Lankan clinical speech-language therapy:

| Phonological Error | Clinical Description | Target Word Exercises | Progression Stage |
| --- | --- | --- | --- |
| **Stopping** | Substitution of fricatives with plosive stops (e.g., /s/ $\rightarrow$ /t/)

 | *පූසා* $\rightarrow$ *පූතා*, *සපත්තු* $\rightarrow$ *තපත්තු*

 | Level 1: Beginner |
| **Fronting** | Replacing posterior velars with anterior alveolars (e.g., /k/, /g/ $\rightarrow$ /t/, /d/)

 | *කහ* $\rightarrow$ *තහ*, *ගස* $\rightarrow$ *දස*

 | Level 1: Beginner |
| **Lateralization** | Distortion/substitution of liquids (e.g., /r/ $\rightarrow$ /l/)

 | *රජ* $\rightarrow$ *ලජ*, *යතුර* $\rightarrow$ *යතුල*, *තාරාවා*

 | Level 2: Intermediate |
| **Backing & Metathesis** | Reversals or backward substitutions in compound consonant structures

 | *තාත්තා*, *පුතා*, *කලිසම*

 | Level 3: Advanced |

---

## 📱 Core System Capabilities

* **Real-Time Affective Emotion Detection:** Captures web/mobile camera frames every 5 seconds, categorizing emotional states (Positive, Neutral, Negative) to dynamically adapt exercise difficulty.


* **Visual Biofeedback (Camera Mirror):** Displays an on-screen mirror feed allowing children to observe and adjust lip, mouth, and tongue movements during articulation practice.


* **Auditory Biofeedback:** Pre-recorded authentic Sinhala acoustic samples (`.mp3`) paired with automatic congratulatory vocal prompts (*"සුපිරි ඔයා හොඳට කිව්වා!"*) for pre-literate learners.


* **Interactive Lion Mascot ("පැංචා"):** Child-centric animated mascot that provides engaging visual reactions to reduce therapy fatigue.


* **Offline-Resilient Architecture:** Integrated local fallback data layer in Flutter ensuring uninterrupted practice during server disconnects or unstable home internet.


* **Privacy-Preserving Edge Inference:** Live webcam frames are processed strictly in volatile memory and discarded immediately without persistent image or video logging.



---

## 🚀 Getting Started

### 1. Prerequisites

* **Flutter SDK:** `>=3.2.0`
* **Dart SDK:** `>=3.0.0`
* **Python:** `3.10+`
* **JDK:** Version 17
* **Google Chrome** (for Web testing) or **Android Device / Emulator** (API 26+)

---

### 2. Backend Setup & Execution

Open a terminal at the project root:

```powershell
# 1. Activate the Python virtual environment
.\.venv\Scripts\Activate.ps1

# 2. Install backend dependencies
pip install -r requirements.txt

# 3. Seed database with clinical Sinhala curriculum
python backend/seed_data.py

# 4. Start the FastAPI server on port 8000
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000

```

Interactive API documentation will be available at: `[http://127.0.0.1:8000/docs](http://127.0.0.1:8000/docs)`

---

### 3. Frontend Mobile & Web Execution

Open a second terminal:

```powershell
# Navigate to the Flutter project
cd flutter_app

# Fetch required packages
flutter pub get

# Run on Google Chrome (Web Client)
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000

# Or run on an Android Emulator
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000

```

---

### 4. Verification & Testing

```powershell
cd flutter_app
flutter analyze
flutter test

```
