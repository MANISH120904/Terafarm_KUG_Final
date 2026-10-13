import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/foundation.dart';

/// Service to manage weather notifications and user location for personalized forecasts
class WeatherNotificationService {
  static final WeatherNotificationService _instance = WeatherNotificationService._internal();
  factory WeatherNotificationService() => _instance;
  WeatherNotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize weather notification service
  /// Call this when user logs in or app starts
  Future<bool> initialize() async {
    try {
      // Check if user is logged in
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ Cannot initialize: User not logged in');
        return false;
      }

      // Request notification permissions
      final notificationPermission = await requestNotificationPermission();
      if (!notificationPermission) {
        debugPrint('⚠️ Notification permission denied');
        return false;
      }

      // Request location permissions
      final locationPermission = await requestLocationPermission();
      if (!locationPermission) {
        debugPrint('⚠️ Location permission denied');
        return false;
      }

      // Setup user for weather notifications
      final success = await setupUserForWeatherNotifications();
      
      if (success) {
        debugPrint('✅ Weather notification service initialized successfully');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Error initializing weather notification service: $e');
      return false;
    }
  }

  /// Request notification permissions from user
  Future<bool> requestNotificationPermission() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Notification permission granted');
        return true;
      } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
        debugPrint('✅ Provisional notification permission granted');
        return true;
      } else {
        debugPrint('❌ Notification permission denied');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  /// Request location permissions from user
  Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('❌ Location permission denied forever');
        debugPrint('💡 Please enable location in app settings');
        return false;
      }

      if (permission == LocationPermission.denied) {
        debugPrint('❌ Location permission denied');
        return false;
      }

      debugPrint('✅ Location permission granted');
      return true;
    } catch (e) {
      debugPrint('❌ Error requesting location permission: $e');
      return false;
    }
  }

  /// Get current device location
  Future<Position?> getCurrentLocation() async {
    try {
      debugPrint('📍 Getting current location...');
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      );

      debugPrint('✅ Location obtained: ${position.latitude}, ${position.longitude}');
      return position;
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      
      // Try with lower accuracy
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
          timeLimit: const Duration(seconds: 15),
        );
        debugPrint('✅ Location obtained (medium accuracy): ${position.latitude}, ${position.longitude}');
        return position;
      } catch (e2) {
        debugPrint('❌ Failed to get location even with medium accuracy: $e2');
        return null;
      }
    }
  }

  /// Get city name from coordinates using reverse geocoding
  Future<Map<String, String?>> getCityFromCoordinates(double lat, double lon) async {
    try {
      debugPrint('🌍 Reverse geocoding: $lat, $lon');
      
      final placemarks = await placemarkFromCoordinates(lat, lon);
      
      if (placemarks.isEmpty) {
        debugPrint('⚠️ No placemark found for coordinates');
        return {
          'name': 'Unknown Location',
          'city': null,
          'state': null,
          'country': null,
        };
      }

      final place = placemarks.first;
      final cityName = place.locality ?? 
                       place.subAdministrativeArea ?? 
                       place.administrativeArea ?? 
                       'Unknown Location';

      debugPrint('✅ Location resolved: $cityName');
      
      return {
        'name': cityName,
        'city': place.locality,
        'state': place.administrativeArea,
        'country': place.country,
      };
    } catch (e) {
      debugPrint('❌ Error reverse geocoding: $e');
      return {
        'name': 'Unknown Location',
        'city': null,
        'state': null,
        'country': null,
      };
    }
  }

  /// Update FCM token for current user (call on every login)
  /// This ensures users always have the latest FCM token
  Future<bool> updateFCMToken({bool skipLocationUpdate = false}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ Cannot update FCM token: User not logged in');
        return false;
      }

      debugPrint('🔄 Updating FCM token for: ${user.email}');

      // Get FCM token
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) {
        debugPrint('❌ Failed to get FCM token');
        return false;
      }

      debugPrint('📱 FCM Token obtained: ${fcmToken.substring(0, 30)}...');

      // Update Firestore with new FCM token
      await _firestore.collection('users').doc(user.uid).set({
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        'weatherNotificationsEnabled': true,
      }, SetOptions(merge: true));

      debugPrint('✅ FCM token updated in Firestore');

      // Update location if not skipped
      if (!skipLocationUpdate) {
        await updateUserLocation();
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        debugPrint('🔄 FCM token refreshed: ${newToken.substring(0, 30)}...');
        _firestore.collection('users').doc(user.uid).update({
          'fcmToken': newToken,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      });

      return true;
    } catch (e) {
      debugPrint('❌ Error updating FCM token: $e');
      return false;
    }
  }

  /// Main function: Setup user for weather notifications
  /// Saves user location and FCM token to Firestore
  Future<bool> setupUserForWeatherNotifications() async {
    try {
      // 1. Get current user
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('❌ User not logged in');
        return false;
      }

      debugPrint('👤 Setting up weather notifications for: ${user.email}');

      // 2. Get FCM token
      final fcmToken = await _messaging.getToken();
      if (fcmToken == null) {
        debugPrint('❌ Could not get FCM token');
        return false;
      }

      debugPrint('🔔 FCM Token obtained: ${fcmToken.substring(0, 20)}...');

      // 3. Get current location
      final position = await getCurrentLocation();
      if (position == null) {
        debugPrint('⚠️ Could not get location, using default (Delhi)');
        // Still save user with default location
        await _saveUserToFirestore(
          userId: user.uid,
          fcmToken: fcmToken,
          userName: user.displayName,
          userEmail: user.email,
          latitude: 28.6139, // Delhi default
          longitude: 77.2090,
          locationInfo: {
            'name': 'Delhi',
            'city': 'Delhi',
            'state': 'Delhi',
            'country': 'India',
          },
        );
        return true;
      }

      // 4. Reverse geocode to get city name
      final locationInfo = await getCityFromCoordinates(
        position.latitude,
        position.longitude,
      );

      // 5. Save to Firestore
      await _saveUserToFirestore(
        userId: user.uid,
        fcmToken: fcmToken,
        userName: user.displayName,
        userEmail: user.email,
        latitude: position.latitude,
        longitude: position.longitude,
        locationInfo: locationInfo,
      );

      debugPrint('✅ User setup complete for weather notifications!');
      debugPrint('📍 Location: ${locationInfo['name']}');
      debugPrint('🌤️ You will receive weather forecasts for this location');
      
      return true;
      
    } catch (e) {
      debugPrint('❌ Error setting up user: $e');
      return false;
    }
  }

  /// Save user data to Firestore
  Future<void> _saveUserToFirestore({
    required String userId,
    required String fcmToken,
    required String? userName,
    required String? userEmail,
    required double latitude,
    required double longitude,
    required Map<String, String?> locationInfo,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).set({
        'fcmToken': fcmToken,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'name': locationInfo['name'],
          'city': locationInfo['city'],
          'state': locationInfo['state'],
          'country': locationInfo['country'],
        },
        'name': userName ?? 'User',
        'email': userEmail,
        'preferences': {
          'notifications': true,
          'weatherAlerts': true,
        },
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('✅ User data saved to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving to Firestore: $e');
      rethrow;
    }
  }

  /// Update user location (call when user manually updates location)
  Future<bool> updateUserLocation() async {
    debugPrint('🔄 Updating user location...');
    return await setupUserForWeatherNotifications();
  }

  /// Get FCM token for debugging
  Future<String?> getFCMToken() async {
    try {
      final token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
      return token;
    } catch (e) {
      debugPrint('❌ Error getting FCM token: $e');
      return null;
    }
  }

  /// Print FCM token to console (for manual testing)
  Future<void> printFCMToken() async {
    final token = await _messaging.getToken();
    debugPrint('=================================');
    debugPrint('FCM TOKEN:');
    debugPrint(token ?? 'NULL');
    debugPrint('=================================');
  }

  /// Check if user is setup for weather notifications
  Future<bool> isUserSetup() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!doc.exists) return false;
      
      final data = doc.data();
      final hasToken = data?['fcmToken'] != null;
      final hasLocation = data?['location'] != null;
      
      return hasToken && hasLocation;
    } catch (e) {
      debugPrint('❌ Error checking user setup: $e');
      return false;
    }
  }

  /// Get user's saved location info
  Future<Map<String, dynamic>?> getUserLocation() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!doc.exists) return null;
      
      return doc.data()?['location'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('❌ Error getting user location: $e');
      return null;
    }
  }

  /// Disable weather notifications for user
  Future<bool> disableWeatherNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).update({
        'preferences.notifications': false,
        'preferences.weatherAlerts': false,
      });

      debugPrint('✅ Weather notifications disabled');
      return true;
    } catch (e) {
      debugPrint('❌ Error disabling notifications: $e');
      return false;
    }
  }

  /// Enable weather notifications for user
  Future<bool> enableWeatherNotifications() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      await _firestore.collection('users').doc(user.uid).update({
        'preferences.notifications': true,
        'preferences.weatherAlerts': true,
      });

      debugPrint('✅ Weather notifications enabled');
      return true;
    } catch (e) {
      debugPrint('❌ Error enabling notifications: $e');
      return false;
    }
  }
}
