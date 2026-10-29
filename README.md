# AssistComm (IAAA) - AI Communication Assistant

AssistComm is an accessible, bilingual (Sinhala & English) location-aware communication assistant designed specifically for deaf, hard-of-hearing, and non-verbal individuals in Sri Lanka. It pairs real-time GPS location detection with context-aware communication phrases tailored for venues including Hospitals, Banks, Restaurants, Supermarkets, and everyday general situations.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Project Architecture & Repository Structure](#project-architecture--repository-structure)
- [Technologies Used](#technologies-used)
- [Prerequisites](#prerequisites)
- [Installation & Setup](#installation--setup)
  - [1. Backend Setup](#1-backend-setup)
  - [2. Database Seeding](#2-database-seeding)
  - [3. Frontend Setup (Flutter)](#3-frontend-setup-flutter)
- [Running the Application](#running-the-application)
  - [Running the Flask Backend / Web Interface](#running-the-flask-backend--web-interface)
  - [Running the Flutter Mobile/Web Application](#running-the-flutter-mobileweb-application)
  - [Running the Web Wrapper](#running-the-web-wrapper)
- [Running Tests](#running-tests)
  - [Backend Tests](#backend-tests)
  - [Frontend Tests](#frontend-tests)
- [API Reference](#api-reference)

---

## Overview

Individuals with hearing or speech impairments often face critical communication barriers in public venues (such as medical check-ins, banking transactions, supermarket inquiries, or dining). AssistComm bridges this gap by automatically detecting nearby Sri Lankan venues via GPS coordinates (or manual selection) and presenting structured, dual-language communication phrases. Selected phrases can be displayed on a fullscreen high-contrast billboard card with an invert/flip feature for easy viewing by counter staff or communication partners.

---

## Key Features

- **GPS Location Detection & Proximity Matching**:
  - Automatically identifies nearby venues within radius threshold using latitude and longitude.
  - Built-in dataset covering major Sri Lankan POIs:
    - 20 Hospitals across Sri Lanka
    - 20 Banks (major commercial and state banks)
    - 20 Restaurants
    - 20 Supermarkets (Cargills Food City, Keells Super, Arpico Supercentre, SPAR, Laugfs Super)
  - Offline local proximity fallback when backend network access is unavailable.

- **Bilingual Categorized Phrase Bank (Sinhala & English)**:
  - Curated phrases organized by venue and situation (Emergency, Doctor Consultations, Pharmacy, Account Inquiries, Checkout, Counter Assistance, Ordering, etc.).
  - Templated phrases with slot filling placeholders.

- **Fullscreen Billboard Card Display**:
  - High-contrast, large-format text presentation optimized for legibility.
  - 180° rotation / flip toggle so users can invert the card toward the person across the desk or counter.
  - Screen wake-lock support via `wakelock_plus` to prevent device screen timeout during communication.

- **Manual Venue Selection & Interactive Map**:
  - Interactive map integration for manual pin selection and visual inspection of nearby venues.
  - GPS simulator modal for testing different venue locations.

- **Custom Typing & AI Suggestion**:
  - Free-form text input with Sinhala/English typing capability.
  - Backend suggestion endpoint integration (`/api/suggest`) connecting to ML phrase suggestion services.

---

## Project Architecture & Repository Structure

```
research/
├── app/                      # Primary Flask application package
│   ├── models/               # SQLAlchemy ORM models (LocationType, Category, Message)
│   ├── routes/               # Route blueprints (views.py for HTML, api.py for REST API)
│   ├── services/             # Core business logic (geo_service.py, message_service.py)
│   ├── static/               # Frontend web assets (CSS design system, JS, icons)
│   └── templates/            # Jinja2 HTML templates (mobile.html, card_view.html, index.html)
├── backend/                  # Alternative backend directory with dedicated run and seed scripts
│   ├── app/                  # Backend application package
│   ├── run.py                # Backend entry point running on 0.0.0.0:5000
│   └── seed.py               # Backend database seeder
├── frontend/                 # Cross-platform Flutter client application
│   ├── lib/
│   │   ├── config/           # Centralized network config (AppConfig.backendBaseUrl)
│   │   ├── controllers/      # State controllers (VenueController)
│   │   ├── data/             # Offline venue datasets & communication phrases
│   │   ├── models/           # Dart data models
│   │   ├── providers/        # InheritedWidget state providers (VenueProvider)
│   │   ├── screens/          # UI screens (HomeScreen, CategoryDetailScreen)
│   │   ├── services/         # API, geolocator, and suggestion client services
│   │   └── widgets/          # UI components (billboard cards, dialogs, drawers)
│   └── test/                 # Flutter unit and widget test suite
├── web_wrapper/              # Lightweight Flutter companion wrapper with WebView
│   └── lib/main.dart         # Embeds Flask /mobile web interface via webview_flutter
├── tests/                    # Python unit and integration test suite
├── test_app.py               # Standalone Python integration test runner
├── run.py                    # Root Flask launch script (binds to 127.0.0.1:5000)
├── seed.py                   # Root database population script
├── requirements.txt          # Python package dependencies
├── DESIGN_SPEC.md            # Detailed UI/UX architecture and design specification
└── README.md                 # Project documentation
```

---

## Technologies Used

- **Backend**:
  - Python 3.10+
  - Flask (>= 3.0.0)
  - Flask-SQLAlchemy (>= 3.1.1)
  - SQLite (database)
  - python-dotenv (>= 1.0.0)
  - requests (>= 2.31.0)
  - Jinja2 & Vanilla CSS Design System

- **Frontend (Mobile & Web)**:
  - Dart & Flutter SDK (^3.13.0)
  - `geolocator` (^14.0.1) - Device GPS location services
  - `http` (^1.2.1) - REST API communication
  - `wakelock_plus` (^1.8.1) - Keeps the screen active during billboard mode
  - `cupertino_icons` (^1.0.8)

- **Companion Wrapper**:
  - `webview_flutter`

---

## Prerequisites

- **Python**: Version 3.10 or higher with `pip`
- **Flutter SDK**: Version 3.13.0 or higher
- **Web Browser or Mobile Emulator/Device**: Chrome (for web testing), Android Emulator/Device, or iOS Simulator

---

## Installation & Setup

### 1. Backend Setup

1. Open a terminal in the project root (`research`):
2. Create and activate a Python virtual environment:
   - **Windows (PowerShell)**:
     ```powershell
     python -m venv venv
     .\venv\Scripts\Activate.ps1
     ```
   - **macOS / Linux**:
     ```bash
     python3 -m venv venv
     source venv/bin/activate
     ```
3. Install required Python packages:
   ```bash
   pip install -r requirements.txt
   ```

### 2. Database Seeding

Initialize the SQLite database (`instance/comms_app.db`) and populate default categories and phrases:

```bash
python seed.py
```

### 3. Frontend Setup (Flutter)

1. Navigate to the `frontend` directory:
   ```bash
   cd frontend
   ```
2. Fetch Flutter package dependencies:
   ```bash
   flutter pub get
   ```
3. *(Optional)* Configure the backend server address:
   Update the backend endpoint in `frontend/lib/config/app_config.dart`:
   - Local testing / Web / Desktop: `http://127.0.0.1:5000`
   - Android Emulator: `http://10.0.2.2:5000`
   - Physical device over Wi-Fi: `http://<YOUR_LOCAL_IP>:5000`

---

## Running the Application

### Running the Flask Backend / Web Interface

From the repository root:

- **Local Development (localhost)**:
  ```bash
  python run.py
  ```
  Accessible in your browser at `http://127.0.0.1:5000`.

- **Network-Accessible Backend (0.0.0.0)**:
  ```bash
  python backend/run.py
  ```
  Accessible across the local network at `http://<HOST_IP>:5000`.

Available Web Views:
- Main Dashboard: `http://127.0.0.1:5000/`
- Mobile-First Web Experience: `http://127.0.0.1:5000/mobile`
- Venue Direct Views: `http://127.0.0.1:5000/mobile/hospital`, `http://127.0.0.1:5000/mobile/bank`, `http://127.0.0.1:5000/mobile/restaurant`, `http://127.0.0.1:5000/mobile/supermarket`
- Billboard Card Display: `http://127.0.0.1:5000/show?text=...&icon=...`

### Running the Flutter Mobile/Web Application

From the `frontend` directory:

- **Run in Google Chrome (Web)**:
  ```bash
  cd frontend
  flutter run -d chrome
  ```

- **Run on a Connected Mobile Device / Emulator**:
  ```bash
  cd frontend
  flutter run
  ```

### Running the Web Wrapper

If using the lightweight WebView wrapper companion:

```bash
cd web_wrapper
flutter pub get
flutter run
```

---

## Running Tests

### Backend Tests

Run the standalone integration test suite:
```bash
python -m unittest test_app.py
```

Run the complete test suite under `tests/`:
```bash
python -m unittest discover tests
```

### Frontend Tests

Run the Flutter unit and widget tests:
```bash
cd frontend
flutter test
```

---

## API Reference

The Flask backend exposes the following RESTful endpoints:

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/locations` | List all available location types and categories |
| `GET` | `/api/locations/<slug>` | Get location details with categories and phrases |
| `GET` | `/api/location-presets` | Retrieve predefined presets and categories |
| `GET` | `/api/location-presets/<slug>` | Retrieve preset details for a venue slug |
| `POST` | `/api/detect-location` | Match GPS `{ "lat": float, "lon": float }` to nearest Sri Lankan venue |
| `GET` | `/api/sri-lanka-hospitals` | List predefined Sri Lankan hospitals (supports query params `lat`, `lon`) |
| `POST` | `/api/select-hospital` | Manually select a hospital venue by ID, name, or coordinates |
| `GET` | `/api/sri-lanka-banks` | List predefined Sri Lankan banks |
| `POST` | `/api/select-bank` | Manually select a bank venue |
| `GET` | `/api/sri-lanka-restaurants` | List predefined Sri Lankan restaurants |
| `POST` | `/api/select-restaurant` | Manually select a restaurant venue |
| `GET` | `/api/sri-lanka-supermarkets`| List predefined Sri Lankan supermarkets |
| `POST` | `/api/select-supermarket` | Manually select a supermarket venue |
| `POST` | `/api/suggest` | Forward message queries to the ML phrase suggestion service |