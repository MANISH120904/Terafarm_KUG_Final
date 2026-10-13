# TeraFarm / AgriCoder — Full Hackathon Rescue Report

**Date:** 13 October 2026  
**Repo:** `AgriCoder` (Git branch `main` → `origin/main`)  
**Product names in code:** TeraFarm (pub package) · AgriGuru (UI docs) · Android id `com.example.terafarm2`  
**Firebase project (wired):** `terafarmsih` (legacy migration source: `terafarm-3ab30`)  
**Constraint:** External accounts (Firebase / GCP / paid APIs) depleted or deleted · **$0 budget** · submit tomorrow  

---

## Executive verdict

The app is a real Flutter product that previously worked. The **spine is Firebase Auth + Firestore**. Almost every product feature assumes that spine is alive. Gemini powers the AI USP (TeraDoc / TeraCare / voice / schemes). Everything else (Cloud Run, Render, Vertex RAG, Maps, weather, YouTube, FCM server push, Unity AR, Web3) is either already soft-failing or can be stubbed.

**Realistic path:** recreate **Firebase Spark (free)** + one **Google AI Studio Gemini key (free)** · fix compile bugs · stub dead backends · **do not** redeploy Cloud Functions / Cloud Run / Unity tonight.

**Estimated rescue time:** 4–6 hours for a judge-demoable Android build.

---

## 1. What this repo is

### Product (from README)

Urban farming + collaborative neighborhood marketplace for balcony/terrace growers. USP is three AI systems:

| Feature | Intent |
|---------|--------|
| **TeraDoc** | Plant disease / health from photos |
| **TeraRecommend** | Crop / grow recommendations |
| **TeraCare** | Personalized chatbot / plant care |
| **Marketplace** | Pool & sell produce locally |
| **Gamification** | Leaderboard, badges, XP |
| **Shop / forum / weather** | Supporting features |

### Architecture (not a formal monorepo)

```
[Flutter app: lib/]
  ├─ Auth (Firebase) → Landing → MainNavigation
  │    Home/Seller | Marketplace | AI hub | Community
  ├─ AI: TeraDoc / PlantCare / Recommend / Scheme chatbot / Voice
  ├─ Maps, Weather, YouTube, Offline toolkit, Gamification
  └─ FCM weather notifications
        │
        ├─ Firebase (terafarmsih): Auth, Firestore, Storage, Functions, FCM
        │     └─ Vertex embeddings in Functions for RAG
        ├─ Gemini / Google AI (client-side hardcoded keys)
        ├─ OpenWeather / Visual Crossing / Maps / YouTube / Mapbox / ORS
        └─ Flask backend (crop rules + Agmarknet) → Render / Cloud Run

[Sidecars]
  functions/          Firebase Cloud Functions (Node 18)
  backend/            Flask + Dockerfile
  tools/migration/    Old→new Firebase migration scripts
  offline_models/     TensorFlow SavedModel weights
  Assets/ + Unity     Incomplete AR experiment (Library/Temp caches)
```

### Tech stack

| Layer | Tech |
|-------|------|
| Client | Flutter / Dart SDK `>=3.3.0 <4.0.0`, Provider, Material, i18n (10 locales) |
| BaaS | Firebase Auth, Firestore, Storage, Cloud Functions, FCM |
| AI | `google_generative_ai` (Gemini), intended TFLite on-device |
| Backend | Flask (`backend/app.py`), Docker → Cloud Run / Render |
| Maps | Google Maps, flutter_map, Mapbox, OpenRouteService, Geolocator |
| Weather | Visual Crossing, OpenWeatherMap |
| Misc | YouTube Data API, speech_to_text / flutter_tts, web3dart (Sepolia), WebView AR |

### How to run (undocumented in README; inferred)

```bash
# Flutter
flutter pub get
flutter run

# Functions (not needed for $0 demo)
cd functions && npm install && npm run serve

# Flask (optional local stub)
cd backend && pip install -r requirements.txt && python app.py
```

---

## 2. Repo health / structural issues

