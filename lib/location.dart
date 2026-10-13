// location_service.dart
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class LocationService {
  // Singleton pattern so this service is accessible globally.
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  String? currentAddress;
  Position? currentPosition;

  /// Determines the current position of the device with high accuracy.
  Future<void> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled. Please enable location services and try again.');
    }

    // Check current permission status.
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission if not yet granted.
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      throw Exception('Location permissions are permanently denied. Please enable them from settings.');
    }

    // At this point, permissions are granted and we can fetch location.
    currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Fetch a human-readable address using OpenRouteService.
    await _getAddressFromCoordinates(currentPosition!);
  }

  /// Uses OpenRouteService to convert coordinates into a human-readable address.
  Future<void> _getAddressFromCoordinates(Position position) async {
    final apiKey = '5b3ce3597851110001cf624864d0a9022ccf426585696672ccf66652'; // Replace with your valid API key
    final url =
        'https://api.openrouteservice.org/geocode/reverse?api_key=$apiKey'
        '&point.lat=${position.latitude}&point.lon=${position.longitude}&size=1';

    // Optionally print to debug.
    print('Fetching reverse geocode for: lat: ${position.latitude}, lon: ${position.longitude}');
    
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['features'] != null && data['features'].isNotEmpty) {
        final properties = data['features'][0]['properties'];
        // Try a more specific field if available; otherwise, use the label.
        currentAddress = properties['locality'] ?? properties['label'] ?? 'Unknown location';
        print('Location resolved to: $currentAddress');
      }
    } else {
      print('Error fetching address: ${response.statusCode}');
    }
  }
}