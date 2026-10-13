import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DevAuthProfile {
  final String uid;
  final String email;
  final String displayName;
  final bool isOffline;
  final DateTime createdAt;

  const DevAuthProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.isOffline,
    required this.createdAt,
  });
}

/// Development utility for creating test accounts
/// Use this to bypass Google Sign-in issues on emulator
class DevAuthHelper {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static bool _offlineMode = false;
  static DevAuthProfile? _offlineProfile;

  static bool get isOffline => _offlineMode;
  static DevAuthProfile? get offlineProfile => _offlineProfile;

  /// Create a test account for development
  static Future<UserCredential?> createTestAccount({
    String email = 'test@terafarm.dev',
    String password = 'test123456',
    String displayName = 'Test Farmer',
  }) async {
    try {
      // Try to sign in first
      try {
        final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        print('✅ Test account signed in: $email');
        return userCredential;
      } catch (e) {
        // Account doesn't exist, create it
        print('📝 Creating test account: $email');
      }

      // Create new account
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update display name
      await userCredential.user?.updateDisplayName(displayName);

      // Create user profile in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'email': email,
        'displayName': displayName,
        'provider': 'email',
        'createdAt': FieldValue.serverTimestamp(),
        'isTestAccount': true,
        'profileComplete': false,
      });

      print('✅ Test account created: $email');
      return userCredential;
      
    } catch (e) {
      print('❌ Error creating test account: $e');

      if (e is FirebaseAuthException && e.code == 'network-request-failed') {
        _enableOfflineProfile(
          email: email,
          displayName: displayName,
        );
        return null;
      }

      rethrow;
    }
  }

  /// Quick test accounts for different scenarios
  static Future<UserCredential?> signInAsFarmer() async {
    return await createTestAccount(
      email: 'farmer@terafarm.dev',
      password: 'farmer123',
      displayName: 'Test Farmer',
    );
  }

  static Future<UserCredential?> signInAsBuyer() async {
    return await createTestAccount(
      email: 'buyer@terafarm.dev',
      password: 'buyer123',
      displayName: 'Test Buyer',
    );
  }

  static Future<UserCredential?> signInAsAdmin() async {
    return await createTestAccount(
      email: 'admin@terafarm.dev',
      password: 'admin123',
      displayName: 'Test Admin',
    );
  }

  /// Sign out
  static Future<void> signOut() async {
    await _auth.signOut();
    print('🚪 Signed out');
    _offlineMode = false;
    _offlineProfile = null;
  }

  /// Check if current user is a test account
  static bool isTestAccount(User? user) {
    if (user == null) return false;
    return user.email?.endsWith('@terafarm.dev') ?? false;
  }

  static void _enableOfflineProfile({
    required String email,
    required String displayName,
  }) {
    _offlineMode = true;
    _offlineProfile = DevAuthProfile(
      uid: 'offline-${Random().nextInt(999999).toString().padLeft(6, '0')}',
      email: email,
      displayName: displayName,
      isOffline: true,
      createdAt: DateTime.now(),
    );

    print('🛟 Offline dev profile enabled for $email');
  }
}
