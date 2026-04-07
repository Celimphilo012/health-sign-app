# HealthSign 🤟

> Healthcare Sign Language Communication App

A Flutter application that enables communication between patients and healthcare workers using sign language, voice, and text.

## Features

- 🤟 Sign language gesture detection via camera
- 🎤 Speech-to-text for healthcare workers
- 🔊 Text-to-speech output
- 🔐 Firebase Authentication (Patient / Nurse roles)
- 💬 Real-time Firestore messaging
- 📱 Dark mode UI

## Tech Stack

- **Flutter** (latest stable)
- **Firebase** — Auth + Firestore
- **TensorFlow Lite** — Gesture recognition
- **speech_to_text** — Voice input
- **flutter_tts** — Voice output

## Setup

### Prerequisites

- Flutter SDK
- Android Studio
- Firebase project

### Installation

```bash
git clone https://github.com/Celimphilo012/health-sign-app.git
cd health-sign-app
flutter pub get
```

### Firebase Setup

1. Create a Firebase project at console.firebase.google.com
2. Enable Authentication (Email/Password)
3. Enable Firestore Database
4. Run `flutterfire configure`
5. This generates `lib/firebase_options.dart` and `android/app/google-services.json`

### Run

```bash
flutter run
```

## Project Structure

```
lib/
├── config/          # Theme & constants
├── models/          # Data models
├── providers/       # State management
├── screens/         # UI screens
│   ├── auth/        # Login, Register
│   ├── patient/     # Patient home
│   ├── nurse/       # Nurse home
│   └── shared/      # Splash, History
├── services/        # Firebase, Speech, Gesture
├── utils/           # Helpers, Validators
└── widgets/         # Reusable components
```

## Roles

| Role    | Features                                              |
| ------- | ----------------------------------------------------- |
| Patient | Camera gesture detection, Quick shortcuts, TTS output |
| Nurse   | Microphone STT, Text replies, Message history         |

## Final Year Project

Eswatini Medical Christian University — Computer Science — 2025
