// lib/services/notification_service.dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    print("NotificationService: Starting initialization...");

    try {
      print("NotificationService: Attempting to initialize plugin...");
      
      // Try the most basic initialization first
      final bool? initialized = await _flutterLocalNotificationsPlugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@android:drawable/ic_dialog_info'),
        ),
      );

      print("NotificationService: Basic initialization result: $initialized");

      // Request permissions for Android 13+
      await _requestPermissions();

      // Create Android notification channel for weather alerts
      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'weather_alerts',
            'Weather Alerts',
            description: 'Weather alerts and severe weather warnings',
            importance: Importance.high,
          ),
        );
        print("NotificationService: Weather alert channel created");
      }
      
      _isInitialized = true;
      print("NotificationService: Initialization completed successfully");
    } catch (e, stackTrace) {
      print("NotificationService: Initialization failed with error: $e");
      print("NotificationService: Stack trace: $stackTrace");
      
      // Mark as initialized anyway to prevent continuous retries
      _isInitialized = true;
      
      // Re-throw the error so caller can handle it
      rethrow;
    }
  }

  Future<void> _requestPermissions() async {
    print("NotificationService: Requesting permissions...");
    
    final androidPlugin = _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin != null) {
      final bool? exactAlarmsResult = await androidPlugin.requestExactAlarmsPermission();
      print("NotificationService: Exact alarms permission: $exactAlarmsResult");
      
      final bool? notificationsResult = await androidPlugin.requestNotificationsPermission();
      print("NotificationService: Notifications permission: $notificationsResult");
    }
  }

  Future<void> showWeatherAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    print("NotificationService: Attempting to show weather alert - Title: $title, Body: $body");
    
    if (!_isInitialized) {
      print("NotificationService: Not initialized, initializing now...");
      await initialize();
    }


    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'weather_alerts',
      'Weather Alerts',
      channelDescription: 'Weather alerts and severe weather warnings',
      importance: Importance.high,
      priority: Priority.high,
      // Using a simpler icon to avoid potential icon issues
      enableVibration: true,
      playSound: true,
      ticker: 'Weather Alert',
      category: AndroidNotificationCategory.alarm,
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
      badgeNumber: 1,
      categoryIdentifier: 'weather_alert',
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    print("NotificationService: Showing notification with ID: $notificationId");

    try {
      await _flutterLocalNotificationsPlugin.show(
        notificationId, // Unique ID
        title,
        body,
        platformChannelSpecifics,
        payload: payload ?? 'weather_alert',
      );
      print("NotificationService: Notification sent successfully!");
    } catch (e) {
      print("NotificationService: Error sending notification: $e");
      rethrow;
    }
  }

  Future<void> showGeneralNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'general_notifications',
      'General Notifications',
      channelDescription: 'General app notifications',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF16A34A),
    );

    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unique ID
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id);
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  // Check if notifications are enabled
  Future<bool> areNotificationsEnabled() async {
    final bool? result = await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.areNotificationsEnabled();
    return result ?? false;
  }
}
