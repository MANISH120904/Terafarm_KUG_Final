// lib/providers/weather_provider.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../location.dart';
import '../services/weather_service.dart';
import '../services/live_weather_service.dart';
import '../services/notification_service.dart';

class WeatherProvider extends ChangeNotifier {
  bool _showWeather = false;
  bool _loadingWeather = false;
  double? _temperature;
  int? _humidity;
  String? _condition;
  String? _alert; // New property for weather alerts
  Timer? _weatherAlertTimer;
  final WeatherService _weatherService = WeatherService();
  final NotificationService _notificationService = NotificationService();
  bool _notificationsInitialized = false;

  bool get showWeather => _showWeather;
  bool get loadingWeather => _loadingWeather;
  double? get temperature => _temperature;
  int? get humidity => _humidity;
  String? get condition => _condition;
  String? get alert => _alert; // Getter for the alert

  WeatherProvider() {
    // Defer plugin work so first frame is not delayed on cold start.
    Future<void>.delayed(const Duration(seconds: 2), () {
      _initializeNotifications();
      _startPeriodicWeatherCheck();
    });
  }

  Future<void> _initializeNotifications() async {
    if (_notificationsInitialized) return;
    print('WeatherProvider: Initializing notifications...');
    try {
      await _notificationService.initialize();
      _notificationsInitialized = true;
      print('WeatherProvider: Notifications initialized successfully');
    } catch (e, stackTrace) {
      print('WeatherProvider: Failed to initialize notifications: $e');
      print('WeatherProvider: Stack trace: $stackTrace');
      _notificationsInitialized = false;
      // Don't rethrow — keep UI responsive on slow devices.
    }
  }

  // Start periodic weather alert checking (every 30 minutes)
  void _startPeriodicWeatherCheck() {
    _weatherAlertTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _checkWeatherAlerts();
    });
    
    // Also check immediately when provider is created
    Future.delayed(const Duration(seconds: 5), () {
      _checkWeatherAlerts();
    });
  }

  Future<void> _checkWeatherAlerts() async {
    try {
      await _weatherService.fetchWeatherAlerts(this);
    } catch (e) {
      // Don't show error alerts to users for API issues
      // Just log the error and continue normal operation
      print("Weather alert check failed: $e");
      // Keep existing alert if any, don't override with error message
    }
  }

  void setLoading(bool loading) {
    _loadingWeather = loading;
    notifyListeners();
  }

  void setWeather(double temp, int humidity, String condition) {
    _temperature = temp;
    _humidity = humidity;
    _condition = condition;
    _showWeather = true;
    _loadingWeather = false;
    notifyListeners();
  }

  // Method to set a weather alert
  void setAlert(String? alertMessage) {
    final previousAlert = _alert;
    _alert = alertMessage;
    
    // Only send notification if this is a new alert (different from previous)
    if (alertMessage != null && alertMessage != previousAlert) {
      _sendWeatherNotification(alertMessage);
    }
    
    notifyListeners();
  }

  Future<void> _sendWeatherNotification(String alertMessage) async {
    await _initializeNotifications();
    
    String title = "🌦️ Weather Alert";
    String payload = "weather_alert";
    
    // Customize notification based on alert type
    if (alertMessage.toLowerCase().contains('heavy rain') || 
        alertMessage.toLowerCase().contains('rain')) {
      title = "🌧️ Heavy Rain Warning";
      payload = "heavy_rain_alert";
    } else if (alertMessage.toLowerCase().contains('snow') || 
               alertMessage.toLowerCase().contains('sleet')) {
      title = "❄️ Snow/Sleet Warning";
      payload = "snow_alert";
    } else if (alertMessage.toLowerCase().contains('thunderstorm') || 
               alertMessage.toLowerCase().contains('storm')) {
      title = "⛈️ Thunderstorm Alert";
      payload = "storm_alert";
    } else if (alertMessage.toLowerCase().contains('wind')) {
      title = "💨 Strong Wind Alert";
      payload = "wind_alert";
    }

    await _notificationService.showWeatherAlert(
      title: title,
      body: alertMessage,
      payload: payload,
    );
  }

  void resetWeather() {
    _showWeather = false;
    _loadingWeather = false;
    _temperature = null;
    _humidity = null;
    _condition = null;
    _alert = null; // Reset the alert as well
    notifyListeners();
  }

  // Fetch weather data using LocationService + Open-Meteo
  Future<void> fetchWeather() async {
    setLoading(true);
    try {
      final locService = LocationService();
      Position? pos = locService.currentPosition;
      if (pos == null) {
        await locService.determinePosition();
        pos = locService.currentPosition;
      }
      if (pos == null) throw Exception('Could not determine location');

      final weather = await LiveWeatherService.byCoordinates(
        lat: pos.latitude,
        lon: pos.longitude,
      );
      setWeather(
        weather.temperatureC,
        weather.humidity,
        weather.condition,
      );

      _checkWeatherAlerts();
    } catch (_) {
      setLoading(false);
    }
  }

  // Method to manually send a test notification
  Future<void> sendTestNotification() async {
    print("WeatherProvider: Sending test notification...");
    await _initializeNotifications();
    try {
      await _notificationService.showWeatherAlert(
        title: "🧪 Test Weather Notification",
        body: "This is a test notification to verify your weather alerts are working correctly!",
        payload: "test_notification",
      );
      print("WeatherProvider: Test notification sent successfully!");
    } catch (e) {
      print("WeatherProvider: Error sending test notification: $e");
      rethrow;
    }
  }

  @override
  void dispose() {
    _weatherAlertTimer?.cancel();
    super.dispose();
  }
}