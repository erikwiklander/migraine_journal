# Repository Guidelines

## Project Structure & Module Organization
This repository is a Flutter app for migraine tracking. Main application code lives in `lib/`, currently centered in `lib/main.dart`. Widget tests live in `test/`, with the baseline app test in `test/widget_test.dart`. Platform folders are `ios/`, `android/`, and `web/`. Build outputs such as `build/` and tool state such as `.dart_tool/` are generated and should not be edited manually.

## Build, Test, and Development Commands
- `flutter pub get`: install or update Dart and Flutter dependencies.
- `flutter analyze`: run static analysis and lint checks.
- `flutter test`: run widget and unit tests.
- `flutter run -d chrome`: launch the app in Chrome for local development.
- `flutter build web`: create a production web build in `build/web/`.
- `flutter run -d <device>`: run on a specific simulator, emulator, or device once configured.

## Coding Style & Naming Conventions
Follow Flutter and Dart conventions with 2-space indentation. Use `UpperCamelCase` for classes and widgets, `lowerCamelCase` for methods and variables, and `snake_case` for file names when new files are added. Prefer small, focused widgets and immutable data models where practical. Run `dart format lib test` before committing. Use `flutter analyze` as the lint gate.

## Testing Guidelines
Use `flutter_test` for widget and unit coverage. Name tests to describe expected behavior, for example: `home screen shows the migraine logger entry point`. Add tests for new UI flows, persistence behavior, and report generation logic when those areas change. Run `flutter test` locally before opening a pull request.

## Commit & Pull Request Guidelines
Current history uses short, imperative commit messages such as `Initial commit`. Continue with concise messages like `Add report date range filter` or `Fix local entry sorting`. For pull requests, include:
- a short summary of user-visible changes
- test results, for example `flutter analyze` and `flutter test`
- screenshots or screen recordings for UI changes
- linked issue or task reference when applicable

## Configuration Notes
Local storage currently uses `shared_preferences`, so avoid committing generated user data or secrets. For simulator or emulator work, verify platform tooling first with `flutter doctor -v`.
