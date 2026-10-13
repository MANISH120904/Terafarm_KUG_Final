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

### Cloud Storage (farm images)

As of 2024–2026, **Cloud Storage for Firebase requires the Blaze plan** (Spark API calls fail with 402/403 / object-not-found). Blaze still has a no-cost Storage tier if you stay under the free quota.

**Upload order in the app** (`FarmImageUploadService`):
1. **Firebase Storage** (if project is on Blaze)
2. **ImgBB** — free key from https://api.imgbb.com/ → set `IMGBB_API_KEY`
3. **Catbox** — no key (demo fallback; public host, not for production secrets)

Other alternatives you can switch to later: Cloudinary free tier, Supabase Storage, Uploadcare.

Location picker uses **OpenStreetMap + Photon/Nominatim** (no Google Maps key).

## Weather

Live weather uses **Open-Meteo** (`api.open-meteo.com`) — real API, **no key required**.
Used by Plant Care, Weather page, and WeatherProvider.

## Optional

- **Agmarknet / data.gov.in** (live mandi prices, no Render): set `AGMARKNET_API_KEY` from https://www.data.gov.in → Generate API Key. App calls `resource/9ef84268-d588-465a-a308-a864a43d0070` directly; falls back to local demo prices if the API fails.
- ImgBB: set `IMGBB_API_KEY` in `dart_defines.json` (recommended over Catbox).
- YouTube: set `YOUTUBE_API_KEY` in `dart_defines.json`.
- Google Maps native SDK (Terra Earth map widget): still needs `GOOGLE_MAPS_API_KEY` in `dart_defines.json` **and** `android/app/src/main/AndroidManifest.xml` (`com.google.android.geo.API_KEY`). Address pickers no longer require it.
