// Shared location for Buyer + Farmer (and map picker).
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService extends ChangeNotifier {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  static const _userAgent =
      'TeraFarm/1.0 (location; contact@terafarm.app)';

  String? currentAddress;
  Position? currentPosition;
  bool _manualOverride = false; // user picked on map — don't clobber with GPS city

  /// Apply a user-confirmed (or loaded) location everywhere.
  void setManualLocation(String address, double lat, double lng) {
    currentAddress = address.trim().isNotEmpty
        ? address.trim()
        : '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
    currentPosition = Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 1.0,
      altitude: 0.0,
      altitudeAccuracy: 1.0,
      heading: 0.0,
      headingAccuracy: 1.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      isMocked: false,
    );
    _manualOverride = true;
    notifyListeners();
  }

  /// Load saved Firestore location first; GPS only if nothing saved.
  Future<void> ensureLocation({bool forceGps = false}) async {
    if (!forceGps &&
        _manualOverride &&
        currentAddress != null &&
        currentAddress!.isNotEmpty &&
        currentPosition != null) {
      return;
    }

    if (!forceGps) {
      final loaded = await loadFromFirestore();
      if (loaded) return;
      if (currentAddress != null &&
          currentAddress!.isNotEmpty &&
          currentPosition != null) {
        return;
      }
    }

    await determinePosition();
  }

  Future<bool> loadFromFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (!doc.exists) return false;
      final data = doc.data();
      final loc = data?['location'];
      if (loc is! Map) return false;
      final address = (loc['address'] as String?)?.trim() ?? '';
      final lat = (loc['latitude'] as num?)?.toDouble();
      final lng = (loc['longitude'] as num?)?.toDouble();
      if (address.isEmpty || lat == null || lng == null) return false;
      // City-only labels from old GPS reverse-geocode — treat as weak.
      final weak = address.split(',').length <= 1 && address.length < 20;
      if (weak && !_manualOverride) {
        // Keep coords if useful, but still try GPS for a better label later.
        currentAddress = address;
        currentPosition = Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 50.0,
          altitude: 0.0,
          altitudeAccuracy: 1.0,
          heading: 0.0,
          headingAccuracy: 1.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          isMocked: false,
        );
        notifyListeners();
        return false; // allow GPS refine
      }
      setManualLocation(address, lat, lng);
      return true;
    } catch (e) {
      debugPrint('loadFromFirestore: $e');
      return false;
    }
  }

  Future<void> saveToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    final pos = currentPosition;
    final addr = currentAddress;
    if (user == null || pos == null || addr == null || addr.isEmpty) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'u_id': user.uid,
      'location': {
        'address': addr,
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> determinePosition() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception(
        'Location services are disabled. Please enable location services and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permissions are permanently denied. Please enable them from settings.',
      );
    }

    currentPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );

    await _getAddressFromCoordinates(currentPosition!);
    _manualOverride = false;
    notifyListeners();
  }

  /// Street-level reverse geocode (Nominatim), not city-only.
  Future<void> _getAddressFromCoordinates(Position position) async {
    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': '${position.latitude}',
        'lon': '${position.longitude}',
        'format': 'jsonv2',
        'addressdetails': '1',
        'zoom': '18',
      });
      final response = await http
          .get(url, headers: {
            'User-Agent': _userAgent,
            'Accept-Language': 'en-IN,en,hi',
          })
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final display = (data['display_name'] as String?)?.trim();
        final addr = (data['address'] as Map<String, dynamic>?) ?? {};
        final parts = <String>[];
        for (final key in [
          'road',
          'pedestrian',
          'neighbourhood',
          'suburb',
          'village',
          'town',
          'city_district',
          'city',
          'state_district',
          'state',
          'postcode',
        ]) {
          final v = addr[key]?.toString().trim();
          if (v != null && v.isNotEmpty && !parts.contains(v)) parts.add(v);
        }
        if (parts.isNotEmpty) {
          currentAddress = parts.join(', ');
        } else if (display != null && display.isNotEmpty) {
          currentAddress = display;
        } else {
          currentAddress =
              '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        }
        return;
      }
    } catch (e) {
      debugPrint('Nominatim reverse failed: $e');
    }

    // Fallback: coordinates only (never city-only ORS locality).
    currentAddress =
        '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
  }
}
