# Keys setup (clones)

The app **compiles without secrets**. AI features need a Gemini key locally.

## Setup (each developer)

1. Copy `dart_defines.example.json` → `dart_defines.json`
2. Paste your Gemini key into `GEMINI_API_KEY`
3. Run:

```bash
flutter pub get
flutter run --dart-define-from-file=dart_defines.json
```

`dart_defines.json` is **gitignored**. Never commit it.

`lib/config/api_keys.dart` in the repo is **placeholders only** (reads from `--dart-define`).

## Firebase

`firebase_options.dart` + `android/app/google-services.json` are FlutterFire **client** config for project `terafarm-16cdd` (needed to run Auth/Firestore). They are not your Gemini key.

## Optional

- Maps / YouTube: set `GOOGLE_MAPS_API_KEY` in `dart_defines.json` (demo works without them; those screens soft-fail).