| Issue | Severity | Notes |
|-------|----------|-------|
| Identity fragmentation | Low | AgriCoder / TeraFarm / AgriGuru / `com.example.terafarm2` |
| `lib/main.dart` corrupted imports | **Critical** | Duplicate import block; mangled `notification_manager` import line |
| No setup / CONTRIBUTING docs | Medium | README is product brief only |
| Empty `storage.rules` | High if using Storage | File exists but empty |
| Empty `firestore.indexes.json` | Medium | May be fine for small demo |
| Missing `firestore.rules` | High | Relying on default / console rules |
| No `GoogleService-Info.plist` | Medium | iOS/macOS Firebase incomplete — **demo on Android** |
| TFLite binaries missing | **High** | Only `.meta` + `plant_disease_labels.txt` remain under `assets/` |
| Unity tree in same repo | Noise | `Library/`, `Temp/`, `Assets/Scripts/` — ignore for Flutter demo |
| Backup / churn files | Noise | `*_backup.dart`, `index-backup*.js`, etc. |
| Secrets hardcoded | Security | API keys + service account JSON in repo |
| `tools/migration/old-firebase.json` | **Danger** | Full service-account private key for `terafarm-3ab30` |

### Confirmed compile hotspot: `lib/main.dart`

Lines 1–11 are valid imports; lines 12–22 are a **corrupted duplicate** of the same block (line 12 concatenates the notification import with a second `firebase_core` import). This must be cleaned before `flutter run`.

### Confirmed asset gap: on-device ML

Present:

- `assets/plant_disease_labels.txt`
- `assets/plant_disease_model.tflite.meta` (Unity-style meta only)
- `assets/models/*.tflite.meta` (meta only)

**Missing:** actual `.tflite` weight files. Offline diagnosis cannot run as designed. Use Gemini vision for the disease demo.

---

## 3. Feature map (Flutter screens)

Major pages under `lib/` (non-exhaustive):

| Area | Pages / services |
|------|------------------|
| Auth | `landing_page`, `login_page`, `create_account_page`, `google_auth_service`, `dev_auth_helper` |
| Nav / home | `main_navigation`, `home_page`, `seller_page`, `dashboard_page`, `menu_page` |
| Marketplace | `list_farm_page`, `edit_farm_page`, `product_page`, `cart_page`, `order_list_page`, `buyers_page`, `shop_page` |
| AI hub | `ai_page`, `TeraDoc_page`, `PlantCare_page`, `plant_disease_detection_page`, `recommendation_ai_page`, voice assistance |
| Schemes | `scheme_chatbot_service`, `subsidies_page`, `enhanced_ai_service` |
| Weather | `weather_page`, `weather_provider`, `Cloud Notification/*` |
| Community | `Community_page`, `forum_page`, `colab_page`, `leaderboard_page` |
| Crop / market data | `crop_suggestion_page`, `market_price_page`, `plant_growth_analysis_page` |
| Offline | `offline_toolkit_page`, `offline_diagnosis_page`, `offline_calculator_page`, `gemma_ai_service` (simulated) |
| AR | `unity_ar_launcher_page`, `agri_ar_*`, WebView model viewer |
| Other | `qr_scanner_page` (web3), maps pickers, account/profile |

**Bottom nav (from docs):** Home/Seller · Marketplace · AI · Community

---

## 4. External dependency audit

### 4.1 Firebase (HARD SPINE)

| Service | Where | Powers | Fail mode | $0 fix |
|---------|-------|--------|-----------|--------|
| **Auth** (email + Google) | `login_page`, `create_account_page`, `google_auth_service`, most features via `currentUser` | Identity for market/forum/orders | Hard-fail for real flows; app shell can still launch | New Spark project; prefer email/password; expand `DevAuthHelper` if needed |
| **Firestore** | Widespread (`users`, `farms`, `orders`, `plants`, `groups`, `channels`, shop collections, FCM tokens, weather docs) | Core product data | Hard-fail | Spark + seed JSON/docs |
| **Storage** | Profile/farm images, forum media, AR uploads, scheme PDFs | Uploads | Hard for uploads; soft for some chat paths | Use `assets/sample_farm.png`; skip uploads in demo |
| **Cloud Functions** | Client: `scheme_chatbot_service.dart` → `us-central1-terafarmsih.cloudfunctions.net/*`; weather test → `asia-south1-...` | RAG schemes, farmer profile, weather FCM | RAG quality drops; client has fallbacks | **Do not deploy**; use local scheme + Gemini |
| **FCM** | `weather_notification_service`, `fcm_token_manager`, Cloud Notification | Push weather alerts | Soft (app runs) | Local notifications only; FCM server key is placeholder `YOUR_FCM_SERVER_KEY_HERE` |
| **Hosting / Analytics / RTDB** | Config crumbs only | Not used meaningfully in `lib/` | N/A | Ignore |

