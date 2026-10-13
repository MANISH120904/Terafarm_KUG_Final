import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'weather_notification_service.dart';
import 'fcm_notification_handler.dart';
import 'scheduled_weather_fcm.dart';

/// Notification Manager
/// Coordinates weather notifications and FCM push notifications
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();
  factory NotificationManager() => _instance;
  NotificationManager._internal();

  final WeatherNotificationService _weatherService = WeatherNotificationService();
  final FCMNotificationHandler _fcmHandler = FCMNotificationHandler();
  final ScheduledWeatherFCM _scheduledFCM = ScheduledWeatherFCM();

  bool _isInitialized = false;

  /// Initialize both notification services
  Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('NotificationManager already initialized');
      return;
    }

    try {
      // Firebase should already be initialized in main(); don't block here.
      if (Firebase.apps.isEmpty) {
        debugPrint('Skipping NotificationManager — Firebase not ready');
        return;
      }

      debugPrint('Initializing Weather Notification Service...');
      await _weatherService.initialize();

      debugPrint('Initializing FCM Notification Handler...');
      await _fcmHandler.initialize();

      debugPrint('Subscribing to weather topics...');
      await _fcmHandler.subscribeToWeatherTopics();

      // Location + forecast can run later — don't block app open.
      unawaited(() async {
        try {
          final position = await _weatherService.getCurrentLocation();
          if (position != null) {
            await _fcmHandler.subscribeToLocationTopic(
              position.latitude,
              position.longitude,
            );
          }
          await _weatherService.checkWeatherAlerts();
          await _weatherService.sendDailyForecast();
        } catch (e) {
          debugPrint('Deferred weather setup skipped: $e');
        }
      }());

      _isInitialized = true;
      debugPrint('✅ NotificationManager initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing NotificationManager: $e');
      // Do not rethrow — app UI must keep running.
    }
  }

  /// Check for weather alerts manually
  Future<void> checkWeatherAlerts() async {
    try {
      await _weatherService.checkWeatherAlerts();
    } catch (e) {
      debugPrint('Error checking weather alerts: $e');
    }
  }

  /// Send daily forecast notification manually
  Future<void> sendDailyForecast() async {
    try {
      await _weatherService.sendDailyForecast();
    } catch (e) {
      debugPrint('Error sending daily forecast: $e');
    }
  }

  /// Get current weather data
  Future<Map<String, dynamic>?> getCurrentWeather() async {
    try {
      final position = await _weatherService.getCurrentLocation();
      if (position == null) return null;
      
      return await _weatherService.fetchWeatherData(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint('Error getting current weather: $e');
      return null;
    }
  }

  /// Get weather forecast
  Future<Map<String, dynamic>?> getWeatherForecast() async {
    try {
      final position = await _weatherService.getCurrentLocation();
      if (position == null) return null;
      
      return await _weatherService.fetchWeatherForecast(
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      debugPrint('Error getting weather forecast: $e');
      return null;
    }
  }

  /// Get FCM token
  Future<String?> getFCMToken() async {
    try {
      return await _fcmHandler.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Subscribe to a custom topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcmHandler.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('Error subscribing to topic $topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcmHandler.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('Error unsubscribing from topic $topic: $e');
    }
  }

  /// Update location-based subscriptions
  Future<void> updateLocationSubscriptions() async {
    try {
      final position = await _weatherService.getCurrentLocation();
      if (position != null) {
        await _fcmHandler.subscribeToLocationTopic(
          position.latitude,
          position.longitude,
        );
      }
    } catch (e) {
      debugPrint('Error updating location subscriptions: $e');
    }
  }

  /// Start automated weather forecast FCM (sends every 1 minute)
  Future<void> startAutomatedWeatherFCM() async {
    try {
      await _scheduledFCM.startAutomatedForecasts();
      debugPrint('✅ Automated weather FCM started (1-minute interval)');
    } catch (e) {
      debugPrint('Error starting automated weather FCM: $e');
    }
  }

  /// Stop automated weather forecast FCM
  void stopAutomatedWeatherFCM() {
    try {
      _scheduledFCM.stopAutomatedForecasts();
      debugPrint('🛑 Automated weather FCM stopped');
    } catch (e) {
      debugPrint('Error stopping automated weather FCM: $e');
    }
  }

  /// Check if automated FCM is running
  bool get isAutomatedFCMRunning => _scheduledFCM.isRunning;

  /// Dispose resources
  void dispose() {
    _scheduledFCM.stopAutomatedForecasts();
    _weatherService.dispose();
    _isInitialized = false;
  }
}
