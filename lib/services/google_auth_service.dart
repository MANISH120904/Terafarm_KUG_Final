import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Google Authentication Service for handling Google Sign-in/Sign-up
class GoogleAuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('🔐 Starting Google Sign-in process...');
      
      // Emulator detection and warning
      if (Platform.isAndroid && kDebugMode) {
        print('⚠️ Running on Android in debug mode');
        print('💡 If on emulator, ensure Google Play Services is updated');
      }
      
      // First, sign out to ensure clean state
      await _googleSignIn.signOut();
      
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print('❌ Google Sign-in was cancelled by user');
        return null; // The user canceled the sign-in
      }

      print('✅ Google user selected: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to obtain Google authentication tokens');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('🔑 Signing in to Firebase with Google credentials...');

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _firebaseAuth.signInWithCredential(credential);
      
      // Create or update user profile in Firestore
      await _createOrUpdateUserProfile(userCredential.user!);
      
      print('✅ Google Sign-in successful for ${userCredential.user?.email}');
      return userCredential;
      
    } on FirebaseAuthException catch (e) {
      print('❌ Firebase Auth error: ${e.code} - ${e.message}');
      
      if (e.code == 'network-request-failed') {
        throw Exception(
          'Network error: Please check your internet connection. '
          'If using emulator, ensure Google Play Services is updated.'
        );
      }
      rethrow;
      
    } catch (error) {
      print('❌ Google Sign-in error: $error');
      
      // Check for common emulator errors
      if (error.toString().contains('NETWORK_ERROR') || 
          error.toString().contains('ApiException: 7')) {
        throw Exception(
          'Google Sign-in failed (Network Error). '
          'This is common on Android emulators. '
          'Please:\n'
          '1. Use a physical device, or\n'
          '2. Update Google Play Services in emulator, or\n'
          '3. Use email/password login instead.'
        );
      }
      
      if (error.toString().contains('PlatformException')) {
        throw Exception(
          'Platform error occurred. Please ensure:\n'
          '1. Google Play Services is installed and updated\n'
          '2. SHA-1 certificate is added to Firebase Console\n'
          '3. google-services.json is up to date'
        );
      }
      
      rethrow;
    }
  }

  /// Sign out from both Firebase and Google
  Future<void> signOut() async {
    try {
      print('🚪 Signing out user...');
      
      // Sign out from Firebase
      await _firebaseAuth.signOut();
      
      // Sign out from Google
      await _googleSignIn.signOut();
      
      print('✅ User signed out successfully');
    } catch (error) {
      print('❌ Sign out error: $error');
      rethrow;
    }
  }

  /// Create or update user profile in Firestore
  Future<void> _createOrUpdateUserProfile(User user) async {
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userRef.get();
      
      final userData = {
        'email': user.email,
        'displayName': user.displayName ?? 'Farmer',
        'photoURL': user.photoURL,
        'provider': 'google',
        'lastLoginAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!userDoc.exists) {
        // Create new user profile
        userData['createdAt'] = FieldValue.serverTimestamp();
        userData['isNewUser'] = true;
        userData['profileComplete'] = false;
        
        print('👤 Creating new user profile for ${user.email}');
      } else {
        // Update existing user profile
        userData['isNewUser'] = false;
        print('👤 Updating existing user profile for ${user.email}');
      }
      
      await userRef.set(userData, SetOptions(merge: true));
      print('✅ User profile saved to Firestore');
      
    } catch (error) {
      print('❌ Error saving user profile: $error');
      // Don't rethrow - profile creation failure shouldn't block authentication
    }
  }

  /// Check if user profile is complete (has farming details)
  Future<bool> isUserProfileComplete(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;
      
      final data = userDoc.data()!;
      return data['profileComplete'] == true;
    } catch (error) {
      print('❌ Error checking profile completeness: $error');
      return false;
    }
  }

  /// Mark user profile as complete
  Future<void> markProfileComplete(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'profileComplete': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ User profile marked as complete');
    } catch (error) {
      print('❌ Error marking profile complete: $error');
    }
  }

  /// Get user profile data
  Future<Map<String, dynamic>?> getUserProfileData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (error) {
      print('❌ Error getting user profile: $error');
      return null;
    }
  }

  /// Delete user account (from both Firebase Auth and Firestore)
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      print('🗑️ Deleting user account: ${user.email}');
      
      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();
      
      // Delete farmer profile if exists
      try {
        await _firestore.collection('farmer_profiles').doc(user.uid).delete();
      } catch (e) {
        print('ℹ️ No farmer profile to delete: $e');
      }
      
      // Sign out from Google first
      await _googleSignIn.signOut();
      
      // Delete the user account
      await user.delete();
      
      print('✅ User account deleted successfully');
    } catch (error) {
      print('❌ Error deleting account: $error');
      rethrow;
    }
  }

  /// Re-authenticate user with Google (required for sensitive operations)
  Future<UserCredential?> reauthenticateWithGoogle() async {
    try {
      print('🔐 Re-authenticating with Google...');
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final user = currentUser;
      if (user == null) {
        throw Exception('No user is currently signed in');
      }

      final userCredential = await user.reauthenticateWithCredential(credential);
      print('✅ Re-authentication successful');
      return userCredential;
      
    } catch (error) {
      print('❌ Re-authentication error: $error');
      rethrow;
    }
  }

  /// Handle authentication errors with user-friendly messages
  String getErrorMessage(dynamic error) {
    if (error.toString().contains('network-request-failed')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (error.toString().contains('user-disabled')) {
      return 'This account has been disabled. Please contact support.';
    } else if (error.toString().contains('operation-not-allowed')) {
      return 'Google Sign-in is not enabled. Please contact support.';
    } else if (error.toString().contains('account-exists-with-different-credential')) {
      return 'An account already exists with the same email but different credentials.';
    } else if (error.toString().contains('credential-already-in-use')) {
      return 'This Google account is already linked to another user.';
    } else if (error.toString().contains('cancelled')) {
      return 'Sign-in was cancelled.';
    } else {
      return 'Authentication failed. Please try again.';
    }
  }
}