**Active Functions exports** (`functions/index.js`):  
`processPDFForRAGEnhanced`, `processPDFForRAG`, `personalizedRAGQuery`, `ragQuery`, `ragQueryWorking`, `manageFarmerProfile`, `scheduledWeatherForecast`, `sendManualWeatherForecast`, `addTestFCMTokens`

**Bug:** Client calls **`getSchemeData`**, which is **not** exported from current `index.js` (lives in backups / `index_simple.js`). Already broken even if project were alive.

**Config files:**

| File | Status |
|------|--------|
| `firebase.json` | Present (Functions + FlutterFire map only) |
| `.firebaserc` | Default `terafarmsih` |
| `lib/firebase_options.dart` | Present (all platforms) |
| `android/app/google-services.json` | Present |
| `ios/.../GoogleService-Info.plist` | **Missing** |
| `storage.rules` | Empty |
| `firestore.indexes.json` | Empty |
| `functions/.env` | `GEMINI_API_KEY` |
| `tools/migration/old-firebase.json` | **Dangerous SA key** |
| `tools/migration/new-firebase.json` | SA for `terafarmsih` |

### 4.2 Google Cloud / Gemini

| Service | Where | Fail | $0 fix |
|---------|-------|------|--------|
| **Gemini** (`gemini-1.5-flash`, `2.0-flash`, `2.0-flash-exp`) | Voice, PlantCare, TeraDoc, disease page, scheme chatbot, enhanced AI, Functions `.env` | AI screens fail without key; enhanced AI has text fallbacks | One AI Studio free key; consolidate all sites |
| **Vertex AI embeddings** | `functions/index.js` (`gemini-embedding-001`, `PROJECT_ID=terafarmsih`) | RAG only | Skip Functions |
| **Cloud Natural Language** | `enhanced_ai_service.dart` | Soft | Skip / stub |
| **Cloud Run crop API** | `crop_suggestion_page.dart` → `terafarm-backend-178459710700.asia-south1.run.app` | Page errors | Inline `recommend_crops()` from Flask |
| **Cloud Run growth API** | `plant_growth_analysis_page.dart` → `tera-242561185203.asia-south1.run.app` | Page errors | Stub or hide page |
| **Maps / Geocoding / Places** | `google_maps_config.dart`, `address_map_picker.dart`, AndroidManifest | Maps blank | OSM via `flutter_map` |
| **YouTube Data API** | `youtube_config.dart`, `youtube_service.dart` | Empty list (soft) | Hardcode 1–2 video IDs |

### 4.3 Other APIs

| Service | Where | Fail | $0 fix |
|---------|-------|------|--------|
| **Render** `terafarm-backend.onrender.com` | `market_price_page.dart` | Error UI | Static mandi JSON |
| **Agmarknet / data.gov.in** | `backend/app.py` | Backend errors | Mock; free tier if Flask run locally |
| **Visual Crossing** | Weather provider / pages | Soft (empty weather) | Open-Meteo (no key) or static JSON |
| **OpenWeatherMap** | `weather_service.dart` (One Call often paid) | Soft | Same |
| **Miswired weather keys** | Cloud Notification uses Gemini-looking key as weather key | Already broken | Mock |
| **Mapbox** | `choose_exact_location.dart` (broken `YOUR_MAPBOX_ACCESS_TOKEN` template also present) | Tiles fail | OSM tiles |
| **OpenRouteService** | `location.dart` | Address string fails | Hardcode city |
| **QuickNode Sepolia + contract** | `qr_scanner_page.dart` | Soft (one page) | Fake tx hash |
| **UPI deep link** | `cart_page.dart` | Needs seller `upi_id` | Snackbar “Order placed” |
| **OpenAI / Anthropic** | — | Not used | — |
| **Stripe / Razorpay / SMS / email** | — | Not used | — |

### 4.4 Fail vs fallback summary

| Dependency | Hard-fail without it? | Existing fallback? |
|------------|----------------------|--------------------|
| Firebase Auth + Firestore | **Yes** for core product | Partial offline only in `DevAuthHelper` |
| Firebase Storage | Uploads / AR yes | Scheme metadata fallback in places |
| Cloud Functions / Vertex | Shell no; RAG yes | Scheme list + AI text fallbacks |
| Gemini | AI screens yes | Enhanced AI + gemma simulate |
| Weather | No | Silent fail |
| Maps / Mapbox / ORS | Location UX only | Can hardcode coords |
| YouTube | No | Empty list |
| Render / Cloud Run / Agmarknet | Those pages only | Easy to stub |
| FCM server | No | Local notifications dependency already present |
| Web3 | QR page only | Mock |
| UPI | Payment step only | Order can still write Firestore |

