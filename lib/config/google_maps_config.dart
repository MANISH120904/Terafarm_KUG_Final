import 'api_keys.dart';

/// Google Maps API Configuration
class GoogleMapsConfig {
  /// From `--dart-define-from-file=dart_defines.json` → `GOOGLE_MAPS_API_KEY`
  static const String apiKey = ApiKeys.googleMaps;

  static const String geocodingApiUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  static const String placesApiUrl = 'https://maps.googleapis.com/maps/api/place';

  static const String directionsApiUrl =
      'https://maps.googleapis.com/maps/api/directions/json';
}
