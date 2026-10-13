import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'weather_notification_service.dart';

/// FCM Push Notification Handler for Weather Alerts
/// Handles background and foreground notifications from Firebase
class FCMNotificationHandler {
  static final FCMNotificationHandler _instance = FCMNotificationHandler._internal();
  factory FCMNotificationHandler() => _instance;
  FCMNotificationHandler._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  
  /// Get FCM token
  String? get fcmToken => _fcmToken;

  /// Initialize FCM
  Future<void> initialize() async {
    // Request permission for iOS
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: true,
      provisional: false,
      sound: true,
    );

    print('User granted permission: ${settings.authorizationStatus}');

    // Get FCM token
    _fcmToken = await _messaging.getToken();
    print('FCM Token: $_fcmToken');

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      print('FCM Token refreshed: $newToken');
      // TODO: Send token to your server
    });

    // Setup message handlers
    _setupMessageHandlers();

    // Subscribe to weather topics
    await subscribeToWeatherTopics();
  }

  /// Setup message handlers
  void _setupMessageHandlers() {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background messages
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Handle notification tap when app is terminated
    _messaging.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageOpenedApp(message);
      }
    });
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.messageId}');
    
    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'Weather Alert',
        body: notification.body ?? '',
        payload: json.encode(data),
        isWeatherAlert: data['type'] == 'weather_alert',
      );
    }

    // Process weather data if present
    if (data.containsKey('weather_data')) {
      _processWeatherData(data);
    }
  }

  /// Handle message opened (notification tap)
  void _handleMessageOpenedApp(RemoteMessage message) {
    print('Message opened: ${message.messageId}');
    final data = message.data;
    
    // Navigate to appropriate screen based on notification type
    if (data['type'] == 'weather_alert') {
      // TODO: Navigate to weather alerts page
      print('Navigate to weather alerts');
    } else if (data['type'] == 'weather_forecast') {
      // TODO: Navigate to weather forecast page
      print('Navigate to forecast');
    }
  }

  /// Process weather data from notification
  void _processWeatherData(Map<String, dynamic> data) {
    try {
      final weatherData = json.decode(data['weather_data']);
      print('Processing weather data: $weatherData');
      // Additional processing if needed
    } catch (e) {
      print('Error processing weather data: $e');
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    bool isWeatherAlert = false,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      isWeatherAlert ? 'weather_alerts' : 'weather_forecast',
      isWeatherAlert ? 'Weather Alerts' : 'Weather Forecast',
      channelDescription: isWeatherAlert 
          ? 'Critical weather warnings and alerts'
          : 'Daily weather forecasts and updates',
      importance: isWeatherAlert ? Importance.max : Importance.defaultImportance,
      showWhen: true,
      enableVibration: isWeatherAlert,
      enableLights: isWeatherAlert,
      color: const Color.fromARGB(255, 255, 87, 34),
      playSound: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Subscribe to weather topics
  Future<void> subscribeToWeatherTopics() async {
    try {
      await _messaging.subscribeToTopic('weather_alerts');
      await _messaging.subscribeToTopic('weather_forecast');
      await _messaging.subscribeToTopic('agricultural_alerts');
      print('Subscribed to weather topics');
    } catch (e) {
      print('Error subscribing to topics: $e');
    }
  }

  /// Unsubscribe from weather topics
  Future<void> unsubscribeFromWeatherTopics() async {
    try {
      await _messaging.unsubscribeFromTopic('weather_alerts');
      await _messaging.unsubscribeFromTopic('weather_forecast');
      await _messaging.unsubscribeFromTopic('agricultural_alerts');
      print('Unsubscribed from weather topics');
    } catch (e) {
      print('Error unsubscribing from topics: $e');
    }
  }

  /// Subscribe to location-specific topic
  Future<void> subscribeToLocationTopic(double latitude, double longitude) async {
    try {
      // Create topic based on coordinates (rounded to ~10km grid)
      final lat = (latitude * 10).round() / 10;
      final lon = (longitude * 10).round() / 10;
      final topic = 'weather_${lat}_$lon'.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      await _messaging.subscribeToTopic(topic);
      print('Subscribed to location topic: $topic');
    } catch (e) {
      print('Error subscribing to location topic: $e');
    }
  }

  /// Get FCM token
  Future<String?> getToken() async {
    return _fcmToken ?? await _messaging.getToken();
  }

  /// Subscribe to a custom topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      print('Subscribed to topic: $topic');
    } catch (e) {
      print('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      print('Unsubscribed from topic: $topic');
    } catch (e) {
      print('Error unsubscribing from topic: $e');
    }
  }

  /// Send FCM token to server
  Future<void> sendTokenToServer(String userId) async {
    if (_fcmToken == null) return;

    try {
      // TODO: Send token to your backend server
      // Example:
      // await http.post(
      //   Uri.parse('https://your-api.com/register-token'),
      //   body: json.encode({
      //     'userId': userId,
      //     'fcmToken': _fcmToken,
      //     'platform': Platform.isAndroid ? 'android' : 'ios',
      //   }),
      // );
      print('FCM token sent to server for user: $userId');
    } catch (e) {
      print('Error sending token to server: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('Handling background message: ${message.messageId}');
  
  // Process weather alert in background
  final data = message.data;
  if (data['type'] == 'weather_alert') {
    // Trigger local weather check
    final weatherService = WeatherNotificationService();
    await weatherService.initialize();
    await weatherService.checkWeatherAlerts();
  }
}
