// lib/providers/weather_provider.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../location.dart';
import '../services/weather_service.dart';
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
    _initializeNotifications();
    _startPeriodicWeatherCheck();
  }

  Future<void> _initializeNotifications() async {
    if (!_notificationsInitialized) {
      print("WeatherProvider: Initializing notifications...");
      try {
        await _notificationService.initialize();
        _notificationsInitialized = true;
        print("WeatherProvider: Notifications initialized successfully");
      } catch (e, stackTrace) {
        print("WeatherProvider: Failed to initialize notifications: $e");
        print("WeatherProvider: Stack trace: $stackTrace");
        // Don't mark as initialized if it failed
        _notificationsInitialized = false;
        rethrow;
      }
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

  // Fetch weather data using LocationService and HTTP
  Future<void> fetchWeather() async {
    setLoading(true);
    try {
      // Determine or get existing position
      final locService = LocationService();
      Position? pos = locService.currentPosition;
      if (pos == null) {
        await locService.determinePosition();
        pos = locService.currentPosition;
      }
      if (pos == null) throw Exception('Could not determine location');
      final query = '${pos.latitude},${pos.longitude}';
      const key =
          '994SBTQFYTXZJPS5YLZP5FWGW'; // Replace with your Visual Crossing API key
      final uri = Uri.https(
        'weather.visualcrossing.com',
        '/VisualCrossingWebServices/rest/services/timeline/$query',
        {
          'unitGroup': 'metric',
          'include': 'current',
          'key': key,
          'contentType': 'json',
        },
      );
      final res = await http.get(uri);
      if (res.statusCode != 200)
        throw Exception('API Error: ${res.statusCode}');
      final data = json.decode(res.body) as Map<String, dynamic>;
      final curr = data['currentConditions'] as Map<String, dynamic>;
      setWeather(
        (curr['temp'] as num).toDouble(),
        (curr['humidity'] as num).toInt(),
        curr['conditions'] as String,
      );
      
      // Also check for weather alerts when fetching weather
      _checkWeatherAlerts();
    } catch (_) {
      setLoading(false);
      // ignore error silently or handle as needed
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