---

## 5. Dead / fragile URLs inventory

| URL / endpoint | Used by |
|----------------|---------|
| `https://terafarm-backend.onrender.com` | Market prices |
| `https://terafarm-backend-178459710700.asia-south1.run.app/suggest_crop` | Crop suggestion |
| `https://tera-242561185203.asia-south1.run.app/` | Plant growth analysis |
| `https://us-central1-terafarmsih.cloudfunctions.net/getSchemeData` | Scheme chatbot (**function missing in active index**) |
| `https://us-central1-terafarmsih.cloudfunctions.net/ragQuery` | Scheme RAG |
| `https://us-central1-terafarmsih.cloudfunctions.net/personalizedRAGQuery` | Personalized RAG |
| `https://us-central1-terafarmsih.cloudfunctions.net/manageFarmerProfile` | Farmer profile |
| `https://asia-south1-terafarmsih.cloudfunctions.net/sendManualWeatherForecast` | Weather test |
| `https://your-server.com/models/...` | Offline model download placeholder |

---

## 6. Secrets & security notes (for submission zip)

**Do not paste live keys into this report.** They currently live in source as hardcoded `AIza…` / weather / Mapbox / Agmarknet / QuickNode strings across:

- `lib/config/google_maps_config.dart`, `youtube_config.dart`
- `lib/voice_assistance*.dart`, `PlantCare_page.dart`, `TeraDoc_page.dart`, `plant_disease_detection_page.dart`
- `lib/services/scheme_chatbot_service.dart`, `enhanced_ai_service.dart`
- `lib/services/weather_service.dart`, weather provider / Cloud Notification files
- `android/app/src/main/AndroidManifest.xml` (Maps meta-data)
- `backend/app.py` (Agmarknet)
- `functions/.env`
- `tools/migration/old-firebase.json` / `new-firebase.json` (service accounts)

**Actions before public zip:**

1. Delete or `.gitignore` migration SA JSON files  
2. Rotate any keys you still control  
3. Prefer `--dart-define` / local untracked config for the demo key  

---

## 7. Priority fix list (ordered for tomorrow)

### P0 — Must fix or nothing demos

| # | Item | Effort | Action |
|---|------|--------|--------|
| 1 | Firebase project dead | 1–2h | Create free Spark project → enable Auth (email) + Firestore → `flutterfire configure` → update `firebase_options.dart` + `google-services.json` → seed 2–3 users/farms/orders |
| 2 | Gemini keys dead | 30m | Create AI Studio key → replace all Gemini call sites with one constant |
| 3 | `main.dart` corruption | 5m | Remove duplicate imports; fix notification import |

### P1 — Demo-breaking pages if judges click them

| # | Item | Effort | Action |
|---|------|--------|--------|
| 4 | TFLite missing | skip rebuild | Demo disease with Gemini image analysis; hide offline diagnosis or show “model pack not bundled” |
| 5 | Crop / market / growth URLs dead | 1h | Port `recommend_crops()` into Dart; static price table; hide or stub growth page |
| 6 | Cloud Functions / Vertex | skip | Rely on client scheme fallbacks + Gemini |

### P2 — Soft fails that look broken on stage

| # | Item | Effort | Action |
|---|------|--------|--------|
| 7 | Maps / Mapbox / ORS | 45m | `flutter_map` + `tile.openstreetmap.org`; hardcode demo lat/lng |
| 8 | Weather | 30m | Open-Meteo or static JSON in `WeatherProvider` |

### P3 — Cut from demo script

| # | Item | Action |
|---|------|--------|
| 9 | FCM push / scheduled Functions | Don’t demo; local notifications optional |
| 10 | YouTube | Hardcode IDs or skip |
| 11 | Web3 QR | Mock success |
| 12 | Unity AR / model upload | Don’t open; remove from pitch if asked “future work” |
| 13 | Google Sign-In SHA-1 pain | Skip; use email/password |

---

## 8. Recommended tonight execution plan

### Hour 0–1: Firebase resurrect

1. Firebase console → new project (Spark)  
2. Enable Email/Password Auth  
3. Create Firestore (test mode for 24h is fine for hackathon; lock down after)  
4. `dart pub global activate flutterfire_cli` → `flutterfire configure`  
5. Seed collections:

```text
users/{uid}        displayName, email, role
farms/{id}         title, price, location, imageUrl, ownerId
orders/{id}        buyerId, items, status
```

