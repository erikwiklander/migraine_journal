# Migraine Journal

A Flutter migraine tracking app for kids and caregivers.

## Features

- Home screen with a large `Log Migraine` action
- Migraine logging with:
  - emoji severity scale from `1-5`
  - trigger chips for weather, food, sleep, screens, and stress
  - auto-filled date and time
  - optional duration in minutes
- Local storage using `shared_preferences`
- History view for reviewing past entries
- Report view with date range filtering and a doctor-friendly summary that can be copied for sharing

## Project Structure

- `lib/main.dart`: current application UI, model, and local repository logic
- `test/widget_test.dart`: baseline widget test
- `ios/`, `android/`, `web/`: platform-specific Flutter scaffolding

## Getting Started

Install dependencies:

```bash
flutter pub get
```

Run analysis and tests:

```bash
flutter analyze
flutter test
```

Run locally in Chrome:

```bash
flutter run -d chrome
```

Build a production web bundle:

```bash
flutter build web
```

## Platform Notes

- Web is configured and working locally.
- iOS and Android source folders exist, but running on simulators or emulators requires full local platform setup.
- Check your environment with:

```bash
flutter doctor -v
flutter devices
```

## Next Steps

Useful follow-up work includes entry editing and deletion, native sharing for reports, and splitting `lib/main.dart` into smaller feature-focused files.
