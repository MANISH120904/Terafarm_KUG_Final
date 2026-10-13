import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/api_keys.dart';

/// Automated Weather Forecast FCM Sender
/// Sends actual weather forecasts via FCM every 1 minute
class ScheduledWeatherFCM {
  static final ScheduledWeatherFCM _instance = ScheduledWeatherFCM._internal();
  factory ScheduledWeatherFCM() => _instance;
  ScheduledWeatherFCM._internal();

  Timer? _forecastTimer;
  bool _isRunning = false;

  // Firebase Cloud Messaging Server Key (Legacy)
  // Get from: Firebase Console > Project Settings > Cloud Messaging > Server Key
  static const String _fcmServerKey = 'YOUR_FCM_SERVER_KEY_HERE';
  
  // Weather API Configuration
  static const String _weatherApiKey = 'YOUR_API_KEY_HERE';
  static const String _geocodingApiKey = 'YOUR_API_KEY_HERE';

  /// Start sending weather forecasts every 1 minute
  Future<void> startAutomatedForecasts() async {
    if (_isRunning) {
      print('⚠️ Automated forecasts already running');
      return;
    }

    _isRunning = true;
    print('🚀 Starting automated weather forecast FCM sender (1-minute interval)');

    // Send immediately
    await _sendWeatherForecastFCM();

    // Schedule every 1 minute
    _forecastTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _sendWeatherForecastFCM();
    });
  }

  /// Stop automated forecasts
  void stopAutomatedForecasts() {
    _forecastTimer?.cancel();
    _forecastTimer = null;
    _isRunning = false;
    print('🛑 Stopped automated weather forecast FCM sender');
  }

  /// Send weather forecast via FCM to all subscribed devices
  Future<void> _sendWeatherForecastFCM() async {
    try {
      print('\n📡 [${DateTime.now()}] Fetching weather for FCM broadcast...');

      // Get current location
      final position = await _getCurrentLocation();
      if (position == null) {
        print('❌ Failed to get location');
        return;
      }

      // Fetch weather data
      final weatherData = await _fetchWeatherData(position.latitude, position.longitude);
      if (weatherData == null) {
        print('❌ Failed to fetch weather data');
        return;
      }

      // Get location name
      final locationName = await _getLocationName(position.latitude, position.longitude);

      // Parse weather data
      final weather = _parseWeatherData(weatherData);
      
      // Create forecast message
      final forecast = _createForecastMessage(weather, locationName);

      // Send via FCM to topic subscribers
      await _sendFCMToTopic(
        topic: 'weather_forecast',
        title: '🌤️ Weather Update - ${locationName}',
        body: forecast,
        data: {
          'type': 'weather_forecast',
          'temperature': weather['temperature'].toString(),
          'condition': weather['condition'].toString(),
          'location': locationName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // Also send to weather_alerts topic if conditions warrant
      if (_shouldAlert(weather)) {
        await _sendFCMToTopic(
          topic: 'weather_alerts',
          title: '⚠️ Weather Alert - ${locationName}',
          body: _createAlertMessage(weather, locationName),
          data: {
            'type': 'weather_alert',
            'alert_type': _getAlertType(weather),
            'temperature': weather['temperature'].toString(),
            'condition': weather['condition'].toString(),
            'location': locationName,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      // Log to Firestore
      await _logForecastToFirestore(weather, locationName, forecast);

      print('✅ Weather forecast FCM sent successfully');
    } catch (e) {
      print('❌ Error sending weather forecast FCM: $e');
    }
  }

  /// Send FCM notification to a topic
  Future<void> _sendFCMToTopic({
    required String topic,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final url = Uri.parse('https://fcm.googleapis.com/fcm/send');
      
      final payload = {
        'to': '/topics/$topic',
        'notification': {
          'title': title,
          'body': body,
          'sound': 'default',
          'badge': '1',
          'priority': 'high',
        },
        'data': data ?? {},
        'priority': 'high',
        'content_available': true,
      };

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=$_fcmServerKey',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('📤 FCM sent to topic "$topic": ${result['success']} success, ${result['failure']} failed');
      } else {
        print('❌ FCM send failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('❌ Error sending FCM to topic: $e');
    }
  }

  /// Get current location
  Future<Position?> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('❌ Location error: $e');
      return null;
    }
  }

  /// Fetch weather data from API
  Future<Map<String, dynamic>?> _fetchWeatherData(double lat, double lon) async {
    try {
      // Using OpenWeatherMap-style endpoint (adjust to your actual API)
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$_weatherApiKey&units=metric'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('❌ Weather API error: $e');
      return null;
    }
  }

  /// Get location name from coordinates
  Future<String> _getLocationName(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lon&key=$_geocodingApiKey'
      );

      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final addressComponents = data['results'][0]['address_components'] as List;
          
          String? city;
          String? state;
          
          for (var component in addressComponents) {
            final types = component['types'] as List;
            if (types.contains('locality')) {
              city = component['long_name'];
            }
            if (types.contains('administrative_area_level_1')) {
              state = component['short_name'];
            }
          }
          
          if (city != null) {
            return state != null ? '$city, $state' : city;
          }
        }
      }
      return 'Your Location';
    } catch (e) {
      return 'Your Location';
    }
  }

  /// Parse weather data
  Map<String, dynamic> _parseWeatherData(Map<String, dynamic> data) {
    return {
      'temperature': (data['main']?['temp'] ?? 0).toDouble(),
      'feels_like': (data['main']?['feels_like'] ?? 0).toDouble(),
      'condition': data['weather']?[0]?['main'] ?? 'Unknown',
      'description': data['weather']?[0]?['description'] ?? '',
      'humidity': (data['main']?['humidity'] ?? 0).toInt(),
      'pressure': (data['main']?['pressure'] ?? 0).toInt(),
      'wind_speed': (data['wind']?['speed'] ?? 0).toDouble(),
      'clouds': (data['clouds']?['all'] ?? 0).toInt(),
      'visibility': (data['visibility'] ?? 0).toInt(),
    };
  }

  /// Create forecast message
  String _createForecastMessage(Map<String, dynamic> weather, String location) {
    final temp = weather['temperature'].toStringAsFixed(1);
    final feelsLike = weather['feels_like'].toStringAsFixed(1);
    final condition = weather['description'];
    final humidity = weather['humidity'];
    final windSpeed = weather['wind_speed'].toStringAsFixed(1);

    final message = '''
🌡️ ${temp}°C (feels like ${feelsLike}°C)
☁️ ${condition.toString().capitalize()}
💧 Humidity: ${humidity}%
💨 Wind: ${windSpeed} m/s
📍 $location
🕐 ${_getTimeString()}
    '''.trim();

    return message;
  }

  /// Create alert message
  String _createAlertMessage(Map<String, dynamic> weather, String location) {
    final temp = weather['temperature'];
    final condition = weather['condition'];
    final windSpeed = weather['wind_speed'];

    String alertMsg = '';

    if (temp > 35) {
      alertMsg = '🔥 HIGH HEAT WARNING! Temperature: ${temp.toStringAsFixed(1)}°C\n';
      alertMsg += '⚠️ Protect crops from heat stress. Increase irrigation.';
    } else if (temp < 5) {
      alertMsg = '❄️ COLD ALERT! Temperature: ${temp.toStringAsFixed(1)}°C\n';
      alertMsg += '⚠️ Risk of frost damage. Protect sensitive crops.';
    } else if (condition == 'Rain' || condition == 'Thunderstorm') {
      alertMsg = '🌧️ RAIN ALERT! ${condition}\n';
      alertMsg += '⚠️ Heavy rain expected. Secure equipment and check drainage.';
    } else if (windSpeed > 15) {
      alertMsg = '💨 WIND ALERT! Wind speed: ${windSpeed.toStringAsFixed(1)} m/s\n';
      alertMsg += '⚠️ Strong winds. Secure structures and greenhouses.';
    }

    return '$alertMsg\n📍 $location\n🕐 ${_getTimeString()}';
  }

  /// Check if weather warrants an alert
  bool _shouldAlert(Map<String, dynamic> weather) {
    final temp = weather['temperature'];
    final condition = weather['condition'];
    final windSpeed = weather['wind_speed'];

    return temp > 35 || 
           temp < 5 || 
           condition == 'Rain' || 
           condition == 'Thunderstorm' ||
           condition == 'Snow' ||
           windSpeed > 15;
  }

  /// Get alert type
  String _getAlertType(Map<String, dynamic> weather) {
    final temp = weather['temperature'];
    final condition = weather['condition'];
    final windSpeed = weather['wind_speed'];

    if (temp > 35) return 'heat';
    if (temp < 5) return 'cold';
    if (condition == 'Rain' || condition == 'Thunderstorm') return 'rain';
    if (windSpeed > 15) return 'wind';
    return 'general';
  }

  /// Get formatted time string
  String _getTimeString() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  /// Log forecast to Firestore
  Future<void> _logForecastToFirestore(
    Map<String, dynamic> weather,
    String location,
    String message,
  ) async {
    try {
      await FirebaseFirestore.instance.collection('weather_forecasts').add({
        'temperature': weather['temperature'],
        'condition': weather['condition'],
        'description': weather['description'],
        'humidity': weather['humidity'],
        'wind_speed': weather['wind_speed'],
        'location': location,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'sent_via_fcm': true,
      });
    } catch (e) {
      print('❌ Firestore logging error: $e');
    }
  }

  /// Get status
  bool get isRunning => _isRunning;
}

// Extension to capitalize strings
extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
