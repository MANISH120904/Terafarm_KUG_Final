import 'api_keys.dart';

class YouTubeConfig {
  /// From `--dart-define-from-file=dart_defines.json` → `YOUTUBE_API_KEY`
  static const String apiKey = ApiKeys.youtube;
  static const String baseUrl = 'https://www.googleapis.com/youtube/v3';
}
