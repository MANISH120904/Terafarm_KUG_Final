/// Reads secrets from compile-time defines — never hardcode real keys here.
///
/// Local setup:
/// 1. Copy `dart_defines.example.json` → `dart_defines.json` (gitignored)
/// 2. Paste keys into that file
/// 3. Run: `flutter run --dart-define-from-file=dart_defines.json`
///
/// See KEYS_NEEDED.md.
class ApiKeys {
  /// REQUIRED for TeraDoc / PlantCare / voice / scheme chatbot.
  /// Get free at: https://aistudio.google.com/apikey
  static const String gemini = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );

  /// Optional — market prices use local mock data by default.
  static const String agmarknet = String.fromEnvironment(
    'AGMARKNET_API_KEY',
    defaultValue: '',
  );

  /// Optional — Maps / geocoding (AndroidManifest still needs a Maps key for native SDK).
  static const String googleMaps = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  /// Optional — YouTube Data API.
  static const String youtube = String.fromEnvironment(
    'YOUTUBE_API_KEY',
    defaultValue: '',
  );

  static bool get hasGemini => gemini.isNotEmpty;

  static bool get hasGoogleMaps => googleMaps.isNotEmpty;

  static bool get hasYoutube => youtube.isNotEmpty;
}