6. Create test account matching `DevAuthHelper` defaults if useful: `test@terafarm.dev` / `test123456`

### Hour 1–2: Compile + Gemini

1. Fix `lib/main.dart`  
2. `flutter pub get` → `flutter run` on Android device/emulator  
3. Add single `lib/config/api_keys.dart` (gitignored or dart-define) and point Gemini callers at it  

### Hour 2–4: Stub dead backends

1. Inline crop suggestion from `backend/app.py` `recommend_crops()`  
2. Replace market price HTTP with local JSON (10 commodities)  
3. Point scheme chatbot to skip Functions (or catch errors and use existing fallbacks — already partially there)  
4. WeatherProvider → static / Open-Meteo  

### Hour 4–5: Demo polish

1. Seed marketplace listings with `assets/sample_farm.png`  
2. Walk the judge script once end-to-end  
3. Hide or comment nav entries for AR / QR chain / broken growth page  
4. Remove SA JSON from any zip you submit  

### Hour 5–6: Buffer

- Google Sign-In only if time  
- Screenshots / video backup if live device fails  

---

## 9. Judge demo script (suggested)

1. **Landing → login** with seeded email account  
2. **Home / farms** — show 2–3 listings (collaborative market story)  
3. **AI hub → TeraDoc** — upload leaf photo → Gemini diagnosis + care tip  
4. **PlantCare / voice (optional)** — short Q&A  
5. **Scheme chatbot** — ask about PM-Kisan / subsidy; show multilingual fallback if needed  
6. **Marketplace** — add produce → cart → place order (skip real UPI; show confirmation)  
7. **Crop suggestion** — local rules by state/budget  
8. **If asked about offline ML / AR / blockchain:** “roadmap; cloud AI path is what we shipped for reliability”

---

## 10. What NOT to spend time on

- Redeploying Vertex RAG / PDF pipeline  
- Paying for OpenWeather One Call / Maps billing  
- Fixing Unity ARCore scripts  
- Restoring missing `.tflite` from scratch (days of ML work)  
- iOS Firebase plist  
- Perfect Firestore security rules (demo first)  
- Cleaning Unity `Library/` / `Temp/` for the build (exclude from zip instead)  

---

## 11. Flask backend reference (easy to port)

`backend/app.py` is **rule-based**, not ML:

- `/suggest_crop` — state + land_size + budget heuristics  
- `/market_price*` — proxies Agmarknet  
- `/status` — health  

Dependencies (`requirements.txt`): Flask, flask-cors, requests, gunicorn only.  
Running locally is free; shipping static Dart equivalents is faster for the demo.

---

## 12. Cloud Functions reference (skip for demo)

Package: `agriglu-functions-rag-simple` · Node 18 · uses `@google-cloud/aiplatform`, firebase-admin, pdf-parse.  

Worth knowing for Q&A: the design was PDF scheme RAG with Vertex embeddings + Gemini answers + scheduled weather FCM. Client already degrades without it.

---

## 13. Cost reality check

| Item | Cost for weekend demo |
|------|------------------------|
| Firebase Spark (Auth + Firestore + Storage light) | **$0** (stay under free quotas) |
| Google AI Studio Gemini | **$0** free tier (watch rate limits during demo) |
| Open-Meteo | **$0** |
| OSM tiles | **$0** (be polite with traffic; demo only) |
| data.gov.in Agmarknet | **$0** if used |
| Cloud Run / Vertex / Maps billing / Render paid wake | **Avoid** |

---

## 14. Success criteria for submission

- [ ] App launches on Android without red-screen  
- [ ] Login works  
- [ ] At least one farm listing visible  
- [ ] TeraDoc returns a diagnosis from a photo  
- [ ] One marketplace order writes to Firestore  
- [ ] Crop suggest or market prices show *something* (even mocked)  
- [ ] Pitch can explain AI + collaborative market without living backends  
- [ ] No service-account private keys in the submitted archive  

---

## 15. Immediate next engineering tasks (when ready to code)

1. Fix `lib/main.dart` imports  
2. Add mock/local crop + market services and wire pages  
3. Consolidate Gemini API key access  
4. Document exact Firebase setup steps in a short `SETUP_HACKATHON.md` after project is created  
5. Seed script or console checklist for demo data  

---

*Report generated from static repository analysis of AgriCoder. External account liveness was inferred from depleted/deleted account context and dead URL patterns; confirm Firebase/Gemini with a live smoke test after recreation.*
