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

  /// Load saved Firestore location first; GPS only if nothing saved / weak label.
  Future<void> ensureLocation({bool forceGps = false}) async {
    if (!forceGps &&
        _manualOverride &&
        currentAddress != null &&
        currentAddress!.isNotEmpty &&
        currentPosition != null &&
        !_isWeakAddress(currentAddress!)) {
      return;
    }

    if (!forceGps) {
      final loaded = await loadFromFirestore();
      // Only skip GPS when we have a strong saved address.
      if (loaded) return;
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

      // City-only / Hindi labels — keep coords as seed, force GPS refine.
      if (_isWeakAddress(address) && !_manualOverride) {
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
    // Don't persist coarse city-only labels as the permanent address.
    if (_isWeakAddress(addr)) return;
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

    // Prefer a fresh high-accuracy fix; fall back to last known if needed.
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } catch (e) {
      debugPrint('getCurrentPosition failed, trying last known: $e');
      position = await Geolocator.getLastKnownPosition();
    }
    if (position == null) {
      throw Exception('Unable to get current location.');
    }

    currentPosition = position;
    await _getAddressFromCoordinates(position);
    _manualOverride = false;
    notifyListeners();
  }

  /// Street-level reverse geocode — Photon then Nominatim (not city-only).
  Future<void> _getAddressFromCoordinates(Position position) async {
    final photon = await _reversePhoton(position);
    if (photon != null && !_isWeakAddress(photon)) {
      currentAddress = photon;
      return;
    }

    final nominatim = await _reverseNominatim(position);
    if (nominatim != null && !_isWeakAddress(nominatim)) {
      currentAddress = nominatim;
      return;
    }

    // Prefer the more detailed of the two weak results over bare city.
    final best = _pickBetterLabel(photon, nominatim);
    if (best != null && best.isNotEmpty) {
      currentAddress = best;
      return;
    }

    currentAddress =
        '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
  }

  Future<String?> _reversePhoton(Position position) async {
    try {
      final url = Uri.https('photon.komoot.io', '/reverse', {
        'lat': '${position.latitude}',
        'lon': '${position.longitude}',
        'lang': 'en',
      });
      final response = await http
          .get(url, headers: {
            'User-Agent': _userAgent,
            'Accept-Language': 'en',
          })
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final features = (data['features'] as List?) ?? [];
      if (features.isEmpty) return null;
      final props = (features.first as Map<String, dynamic>)['properties']
              as Map<String, dynamic>? ??
          {};
      return _formatParts(
        name: props['name']?.toString(),
        house: props['housenumber']?.toString(),
        road: props['street']?.toString(),
        neighbourhood: props['district']?.toString(),
        suburb: props['suburb']?.toString(),
        city: props['city']?.toString() ??
            props['town']?.toString() ??
            props['village']?.toString(),
        state: props['state']?.toString(),
        postcode: props['postcode']?.toString(),
        country: props['country']?.toString(),
      );
    } catch (e) {
      debugPrint('Photon reverse failed: $e');
      return null;
    }
  }

  Future<String?> _reverseNominatim(Position position) async {
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
            'Accept-Language': 'en',
          })
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;
      final data = json.decode(response.body) as Map<String, dynamic>;
      final display = (data['display_name'] as String?)?.trim();
      final addr = (data['address'] as Map<String, dynamic>?) ?? {};
      return _formatParts(
        name: data['name']?.toString(),
        house: addr['house_number']?.toString(),
        road: addr['road']?.toString() ??
            addr['pedestrian']?.toString() ??
            addr['residential']?.toString(),
        neighbourhood: addr['neighbourhood']?.toString() ??
            addr['quarter']?.toString() ??
            addr['suburb']?.toString(),
        suburb: addr['suburb']?.toString(),
        city: addr['city']?.toString() ??
            addr['town']?.toString() ??
            addr['village']?.toString() ??
            addr['municipality']?.toString() ??
            addr['city_district']?.toString(),
        stateDistrict: addr['state_district']?.toString(),
        state: addr['state']?.toString(),
        postcode: addr['postcode']?.toString(),
        country: addr['country']?.toString(),
        fallback: display,
      );
    } catch (e) {
      debugPrint('Nominatim reverse failed: $e');
      return null;
    }
  }

  String? _formatParts({
    String? name,
    String? house,
    String? road,
    String? neighbourhood,
    String? suburb,
    String? city,
    String? stateDistrict,
    String? state,
    String? postcode,
    String? country,
    String? fallback,
  }) {
    final parts = <String>[];
    void add(String? v) {
      final t = v?.trim();
      if (t == null || t.isEmpty) return;
      if (_hasNonLatinScript(t)) return;
      if (parts.any((p) => p.toLowerCase() == t.toLowerCase())) return;
      parts.add(t);
    }

    // Street-level first so we never end up with only "Chennai".
    if (house != null && road != null) {
      add('$house $road');
    } else {
      add(house);
      add(road);
    }
    add(name);
    add(neighbourhood);
    add(suburb);
    add(city);
    add(stateDistrict);
    add(state);
    add(postcode);
    // Skip country to keep the chip shorter.

    if (parts.isNotEmpty) return parts.join(', ');
    final fb = fallback?.trim();
    if (fb != null && fb.isNotEmpty && !_hasNonLatinScript(fb)) return fb;
    return null;
  }

  String? _pickBetterLabel(String? a, String? b) {
    if (a == null || a.isEmpty) return b;
    if (b == null || b.isEmpty) return a;
    // More comma-separated parts ≈ more specific.
    final scoreA = a.split(',').length;
    final scoreB = b.split(',').length;
    return scoreA >= scoreB ? a : b;
  }

  /// Major metros — alone or with only state/country they are too coarse.
  static const _coarseCities = {
    'chennai',
    'mumbai',
    'delhi',
    'new delhi',
    'bengaluru',
    'bangalore',
    'hyderabad',
    'kolkata',
    'calcutta',
    'pune',
    'ahmedabad',
    'jaipur',
    'lucknow',
    'coimbatore',
    'madurai',
    'kochi',
  };

  /// City-only / Indic / too-coarse labels that need GPS refine.
  static bool _isWeakAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return true;
    if (_hasNonLatinScript(trimmed)) return true;
    // Bare coordinates — refine when online reverse-geocode is available.
    if (RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$').hasMatch(trimmed)) return true;

    final parts = trimmed
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return true;
    // "Chennai" alone.
    if (parts.length == 1) return true;
    // "Chennai, Tamil Nadu" / "Chennai, India" — still city-level.
    // Keep "Anna Nagar, Chennai" (locality + city) as acceptable.
    if (parts.length == 2 &&
        _coarseCities.contains(parts[0].toLowerCase())) {
      return true;
    }
    return false;
  }

  /// Devanagari / other Indic scripts that look wrong in the English UI.
  static bool _hasNonLatinScript(String text) {
    return RegExp(r'[\u0900-\u097F\u0A80-\u0D7F]').hasMatch(text);
  }
}
