import 'dart:convert';

import 'package:http/http.dart' as http;

/// Live weather via Open-Meteo (no API key required).
/// Docs: https://open-meteo.com/
class LiveWeatherService {
  static Future<LiveWeather> byCoordinates({
    required double lat,
    required double lon,
  }) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'current': 'temperature_2m,relative_humidity_2m,weather_code',
      'timezone': 'auto',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw Exception('Weather API error ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final current = data['current'] as Map<String, dynamic>?;
    if (current == null) throw Exception('No current weather in response');

    final code = (current['weather_code'] as num?)?.toInt() ?? 0;
    return LiveWeather(
      temperatureC: (current['temperature_2m'] as num).toDouble(),
      humidity: (current['relative_humidity_2m'] as num).toInt(),
      condition: _conditionFromCode(code),
      latitude: lat,
      longitude: lon,
    );
  }

  /// Resolve city/place name then fetch current weather.
  static Future<LiveWeather> byPlaceName(String place) async {
    final q = place.trim();
    if (q.isEmpty) throw Exception('Enter a city or location');

    // Allow "lat,lon" pasted directly.
    final parts = q.split(',');
    if (parts.length == 2) {
      final lat = double.tryParse(parts[0].trim());
      final lon = double.tryParse(parts[1].trim());
      if (lat != null && lon != null) {
        return byCoordinates(lat: lat, lon: lon);
      }
    }

    final geoUri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q,
      'count': '1',
      'language': 'en',
      'format': 'json',
    });
    final geoRes = await http.get(geoUri).timeout(const Duration(seconds: 15));
    if (geoRes.statusCode != 200) {
      throw Exception('Location lookup failed ${geoRes.statusCode}');
    }
    final geo = jsonDecode(geoRes.body) as Map<String, dynamic>;
    final results = geo['results'] as List?;
    if (results == null || results.isEmpty) {
      throw Exception('Location not found: $q');
    }
    final first = results.first as Map<String, dynamic>;
    final lat = (first['latitude'] as num).toDouble();
    final lon = (first['longitude'] as num).toDouble();
    return byCoordinates(lat: lat, lon: lon);
  }

  static String _conditionFromCode(int code) {
    if (code == 0) return 'Clear';
    if (code == 1) return 'Mainly clear';
    if (code == 2) return 'Partly cloudy';
    if (code == 3) return 'Overcast';
    if (code == 45 || code == 48) return 'Fog';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 85 && code <= 86) return 'Snow showers';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Unknown';
  }
}

class LiveWeather {
  final double temperatureC;
  final int humidity;
  final String condition;
  final double? latitude;
  final double? longitude;

  const LiveWeather({
    required this.temperatureC,
    required this.humidity,
    required this.condition,
    this.latitude,
    this.longitude,
  });
}
