import 'package:flutter/foundation.dart';
import '../services/weather_notification_service.dart';

/// Utility class to manage FCM token updates across the app
/// 
/// This ensures FCM tokens are always up-to-date for weather notifications
class FCMTokenManager {
  static final FCMTokenManager _instance = FCMTokenManager._internal();
  factory FCMTokenManager() => _instance;
  FCMTokenManager._internal();

  final WeatherNotificationService _weatherService = WeatherNotificationService();
  bool _isUpdating = false;
  DateTime? _lastUpdateTime;

  /// Update FCM token for current user
  /// 
  /// **When to call:**
  /// - ✅ On every login (existing users)
  /// - ✅ After successful signup (new users)
  /// - ✅ When app becomes active (optional)
  /// - ✅ When user enables notifications in settings
  /// 
  /// **Parameters:**
  /// - [forceUpdate]: Update even if recently updated (default: false)
  /// - [updateLocation]: Also update user location (default: true)
  /// 
  /// **Returns:**
  /// - `true` if FCM token updated successfully
  /// - `false` if update failed or was skipped
  Future<bool> updateFCMTokenForCurrentUser({
    bool forceUpdate = false,
    bool updateLocation = true,
  }) async {
    try {
      // Prevent concurrent updates
      if (_isUpdating && !forceUpdate) {
        debugPrint('⏭️ FCM token update already in progress, skipping...');
        return false;
      }

      // Skip if recently updated (within last 5 minutes)
      if (!forceUpdate && _lastUpdateTime != null) {
        final timeSinceLastUpdate = DateTime.now().difference(_lastUpdateTime!);
        if (timeSinceLastUpdate.inMinutes < 5) {
          debugPrint('⏭️ FCM token updated ${timeSinceLastUpdate.inMinutes} minutes ago, skipping...');
          return true; // Return true since token is already up-to-date
        }
      }

      _isUpdating = true;
      debugPrint('🔄 Updating FCM token for current user...');

      final success = await _weatherService.updateFCMToken(
        skipLocationUpdate: !updateLocation,
      );

      if (success) {
        _lastUpdateTime = DateTime.now();
        debugPrint('✅ FCM token update completed successfully');
        debugPrint('📱 User will now receive personalized weather notifications');
      } else {
        debugPrint('⚠️ FCM token update failed - user may not receive notifications');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
      return false;
    } finally {
      _isUpdating = false;
    }
  }

  /// Initialize weather notifications for new user
  /// 
  /// **When to call:**
  /// - ✅ After successful account creation
  /// - ✅ First time user logs in
  /// 
  /// This will:
  /// 1. Request notification permissions
  /// 2. Request location permissions
  /// 3. Get and save FCM token
  /// 4. Get and save user location
  Future<bool> initializeForNewUser() async {
    try {
      debugPrint('🆕 Initializing weather notifications for new user...');

      _isUpdating = true;
      final success = await _weatherService.initialize();

      if (success) {
        _lastUpdateTime = DateTime.now();
        debugPrint('✅ Weather notifications initialized for new user');
      } else {
        debugPrint('⚠️ Weather notifications initialization incomplete');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error initializing weather notifications: $e');
      return false;
    } finally {
      _isUpdating = false;
    }
  }

  /// Update user location only (keeps existing FCM token)
  /// 
  /// **When to call:**
  /// - ✅ When user manually updates location in settings
  /// - ✅ When user grants location permission
  /// - ✅ Periodically to keep location current
  Future<bool> updateLocationOnly() async {
    try {
      debugPrint('📍 Updating user location...');

      final success = await _weatherService.updateUserLocation();

      if (success) {
        debugPrint('✅ User location updated successfully');
      } else {
        debugPrint('⚠️ User location update failed');
      }

      return success;
    } catch (e) {
      debugPrint('❌ Error updating location: $e');
      return false;
    }
  }

  /// Check if user has weather notifications enabled
  /// 
  /// Returns `true` if user has valid FCM token in Firestore
  Future<bool> hasWeatherNotificationsEnabled() async {
    try {
      final token = await _weatherService.getFCMToken();
      return token != null && token.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking notification status: $e');
      return false;
    }
  }

  /// Get last update time (for debugging)
  DateTime? get lastUpdateTime => _lastUpdateTime;

  /// Check if update is in progress (for debugging)
  bool get isUpdating => _isUpdating;

  /// Force reset state (for testing)
  void reset() {
    _lastUpdateTime = null;
    _isUpdating = false;
    debugPrint('🔄 FCMTokenManager state reset');
  }
}

/// Extension methods for easy access
extension FCMTokenManagerExtension on FCMTokenManager {
  /// Quick update FCM token on login
  Future<bool> onLogin() => updateFCMTokenForCurrentUser(
    forceUpdate: false,
    updateLocation: true,
  );

  /// Quick update FCM token on signup
  Future<bool> onSignup() => initializeForNewUser();

  /// Quick update when app becomes active
  Future<bool> onAppActive() => updateFCMTokenForCurrentUser(
    forceUpdate: false,
    updateLocation: false, // Don't update location on every app open
  );
}
