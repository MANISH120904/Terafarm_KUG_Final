import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart' as latLong;

import 'location.dart';
import 'Product_page.dart';
import 'menu_page.dart';
import 'address_map_picker.dart';
import 'l10n/app_localizations.dart';
import 'utils/farm_distance.dart';
import 'widgets/mode_language_bar.dart';
import 'widgets/tera_farm_hub_app_bar.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userAddress = '';
  double _radiusKm = 5;

  // Default India (Chennai) — never SF.
  static const _fallback = latLong.LatLng(13.0827, 80.2707);

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF475D27),
        statusBarIconBrightness: Brightness.light,
      ),
    );
    LocationService().addListener(_onSharedLocation);
    final cached = LocationService().currentAddress;
    if (cached != null && cached.isNotEmpty) {
      _userAddress = cached;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchUserLocation());
  }

  @override
  void dispose() {
    LocationService().removeListener(_onSharedLocation);
    super.dispose();
  }

  void _onSharedLocation() {
    if (!mounted) return;
    final addr = LocationService().currentAddress;
    if (addr != null && addr.isNotEmpty && addr != _userAddress) {
      setState(() => _userAddress = addr);
    }
  }

  Future<void> _fetchUserLocation() async {
    final loc = AppLocalizations.of(context)!;
    try {
      // Prefer saved / already-confirmed location (Buyer↔Farmer share it).
      await LocationService().ensureLocation();
      final addr = LocationService().currentAddress ?? '';
      if (!mounted) return;
      setState(() {
        _userAddress =
            addr.isNotEmpty ? addr : loc.unableFetchLocation;
      });
      await LocationService().saveToFirestore();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _userAddress = LocationService().currentAddress?.isNotEmpty == true
            ? LocationService().currentAddress!
            : loc.unableFetchLocation;
      });
    }
  }

  Future<void> _chooseMapLocation() async {
    final pos = LocationService().currentPosition;
    final initial = pos != null
        ? latLong.LatLng(pos.latitude, pos.longitude)
        : _fallback;

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => AddressMapPicker(initialLocation: initial),
      ),
    );

    if (result != null) {
      final newAddr = result['address'] as String;
      final lat = result['lat'] as double;
      final lng = result['lng'] as double;
      LocationService().setManualLocation(newAddr, lat, lng);
      await LocationService().saveToFirestore();
      if (mounted) setState(() => _userAddress = newAddr);
    }
  }

  void _onFarmSelected(DocumentSnapshot farmDoc) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductPage(farmId: farmDoc.id)),
    );
  }

  Widget _buildLocationWidget(AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on, color: Color(0xFF22C55E), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _userAddress.isNotEmpty ? _userAddress : loc.fetchingLocation,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _chooseMapLocation(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.map, color: Color(0xFF22C55E), size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Color(0xFF407944),
        statusBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        drawer: const MenuPage(),
        body: SafeArea(
          child: Column(
            children: [
              TeraFarmHubAppBar(
                title: loc.appTitle,
                subtitle: loc.welcomeTo,
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildLocationWidget(loc),
                      const SizedBox(height: 16),

                      ModeLanguageBar.buyerStyle(isSellerMode: false),

                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF22C55E).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.store,
                                color: Color(0xFF22C55E),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                loc.buyDirect,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  letterSpacing: 0.2,
                                  height: 1.4,
                                  fontFamily: null, // Use system default font for better Tamil rendering
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.visible,
                                softWrap: true,
                                textAlign: TextAlign.start,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildRadiusFilter(),
                      const SizedBox(height: 8),

                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('farms')
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (ctx, snap) {
                          if (!snap.hasData) {
                            return const Padding(
                              padding: EdgeInsets.only(top: 20),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final docs = snap.data!.docs;
                          if (docs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(loc.noFarms),
                            );
                          }
                          final nearby = farmsWithinRadius(
                            docs: docs,
                            radiusKm: _radiusKm,
                          );
                          if (LocationService().currentPosition == null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                'Set your location above to see nearby farms.',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            );
                          }
                          if (nearby.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 20),
                              child: Text(
                                'No farms within ${_radiusKm.round()} km. Increase the radius to search farther.',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: nearby.length,
                            itemBuilder: (ctx, i) => _buildFarmCard(
                              nearby[i].doc,
                              loc,
                              distanceKm: nearby[i].distanceKm,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadiusFilter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, size: 18, color: Color(0xFF22C55E)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Farms within ${_radiusKm.round()} km',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '5–100 km',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          Slider(
            value: _radiusKm,
            min: 5,
            max: 100,
            divisions: 19,
            label: '${_radiusKm.round()} km',
            activeColor: const Color(0xFF22C55E),
            onChanged: (v) => setState(() => _radiusKm = v),
          ),
        ],
      ),
    );
  }

  Widget _buildFarmCard(
    DocumentSnapshot doc,
    AppLocalizations loc, {
    double? distanceKm,
  }) {
    final farm = doc.data()! as Map<String, dynamic>;
    final name    = farm['farmName']        ?? loc.unnamedFarm;
    final desc    = farm['farmDescription'] ?? loc.noDescription;
    final image   = farm['imageUrl']        ?? 'assets/sample_farm.png';
    final scale   = farm['scale']           ?? 'N/A';
    final rating  = farm['rating']          ?? 4.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onFarmSelected(doc),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.withOpacity(0.1),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Stack(
                    children: [
                      image.startsWith('assets/')
                          ? Image.asset(image, height: 180, width: double.infinity, fit: BoxFit.cover)
                          : Image.network(image, height: 180, width: double.infinity, fit: BoxFit.cover),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                rating.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.agriculture,
                            color: Color(0xFF22C55E),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (distanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF22C55E).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              formatDistanceKm(distanceKm),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      desc,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF22C55E).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.straighten,
                            size: 16,
                            color: Color(0xFF22C55E),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${loc.scaleLabel}: $scale',
                            style: const TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
