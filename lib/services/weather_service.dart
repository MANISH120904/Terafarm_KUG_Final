// lib/services/weather_service.dart
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import '../location.dart';
import '../providers/weather_provider.dart';
import 'notification_service.dart';

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  static const String _apiKey =
      "8a292724491a2b7596a7b7a1e4573176"; // Replace with your OpenWeatherMap API key
  static const String _baseUrl = "api.openweathermap.org";
  
  final NotificationService _notificationService = NotificationService();

  Future<void> fetchWeatherAlerts(WeatherProvider weatherProvider) async {
    try {
      final locService = LocationService();
      Position? pos = locService.currentPosition;

      if (pos == null) {
        await locService.determinePosition();
        pos = locService.currentPosition;
      }

      if (pos == null) {
        throw Exception('Could not determine location');
      }

      final uri = Uri.https(_baseUrl, '/data/3.0/onecall', {
        'lat': pos.latitude.toString(),
        'lon': pos.longitude.toString(),
        'exclude': 'current,minutely,daily',
        'appid': _apiKey,
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check for severe weather alerts from the API
        if (data['alerts'] != null) {
          final alert = data['alerts'][0];
          final alertMessage = "Weather Alert: ${alert['event']}. ${alert['description']}";
          weatherProvider.setAlert(alertMessage);
          
          // Send notification for severe weather alerts
          await _notificationService.showWeatherAlert(
            title: "⚠️ Severe Weather Alert",
            body: alertMessage,
            payload: "severe_weather_alert",
          );
          return;
        }

        // If no alerts, check the hourly forecast for the next 24 hours
        final hourlyForecasts = data['hourly'].take(24).toList();
        for (var forecast in hourlyForecasts) {
          final weatherId = forecast['weather'][0]['id'];
          // Check for thunderstorms, heavy rain, or other severe conditions
          if (weatherId < 300 || (weatherId >= 502 && weatherId <= 531)) {
            final alertMessage = "Heads up! Heavy rain is expected in the next 24 hours. Make sure your crops are protected.";
            weatherProvider.setAlert(alertMessage);
            
            // Send notification for heavy rain
            await _notificationService.showWeatherAlert(
              title: "🌧️ Heavy Rain Warning",
              body: alertMessage,
              payload: "heavy_rain_alert",
            );
            return;
          }
          if (weatherId >= 600 && weatherId <= 622) {
            final alertMessage = "Warning: Snow or sleet is expected. Protect your crops from freezing temperatures.";
            weatherProvider.setAlert(alertMessage);
            
            // Send notification for snow/sleet
            await _notificationService.showWeatherAlert(
              title: "❄️ Snow/Sleet Warning",
              body: alertMessage,
              payload: "snow_alert",
            );
            return;
          }
        }
        weatherProvider.setAlert(null); // No alerts
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      // Don't set user-visible alerts for API errors
      // Only log the error internally, don't show banner to user
      print("Weather service error: $e");
      weatherProvider.setAlert(null); // Clear any existing alerts
      
      // Optionally send notification for critical errors only (uncomment if needed)
      // await _notificationService.showGeneralNotification(
      //   title: "Weather Service Error",
      //   body: "Could not fetch weather alerts at this time.",
      //   payload: "weather_error",
      // );
    }
  }
  
  // Method to manually send a test weather notification
  Future<void> sendTestWeatherNotification() async {
    await _notificationService.showWeatherAlert(
      title: "🌤️ Test Weather Alert",
      body: "This is a test weather notification to verify the system is working correctly.",
      payload: "test_alert",
    );
  }
}