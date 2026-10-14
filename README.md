# Little Voices — Sinhala Speech Therapy

A bilingual Flutter application for children aged 4–10 to practise Sinhala letters, pronunciation, and step-by-step word building. Profile setup, guidance, and progress management are designed for a parent or guardian.

## Architecture

- **Flutter client:** `flutter_app/` — Android and web UI built with Flutter/Dart
- **API:** `backend/` — FastAPI and SQLAlchemy
- **Database:** SQLite, created and seeded automatically
- **State and routing:** Provider and GoRouter
- **Localization:** Flutter ARB resources in `flutter_app/lib/l10n/`

The Flutter client uses the existing backend APIs and database. There is no authentication feature in the original application, so no authentication flow is included in the migration.

## Features

- English and Sinhala UI with a persisted language preference
- Eight Sinhala letter exercises and twenty word-building exercises
- Animated child-friendly therapy guide
- Sinhala text-to-speech and Sinhala speech recognition
- Camera mirror and backend emotion analysis
- Attempt, star, and progress tracking using the existing API
- Parent/guardian profile setup and guidance
- Centered, localized confirmation and error dialogs
- Responsive navigation for phones, tablets, and web

## Development environment (without Android Studio)

This project uses VS Code and Android command-line tools only.

Required tools:

- Flutter SDK and Dart SDK
- VS Code with `Dart-Code.dart-code` and `Dart-Code.flutter`
- JDK 17
- Android SDK command-line tools
- Android SDK Platform 36 and Build Tools 36

Verify the environment:

```powershell
flutter doctor -v
code --list-extensions
```

`flutter doctor` may report Visual Studio as missing. Visual Studio is only required for a Windows desktop build; it is not required for this project's Android and web targets.

## Start the application

The FastAPI backend and Flutter client must both be running during development.

### 1. Open the project in VS Code

```powershell
cd C:\Users\User\Downloads\sinhala_speech_therapy
code .
```

### 2. Start the backend

Open the first VS Code terminal from the repository root:

```powershell
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

Keep this terminal open. Verify that the backend is running by opening:

```text
http://127.0.0.1:8000/docs
```

If PowerShell prevents virtual-environment activation, run this once in the current terminal and try again:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
```

### 3. Start Flutter in Chrome

Open a second VS Code terminal:

```powershell
cd flutter_app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

Flutter will launch the application in Chrome. Keep both terminals open while using the application.

### Quick Windows start

You can start the backend and Chrome client together by double-clicking:

```text
run_app.bat
```

### Start on an Android emulator

Start the emulator using Android command-line tools, confirm that Flutter can see it, and then launch the app:

```powershell
cd flutter_app
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

`10.0.2.2` is the Android emulator address for the backend running on the development computer.

### Start on a physical Android device

1. Enable **Developer options** and **USB debugging** on the device.
2. Connect it to the computer using USB.
3. Ensure the phone and computer are connected to the same network.
4. Find the computer's IPv4 address:

   ```powershell
   ipconfig
   ```

5. Confirm that Flutter detects the device and replace `YOUR_COMPUTER_IP` below with that IPv4 address:

   ```powershell
   cd flutter_app
   flutter devices
   flutter run --dart-define=API_BASE_URL=http://YOUR_COMPUTER_IP:8000
   ```

For example:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

The included `.vscode/launch.json` also contains Chrome and Android launch configurations.

### Troubleshoot data-loading problems

1. Confirm that the backend terminal is still running.
2. Open the health endpoint:

   ```text
   http://127.0.0.1:8000/api/health
   ```

   A healthy response reports `"status": "ok"`, at least one child, and 28 exercises.

3. For Chrome, use `http://127.0.0.1:8000` as `API_BASE_URL`.
4. For the Android emulator, use `http://10.0.2.2:8000`.
5. For a physical device, use the computer's LAN IPv4 address—not `127.0.0.1` or `10.0.2.2`.
6. If port 8000 is already occupied, stop the older backend process before starting a new one.

The SQLite path is anchored to the repository root, so the backend always reads the same `therapy.db` file regardless of which directory it is started from.

### Troubleshoot missing sound

- Increase the device's **media volume** and confirm it is not muted.
- Stop and restart Flutter after updating the application so the bundled audio assets are loaded.
- In Chrome, allow sound for the site and select a listen button after the page opens; browsers can block audio before the first user interaction.
- If an older version is cached, close the application tab, start it again with `run_app.bat`, and hard-refresh Chrome with `Ctrl+F5`.
- The app includes offline Sinhala recordings for every seeded letter, syllable, and word. It only uses the device's text-to-speech engine for text that has no bundled recording.
- On Android, installing Google Speech Services and Sinhala voice data is still recommended as a fallback for additional text.

## Build and verify

```powershell
cd flutter_app
flutter gen-l10n
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build web --release --dart-define=API_BASE_URL=http://127.0.0.1:8000
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

After `flutter build web`, FastAPI automatically serves `flutter_app/build/web`. During development, run Flutter directly from VS Code or with `flutter run`.

## Localization

Translations are maintained in:

- `flutter_app/lib/l10n/app_en.arb`
- `flutter_app/lib/l10n/app_si.arb`

Run `flutter gen-l10n` after editing either resource. Sinhala letters and words remain in Sinhala in both interface languages because they are the learning targets.

## Emotion-model training

Model-training utilities remain available and are separate from the Flutter client:

```powershell
python backend/ml/train_emotion_model.py --train_dir "C:\Users\User\Downloads\train" --test_dir "C:\Users\User\Downloads\test"
```
