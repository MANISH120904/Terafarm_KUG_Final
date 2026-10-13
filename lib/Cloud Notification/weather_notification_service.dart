import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../config/api_keys.dart';

/// Weather Notification Service using GCP Weather API and Google Maps
/// Provides real-time weather alerts and forecasting notifications
class WeatherNotificationService {
  static final WeatherNotificationService _instance = WeatherNotificationService._internal();
  factory WeatherNotificationService() => _instance;
  WeatherNotificationService._internal();

  // API Keys
  static const String _weatherApiKey = 'YOUR_API_KEY_HERE';
  static const String _mapsApiKey = 'YOUR_API_KEY_HERE';
  
  // Notification channels
  static const String _weatherAlertChannelId = 'weather_alerts';
  static const String _weatherForecastChannelId = 'weather_forecast';
  
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  
  Timer? _weatherCheckTimer;
  Position? _lastKnownPosition;
  String? _lastKnownLocation;

  /// Initialize the notification service
  Future<void> initialize() async {
    await _initializeNotifications();
    await _requestPermissions();
    await _loadLastKnownLocation();
    _startPeriodicWeatherCheck();
  }

  /// Initialize notification plugin
  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();
  }

  /// Create Android notification channels
  Future<void> _createNotificationChannels() async {
    const AndroidNotificationChannel alertChannel = AndroidNotificationChannel(
      _weatherAlertChannelId,
      'Weather Alerts',
      description: 'Critical weather warnings and alerts',
      importance: Importance.max,
      showBadge: true,
      enableVibration: true,
      enableLights: true,
      playSound: true,
    );

    const AndroidNotificationChannel forecastChannel = AndroidNotificationChannel(
      _weatherForecastChannelId,
      'Weather Forecast',
      description: 'Daily weather forecasts and updates',
      importance: Importance.defaultImportance,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alertChannel);

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(forecastChannel);
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      // Handle navigation based on payload
      print('Notification tapped with payload: ${response.payload}');
      // TODO: Navigate to weather details page
    }
  }

  /// Load last known location from storage
  Future<void> _loadLastKnownLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('last_latitude');
    final lon = prefs.getDouble('last_longitude');
    final location = prefs.getString('last_location_name');

    if (lat != null && lon != null) {
      _lastKnownPosition = Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
      _lastKnownLocation = location;
    }
  }

  /// Save current location to storage
  Future<void> _saveLocation(Position position, String locationName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_latitude', position.latitude);
    await prefs.setDouble('last_longitude', position.longitude);
    await prefs.setString('last_location_name', locationName);
    _lastKnownPosition = position;
    _lastKnownLocation = locationName;
  }

  /// Get current user location
  Future<Position?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('Location services are disabled');
        return _lastKnownPosition;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
          return _lastKnownPosition;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print('Location permissions are permanently denied');
        return _lastKnownPosition;
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get location name using Google Maps Geocoding API
      final locationName = await _getLocationName(position.latitude, position.longitude);
      await _saveLocation(position, locationName);

      return position;
    } catch (e) {
      print('Error getting location: $e');
      return _lastKnownPosition;
    }
  }

  /// Get location name from coordinates using Google Maps Geocoding API
  Future<String> _getLocationName(double latitude, double longitude) async {
    try {
      final url = Uri.https(
        'maps.googleapis.com',
        '/maps/api/geocode/json',
        {
          'latlng': '$latitude,$longitude',
          'key': _mapsApiKey,
        },
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final addressComponents = data['results'][0]['address_components'] as List;
          
          // Extract city/locality
          String? city;
          String? state;
          
          for (var component in addressComponents) {
            final types = component['types'] as List;
            if (types.contains('locality')) {
              city = component['long_name'];
            } else if (types.contains('administrative_area_level_1')) {
              state = component['short_name'];
            }
          }
          
          return city != null ? '$city${state != null ? ", $state" : ""}' : 'Unknown Location';
        }
      }
      return 'Unknown Location';
    } catch (e) {
      print('Error getting location name: $e');
      return 'Unknown Location';
    }
  }

  /// Fetch weather data from GCP Weather API
  Future<Map<String, dynamic>?> fetchWeatherData(double latitude, double longitude) async {
    try {
      // Using OpenWeatherMap API as a proxy for weather data
      // You can replace this with actual GCP Weather API endpoint
      final url = Uri.https(
        'api.openweathermap.org',
        '/data/2.5/weather',
        {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'appid': _weatherApiKey,
          'units': 'metric',
        },
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching weather data: $e');
      return null;
    }
  }

  /// Fetch weather forecast
  Future<Map<String, dynamic>?> fetchWeatherForecast(double latitude, double longitude) async {
    try {
      final url = Uri.https(
        'api.openweathermap.org',
        '/data/2.5/forecast',
        {
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'appid': _weatherApiKey,
          'units': 'metric',
          'cnt': '8', // 24 hours (3-hour intervals)
        },
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return null;
    } catch (e) {
      print('Error fetching forecast: $e');
      return null;
    }
  }

  /// Check for weather alerts
  Future<void> checkWeatherAlerts() async {
    final position = await getCurrentLocation();
    if (position == null) return;

    final weatherData = await fetchWeatherData(position.latitude, position.longitude);
    if (weatherData == null) return;

    await _analyzeAndNotify(weatherData, position);
  }

  /// Analyze weather data and send notifications
  Future<void> _analyzeAndNotify(Map<String, dynamic> weatherData, Position position) async {
    final main = weatherData['main'];
    final weather = weatherData['weather'][0];
    final temp = main['temp'];
    final condition = weather['main'];
    final description = weather['description'];
    final humidity = main['humidity'];
    final windSpeed = weatherData['wind']['speed'];

    // Check for severe weather conditions
    bool isSevereWeather = false;
    String alertTitle = '';
    String alertMessage = '';

    // Extreme temperature
    if (temp > 40) {
      isSevereWeather = true;
      alertTitle = '🌡️ Extreme Heat Alert';
      alertMessage = 'Temperature: ${temp.toStringAsFixed(1)}°C. Stay hydrated and avoid direct sunlight.';
    } else if (temp < 5) {
      isSevereWeather = true;
      alertTitle = '❄️ Cold Weather Alert';
      alertMessage = 'Temperature: ${temp.toStringAsFixed(1)}°C. Protect your crops from frost.';
    }

    // Heavy rain or storm
    if (condition.toLowerCase().contains('thunderstorm') || 
        condition.toLowerCase().contains('storm')) {
      isSevereWeather = true;
      alertTitle = '⛈️ Severe Storm Alert';
      alertMessage = '$description detected. Secure loose items and protect crops.';
    } else if (condition.toLowerCase().contains('rain') && humidity > 85) {
      isSevereWeather = true;
      alertTitle = '🌧️ Heavy Rainfall Alert';
      alertMessage = '$description with ${humidity}% humidity. Monitor drainage systems.';
    }

    // High wind
    if (windSpeed > 15) {
      isSevereWeather = true;
      alertTitle = '💨 High Wind Alert';
      alertMessage = 'Wind speed: ${windSpeed.toStringAsFixed(1)} m/s. Secure structures and crops.';
    }

    // Send notification if severe weather detected
    if (isSevereWeather) {
      await _sendWeatherAlert(
        title: alertTitle,
        body: '$alertMessage\nLocation: ${_lastKnownLocation ?? "Current Location"}',
        payload: json.encode({
          'type': 'weather_alert',
          'lat': position.latitude,
          'lon': position.longitude,
          'weather': weatherData,
        }),
      );

      // Save alert to Firestore
      await _saveAlertToFirestore(alertTitle, alertMessage, weatherData);
    }
  }

  /// Send weather alert notification
  Future<void> _sendWeatherAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _weatherAlertChannelId,
      'Weather Alerts',
      channelDescription: 'Critical weather warnings and alerts',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      enableLights: true,
      color: Color.fromARGB(255, 255, 87, 34),
      playSound: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Send daily weather forecast notification
  Future<void> sendDailyForecast() async {
    final position = await getCurrentLocation();
    if (position == null) return;

    final forecastData = await fetchWeatherForecast(position.latitude, position.longitude);
    if (forecastData == null) return;

    final list = forecastData['list'] as List;
    if (list.isEmpty) return;

    // Get today's forecast
    final todayForecast = list[0];
    final temp = todayForecast['main']['temp'];
    final minTemp = todayForecast['main']['temp_min'];
    final maxTemp = todayForecast['main']['temp_max'];
    final condition = todayForecast['weather'][0]['description'];
    final humidity = todayForecast['main']['humidity'];

    final title = '🌤️ Today\'s Weather Forecast';
    final body = '''
${_lastKnownLocation ?? "Your Location"}
${condition.toString().toUpperCase()}
Temperature: ${temp.toStringAsFixed(1)}°C (${minTemp.toStringAsFixed(1)}°-${maxTemp.toStringAsFixed(1)}°C)
Humidity: $humidity%

Agricultural Advice: ${_getAgriculturalAdvice(temp, humidity, condition)}
''';

    await _sendForecastNotification(title, body);
  }

  /// Send forecast notification
  Future<void> _sendForecastNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _weatherForecastChannelId,
      'Weather Forecast',
      channelDescription: 'Daily weather forecasts and updates',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
    );
  }

  /// Get agricultural advice based on weather
  String _getAgriculturalAdvice(double temp, int humidity, String condition) {
    if (temp > 35 && humidity < 40) {
      return 'Increase irrigation. Crops may need extra water.';
    } else if (temp < 10) {
      return 'Protect sensitive crops from cold stress.';
    } else if (humidity > 80) {
      return 'Monitor for fungal diseases. Ensure good ventilation.';
    } else if (condition.toLowerCase().contains('rain')) {
      return 'Good for crops. Check drainage to prevent waterlogging.';
    } else if (condition.toLowerCase().contains('clear')) {
      return 'Ideal conditions. Continue regular maintenance.';
    }
    return 'Monitor your crops regularly.';
  }

  /// Save alert to Firestore for history
  Future<void> _saveAlertToFirestore(String title, String message, Map<String, dynamic> weatherData) async {
    try {
      await FirebaseFirestore.instance.collection('weather_alerts').add({
        'title': title,
        'message': message,
        'location': _lastKnownLocation,
        'latitude': _lastKnownPosition?.latitude,
        'longitude': _lastKnownPosition?.longitude,
        'weatherData': weatherData,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving alert to Firestore: $e');
    }
  }

  /// Start periodic weather check (every 30 minutes)
  void _startPeriodicWeatherCheck() {
    _weatherCheckTimer?.cancel();
    _weatherCheckTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      checkWeatherAlerts();
    });

    // Initial check
    checkWeatherAlerts();
  }

  /// Schedule daily forecast notification (8 AM)
  Future<void> scheduleDailyForecast() async {
    tz.initializeTimeZones();
    final location = tz.getLocation('Asia/Kolkata'); // Indian timezone
    
    final now = tz.TZDateTime.now(location);
    var scheduledDate = tz.TZDateTime(location, now.year, now.month, now.day, 8, 0);
    
    if (now.isAfter(scheduledDate)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notificationsPlugin.zonedSchedule(
      0,
      '🌤️ Daily Weather Forecast',
      'Check your daily weather update',
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _weatherForecastChannelId,
          'Weather Forecast',
          channelDescription: 'Daily weather forecasts',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Stop all notifications and timers
  void dispose() {
    _weatherCheckTimer?.cancel();
  }
}
