// lib/address_map_picker.dart
// Free map picker: OSM tiles + Photon (primary) / Nominatim (fallback).
// Biased to India and the user's current map area for better accuracy.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class AddressMapPicker extends StatefulWidget {
  final LatLng initialLocation;

  const AddressMapPicker({Key? key, required this.initialLocation})
      : super(key: key);

  @override
  _AddressMapPickerState createState() => _AddressMapPickerState();
}

class _AddressMapPickerState extends State<AddressMapPicker> {
  static const _userAgent = 'TeraFarm/1.0 (farm location picker; contact@terafarm.app)';

  final MapController _mapController = MapController();
  late LatLng _selectedLocation;
  String _selectedAddress = '';
  bool _isLoading = false;

  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  Timer? _tapGeocodeDebounce;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    // Prefill address for the starting pin.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reverseGeocode());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _tapGeocodeDebounce?.cancel();
    super.dispose();
  }

  Map<String, String> get _httpHeaders => {
        'User-Agent': _userAgent,
        // English only — `hi` caused Hindi labels on first login / map pick.
        'Accept-Language': 'en',
      };

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (query.trim().length >= 2) {
        _searchPlaces(query.trim());
      } else {
        setState(() => _searchResults.clear());
      }
    });
  }

  /// ~0.4° box (~40km) around current selection to bias local results.
  String _viewboxAround(LatLng c, {double delta = 0.35}) {
    final minLon = c.longitude - delta;
    final maxLon = c.longitude + delta;
    final minLat = c.latitude - delta;
    final maxLat = c.latitude + delta;
    // Nominatim viewbox: left,top,right,bottom
    return '$minLon,$maxLat,$maxLon,$minLat';
  }

  String _formatFromParts({
    String? name,
    String? house,
    String? road,
    String? neighbourhood,
    String? suburb,
    String? village,
    String? town,
    String? city,
    String? county,
    String? stateDistrict,
    String? state,
    String? postcode,
    String? country,
    String? fallback,
  }) {
    final locality = [
      neighbourhood,
      suburb,
      village,
      town,
      city,
      county,
      stateDistrict,
    ].where((e) => e != null && e.trim().isNotEmpty).map((e) => e!.trim()).toList();

    final parts = <String>[];
    if (name != null && name.trim().isNotEmpty) parts.add(name.trim());
    final streetBits = [house, road]
        .where((e) => e != null && e.trim().isNotEmpty)
        .map((e) => e!.trim())
        .toList();
    if (streetBits.isNotEmpty) parts.add(streetBits.join(' '));
    // Keep first 2 unique locality levels to avoid huge strings.
    final seen = <String>{};
    for (final loc in locality) {
      final key = loc.toLowerCase();
      if (seen.add(key)) parts.add(loc);
      if (seen.length >= 2) break;
    }
    if (state != null && state.trim().isNotEmpty) parts.add(state.trim());
    if (postcode != null && postcode.trim().isNotEmpty) parts.add(postcode.trim());
    if (country != null && country.trim().isNotEmpty) parts.add(country.trim());

    final formatted = parts.join(', ');
    if (formatted.isNotEmpty) return formatted;
    return fallback?.trim().isNotEmpty == true
        ? fallback!.trim()
        : '${_selectedLocation.latitude.toStringAsFixed(6)}, ${_selectedLocation.longitude.toStringAsFixed(6)}';
  }

  String _enrichIndiaQuery(String query) {
    final q = query.trim();
    final lower = q.toLowerCase();
    if (lower.contains('india') ||
        lower.contains('chennai') ||
        lower.contains('tamil') ||
        lower.contains('kolathur') ||
        lower.contains('hyderabad') ||
        lower.contains('bengaluru') ||
        lower.contains('bangalore') ||
        lower.contains('mumbai') ||
        lower.contains('delhi')) {
      return q;
    }
    // Bias typo-prone local searches toward India.
    return '$q, India';
  }

  Future<void> _searchPlaces(String query, {bool autoSelectFirst = false}) async {
    setState(() => _isSearching = true);
    try {
      final enriched = _enrichIndiaQuery(query);
      var results = await _searchNominatim(enriched);
      if (results.isEmpty) {
        results = await _searchPhoton(enriched);
      }
      if (results.isEmpty && enriched != query.trim()) {
        results = await _searchNominatim(query.trim());
      }
      if (!mounted) return;
      setState(() => _searchResults = results);
      if (results.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No places found. Try a fuller address (area, city).'),
            duration: Duration(seconds: 2),
          ),
        );
      } else if (autoSelectFirst && results.isNotEmpty) {
        _selectSearchResult(results.first, refineAddress: false);
      }
    } catch (_) {
      if (mounted) setState(() => _searchResults.clear());
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<List<Map<String, dynamic>>> _searchPhoton(String query) async {
    final url = Uri.https('photon.komoot.io', '/api/', {
      'q': query,
      'lat': '${_selectedLocation.latitude}',
      'lon': '${_selectedLocation.longitude}',
      'limit': '10',
      'lang': 'en',
      'bbox': '68.1,6.5,97.4,35.5', // India-ish
    });
    final response = await http.get(url, headers: _httpHeaders).timeout(
          const Duration(seconds: 8),
        );
    if (response.statusCode != 200) return [];

    final data = json.decode(response.body) as Map<String, dynamic>;
    final features = (data['features'] as List?) ?? [];
    final mapped = <Map<String, dynamic>>[];

    for (final f in features) {
      final feature = f as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>?;
      final props = feature['properties'] as Map<String, dynamic>? ?? {};
      final coords = geometry?['coordinates'] as List?;
      if (coords == null || coords.length < 2) continue;

      final lng = (coords[0] as num).toDouble();
      final lat = (coords[1] as num).toDouble();
      final name = (props['name'] as String?)?.trim();
      final address = _formatFromParts(
        name: name,
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
        fallback: name,
      );

      // Soft-prefer India / nearby results.
      final country = (props['country'] as String?)?.toLowerCase() ?? '';
      final countryCode = (props['countrycode'] as String?)?.toLowerCase() ?? '';
      final dist = _haversineKm(_selectedLocation, LatLng(lat, lng));
      var score = 0.0;
      if (countryCode == 'in' || country.contains('india')) score += 50;
      score += math.max(0, 40 - dist); // closer = better

      mapped.add({
        'name': (name != null && name.isNotEmpty) ? name : address.split(',').first,
        'address': address,
        'lat': lat,
        'lng': lng,
        'score': score,
      });
    }

    mapped.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    return mapped.take(8).toList();
  }

  Future<List<Map<String, dynamic>>> _searchNominatim(String query) async {
    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'jsonv2',
      'addressdetails': '1',
      'limit': '8',
      'countrycodes': 'in',
      'viewbox': _viewboxAround(_selectedLocation),
      'bounded': '0', // prefer nearby, don't hard-lock
      'dedupe': '1',
    });
    final response = await http.get(url, headers: _httpHeaders).timeout(
          const Duration(seconds: 8),
        );
    if (response.statusCode != 200) return [];

    final results = json.decode(response.body) as List;
    return results.map((result) {
      final r = result as Map<String, dynamic>;
      final addr = (r['address'] as Map<String, dynamic>?) ?? {};
      final display = (r['display_name'] as String?) ?? '';
      final name = (r['name'] as String?)?.trim();
      final address = _formatFromParts(
        name: name,
        house: addr['house_number']?.toString(),
        road: addr['road']?.toString() ?? addr['pedestrian']?.toString(),
        neighbourhood: addr['neighbourhood']?.toString() ?? addr['suburb']?.toString(),
        village: addr['village']?.toString(),
        town: addr['town']?.toString(),
        city: addr['city']?.toString() ?? addr['municipality']?.toString(),
        county: addr['county']?.toString(),
        stateDistrict: addr['state_district']?.toString(),
        state: addr['state']?.toString(),
        postcode: addr['postcode']?.toString(),
        country: addr['country']?.toString(),
        fallback: display,
      );
      return {
        'name': (name != null && name.isNotEmpty)
            ? name
            : address.split(',').first.trim(),
        'address': address,
        'lat': double.tryParse('${r['lat']}') ?? 0.0,
        'lng': double.tryParse('${r['lon']}') ?? 0.0,
      };
    }).toList();
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.latitude - a.latitude);
    final dLon = _rad(b.longitude - a.longitude);
    final la1 = _rad(a.latitude);
    final la2 = _rad(b.latitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(la1) * math.cos(la2) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(h));
  }

  double _rad(double deg) => deg * math.pi / 180.0;

  void _selectSearchResult(
    Map<String, dynamic> result, {
    bool refineAddress = false,
  }) {
    final lat = result['lat'] as double;
    final lng = result['lng'] as double;

    setState(() {
      _selectedLocation = LatLng(lat, lng);
      _selectedAddress = result['address'] as String;
      _searchResults.clear();
      _searchController.clear();
    });

    try {
      _mapController.move(_selectedLocation, 17.5);
    } catch (_) {}

    // Don't reverse-geocode after search — nearby POIs overwrite the match
    // (e.g. searched Kolathur → showed a clinic next door).
    if (refineAddress) {
      _reverseGeocode();
    }
  }

  void _onTap(TapPosition tapPosition, LatLng latlng) {
    setState(() {
      _selectedLocation = latlng;
      _selectedAddress = '';
    });
    _tapGeocodeDebounce?.cancel();
    _tapGeocodeDebounce = Timer(const Duration(milliseconds: 400), () {
      _reverseGeocode();
    });
  }

  Future<void> _reverseGeocode() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      var address = await _reversePhoton();
      address ??= await _reverseNominatim();
      if (!mounted) return;
      setState(() {
        _selectedAddress = address ??
            '${_selectedLocation.latitude.toStringAsFixed(6)}, '
                '${_selectedLocation.longitude.toStringAsFixed(6)}';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedAddress =
            '${_selectedLocation.latitude.toStringAsFixed(6)}, '
            '${_selectedLocation.longitude.toStringAsFixed(6)}';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String?> _reversePhoton() async {
    final url = Uri.https('photon.komoot.io', '/reverse', {
      'lat': '${_selectedLocation.latitude}',
      'lon': '${_selectedLocation.longitude}',
      'lang': 'en',
    });
    final response = await http.get(url, headers: _httpHeaders).timeout(
          const Duration(seconds: 8),
        );
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    final features = (data['features'] as List?) ?? [];
    if (features.isEmpty) return null;
    final props =
        (features.first as Map<String, dynamic>)['properties'] as Map<String, dynamic>? ??
            {};
    return _formatFromParts(
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
  }

  Future<String?> _reverseNominatim() async {
    final url = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '${_selectedLocation.latitude}',
      'lon': '${_selectedLocation.longitude}',
      'format': 'jsonv2',
      'addressdetails': '1',
      'zoom': '18', // building/street level
      'namedetails': '1',
    });
    final response = await http.get(url, headers: _httpHeaders).timeout(
          const Duration(seconds: 8),
        );
    if (response.statusCode != 200) return null;
    final data = json.decode(response.body) as Map<String, dynamic>;
    final addr = (data['address'] as Map<String, dynamic>?) ?? {};
    return _formatFromParts(
      name: data['name']?.toString(),
      house: addr['house_number']?.toString(),
      road: addr['road']?.toString() ?? addr['pedestrian']?.toString(),
      neighbourhood: addr['neighbourhood']?.toString() ?? addr['suburb']?.toString(),
      village: addr['village']?.toString(),
      town: addr['town']?.toString(),
      city: addr['city']?.toString() ?? addr['municipality']?.toString(),
      county: addr['county']?.toString(),
      stateDistrict: addr['state_district']?.toString(),
      state: addr['state']?.toString(),
      postcode: addr['postcode']?.toString(),
      country: addr['country']?.toString(),
      fallback: data['display_name']?.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 112,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/top_bar.png'),
                  fit: BoxFit.cover,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.only(top: 8, bottom: 2, left: 24, right: 24),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Pick an Address',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF5F7F3), Color(0xFFECF1E8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Search area, street, landmark...',
                        prefixIcon: const Icon(Icons.search, color: Colors.green),
                        suffixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.green,
                                  ),
                                ),
                              )
                            : (_searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.green),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchResults.clear());
                                    },
                                  )
                                : null),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.8),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (q) {
                        if (q.trim().length >= 2) {
                          _searchPlaces(q.trim(), autoSelectFirst: true);
                        }
                      },
                    ),
                    if (_searchResults.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final result = _searchResults[index];
                            return ListTile(
                              dense: true,
                              leading: const Icon(
                                Icons.location_on,
                                color: Colors.green,
                                size: 18,
                              ),
                              title: Text(
                                result['name'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                result['address'] as String,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _selectSearchResult(result),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: widget.initialLocation,
                      initialZoom: 16,
                      maxZoom: 19,
                      minZoom: 4,
                      onTap: _onTap,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.terafarm2',
                        maxNativeZoom: 19,
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _selectedLocation,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECF1E8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: _isLoading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.green,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text('Getting precise address...'),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedAddress.isNotEmpty
                                ? _selectedAddress
                                : 'Tap the map or search, then fine-tune the pin',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_selectedLocation.latitude.toStringAsFixed(6)}, '
                            '${_selectedLocation.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF246B40),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(45),
                      ),
                      onPressed: _isLoading ? null : _reverseGeocode,
                      child: const Text('Get Address'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F7A3E),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(45),
                      ),
                      onPressed: () async {
                        if (_selectedAddress.isEmpty) {
                          await _reverseGeocode();
                        }
                        if (!mounted) return;
                        Navigator.of(context).pop({
                          'address': _selectedAddress.isNotEmpty
                              ? _selectedAddress
                              : '${_selectedLocation.latitude}, ${_selectedLocation.longitude}',
                          'lat': _selectedLocation.latitude,
                          'lng': _selectedLocation.longitude,
                        });
                      },
                      child: const Text('Confirm'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
