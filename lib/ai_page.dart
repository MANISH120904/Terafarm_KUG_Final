import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart' as lat_long;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'dart:math';

import 'menu_page.dart';
import 'plantcare_page.dart';
import 'teradoc_page.dart';
import 'recommendation_ai_page.dart';
import 'address_map_picker.dart';
import 'location.dart';
import 'sustainable.dart';
import 'l10n/app_localizations.dart';
import 'widgets/mode_language_bar.dart';
import 'widgets/tera_farm_hub_app_bar.dart';

class AIPage extends StatefulWidget {
  const AIPage({Key? key}) : super(key: key);
  @override
  _AIPageState createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> with TickerProviderStateMixin {
  String _userAddress = '';
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  late Timer? _shimmerTimer;

  @override
  void initState() {
    super.initState();
    // Initialize shimmer animation
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOutQuart,
    ));
    
    // Start the shimmer animation cycle
    _startShimmerCycle();
    
    _updateLocationFromService();
  }

  void _startShimmerCycle() {
    // Start the first animation immediately
    _shimmerController.forward().then((_) {
      _shimmerController.reset();
    });
    
    // Set up timer to repeat every 8 seconds
    _shimmerTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      _shimmerController.forward().then((_) {
        _shimmerController.reset();
      });
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _shimmerTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateLocationFromService();
  }

  void _updateLocationFromService() {
    final latest = LocationService().currentAddress;
    if (latest != null && latest.isNotEmpty && latest != _userAddress) {
      setState(() => _userAddress = latest);
    } else if ((latest == null || latest.isEmpty) && _userAddress.isEmpty) {
      _fetchUserLocation();
    }
  }

  Future<void> _fetchUserLocation() async {
    final loc = AppLocalizations.of(context)!;
    try {
      await LocationService().determinePosition();
      final addr = LocationService().currentAddress ?? '';
      setState(() => _userAddress = addr.isNotEmpty
          ? addr
          : loc.fetchingLocation);
      final pos = LocationService().currentPosition;
      if (pos != null) {
        await _storeUserLocation(addr, pos.latitude, pos.longitude);
      }
    } catch (_) {
      setState(() => _userAddress = loc.unableFetchLocation);
    }
  }

  Future<void> _storeUserLocation(
      String address, double lat, double lon) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set({
          'u_id': user.uid,
          'location': {
            'address': address,
            'latitude': lat,
            'longitude': lon,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> _chooseMapLocation() async {
    final pos = LocationService().currentPosition;
    final initial = pos != null
        ? lat_long.LatLng(pos.latitude, pos.longitude)
        : const lat_long.LatLng(13.0827, 80.2707);

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

  Widget _buildLocationWidget(AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFF5F7F3),
            const Color(0xFFECF1E8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade400),
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
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on, color: Colors.green, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _userAddress.isNotEmpty
                  ? _userAddress
                  : loc.fetchingLocation,
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
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _chooseMapLocation(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.map, color: Colors.green, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton(String label, String description, VoidCallback onTap, {String? buttonDescription}) {
    // Update colors to match the green color scheme from your image
    List<Color> buttonColors = [const Color(0xFF4F7942), const Color(0xFF3D5E33)]; // Fern green shades
    
    if (label.toLowerCase().contains('doctor') || label.toLowerCase().contains('à¤¡à¥‰à¤•à¥à¤Ÿà¤°') || 
        label.toLowerCase().contains('à®®à®°à¯à®¤à¯à®¤à¯à®µà®°à¯') || label.toLowerCase().contains('à°µà±ˆà°¦à±à°¯à±à°¡à±')) {
      buttonColors = [const Color(0xFF4F7942), const Color(0xFF3D5E33)]; // Fern green for doctor
    } else if (label.toLowerCase().contains('suggest') || label.toLowerCase().contains('à¤¸à¥à¤à¤¾à¤µ') ||
               label.toLowerCase().contains('à®ªà®°à®¿à®¨à¯à®¤à¯à®°à¯ˆ') || label.toLowerCase().contains('à°¸à±‚à°šà°¨')) {
      buttonColors = [const Color(0xFF2E8B57), const Color(0xFF228B47)]; // Sea green for suggestions
    } else if (label.toLowerCase().contains('care') || label.toLowerCase().contains('à¤¦à¥‡à¤–à¤­à¤¾à¤²') ||
               label.toLowerCase().contains('à®ªà®°à®¾à´®à¤°à¤¿à¤ªà¯à¦ªà¯') || label.toLowerCase().contains('à°¸à°‚à°°à°•à±à°·à°£')) {
      buttonColors = [const Color(0xFF66CDAA), const Color(0xFF5CBAA0)]; // Medium aquamarine for care
    } else if (label.toLowerCase().contains('tips') || label.toLowerCase().contains('à¤Ÿà¤¿à¤ªà¥à¤¸') ||
               label.toLowerCase().contains('à®•à¯à®±à®¿à®ªà¯à®ªà¯à®•à®³à¯') || label.toLowerCase().contains('à°šà°¿à°Ÿà±à°•à°¾à°²à±')) {
      buttonColors = [const Color(0xFF8FBC8F), const Color(0xFF7BA47B)]; // Light sage green for tips
    } else if (label.toLowerCase().contains('rover') || label.toLowerCase().contains('à¤°à¥‹à¤µà¤°') ||
               label.toLowerCase().contains('à®°à¯‹à®µà®°à¯') || label.toLowerCase().contains('à°°à±‹à°µà°°à±')) {
      buttonColors = [const Color(0xFF407944), const Color(0xFF2F5A32)]; // Dark forest green for rover
    }
    
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                buttonColors[0],
                buttonColors[0].withOpacity(0.8),
                buttonColors[0].withOpacity(0.9),
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.3),
                buttonColors[0].withOpacity(0.9),
                buttonColors[1],
              ],
              stops: [
                0.0,
                (_shimmerAnimation.value * 2.0 - 1.0).clamp(0.0, 1.0),
                (_shimmerAnimation.value * 2.0 - 0.7).clamp(0.0, 1.0),
                (_shimmerAnimation.value * 2.0 - 0.5).clamp(0.0, 1.0),
                (_shimmerAnimation.value * 2.0 - 0.3).clamp(0.0, 1.0),
                (_shimmerAnimation.value * 2.0 - 0.1).clamp(0.0, 1.0),
                1.0,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              transform: GradientRotation(
                (_shimmerAnimation.value * 0.1) - 0.05,
              ),
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: buttonColors[0].withOpacity(0.25),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
              if (_shimmerAnimation.value > 0.05 && _shimmerAnimation.value < 0.95)
                BoxShadow(
                  color: Colors.white.withOpacity(
                    0.6 * 
                    (1 - ((_shimmerAnimation.value - 0.5).abs() * 2)) *
                    (sin(_shimmerAnimation.value * 3.14159) * 0.5 + 0.5)
                  ),
                  blurRadius: 12 + (_shimmerAnimation.value * 6),
                  spreadRadius: 2,
                  offset: Offset(
                    -12 + (_shimmerAnimation.value * 24), 
                    -12 + (_shimmerAnimation.value * 24)
                  ),
                ),
              // Additional subtle inner glow
              if (_shimmerAnimation.value > 0.1 && _shimmerAnimation.value < 0.9)
                BoxShadow(
                  color: Colors.white.withOpacity(
                    0.3 * (1 - ((_shimmerAnimation.value - 0.5).abs() * 2))
                  ),
                  blurRadius: 4,
                  spreadRadius: 0,
                  offset: const Offset(0, 0),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(
                    0.22 + (_shimmerAnimation.value > 0.15 && _shimmerAnimation.value < 0.85 
                      ? 0.18 * (1 - ((_shimmerAnimation.value - 0.5).abs() * 2)) 
                      : 0.0)
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    if (_shimmerAnimation.value > 0.15 && _shimmerAnimation.value < 0.85)
                      BoxShadow(
                        color: Colors.white.withOpacity(
                          0.8 * 
                          (1 - ((_shimmerAnimation.value - 0.5).abs() * 2)) *
                          (sin(_shimmerAnimation.value * pi * 2) * 0.3 + 0.7)
                        ),
                        blurRadius: 8 + (_shimmerAnimation.value * 4),
                        spreadRadius: 1,
                        offset: const Offset(0, 0),
                      ),
                    // Subtle colored glow from main button color
                    if (_shimmerAnimation.value > 0.2 && _shimmerAnimation.value < 0.8)
                      BoxShadow(
                        color: buttonColors[0].withOpacity(
                          0.3 * (1 - ((_shimmerAnimation.value - 0.5).abs() * 2))
                        ),
                        blurRadius: 6,
                        spreadRadius: 0,
                        offset: const Offset(1, 1),
                      ),
                  ],
                ),
                child: Icon(
                  _getToolIcon(label),
                  size: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              // Main label text
              Flexible(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double fontSize = 13;
                    if (label.length > 14) {
                      fontSize = 12;
                    }
                    if (label.length > 20) {
                      fontSize = 11;
                    }
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  },
                ),
              ),
              // Description text
              if (buttonDescription != null) ...[
                const SizedBox(height: 4),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      buttonDescription,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        height: 1.15,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }

  IconData _getToolIcon(String label) {
    if (label.toLowerCase().contains('doctor') || label.toLowerCase().contains('à¤¡à¥‰à¤•à¥à¤Ÿà¤°') || 
        label.toLowerCase().contains('à®®à®°à¯à®¤à¯à®¤à¯à®µà®°à¯') || label.toLowerCase().contains('à°µà±ˆà°¦à±à°¯à±à°¡à±')) {
      return Icons.medical_services_outlined;
    } else if (label.toLowerCase().contains('suggest') || label.toLowerCase().contains('à¤¸à¥à¤à¤¾à¤µ') ||
               label.toLowerCase().contains('à®ªà®°à®¿à®¨à¯à®¤à¯à®°à¯ˆ') || label.toLowerCase().contains('à°¸à±‚à°šà°¨')) {
      return Icons.lightbulb_outline;
    } else if (label.toLowerCase().contains('care') || label.toLowerCase().contains('à¤¦à¥‡à¤–à¤­à¤¾à¤²') ||
               label.toLowerCase().contains('à®ªà®°à®¾à®®à®°à®¿à®ªà¯à®ªà¯') || label.toLowerCase().contains('à°¸à°‚à°°à°•à±à°·à°£')) {
      return Icons.favorite_outline;
    } else if (label.toLowerCase().contains('tips') || label.toLowerCase().contains('à¤Ÿà¤¿à¤ªà¥à¤¸') ||
               label.toLowerCase().contains('à®•à¯à®±à®¿à®ªà¯à®ªà¯à®•à®³à¯') || label.toLowerCase().contains('à°šà°¿à°Ÿà±à°•à°¾à°²à±')) {
      return Icons.eco_outlined;
    } else if (label.toLowerCase().contains('rover') || label.toLowerCase().contains('à¤°à¥‹à¤µà¤°') ||
               label.toLowerCase().contains('à®°à¯‹à®µà®°à¯') || label.toLowerCase().contains('à°°à±‹à°µà°°à±')) {
      return Icons.smart_toy_outlined;
    } else if (label.toLowerCase().contains('satellite') || label.toLowerCase().contains('analysis')) {
      return Icons.satellite_alt;
    }
    return Icons.psychology_outlined;
  }

  String _getToolDescription(String label, AppLocalizations loc) {
    if (label.toLowerCase().contains('doctor') || label.toLowerCase().contains('à¤¡à¥‰à¤•à¥à¤Ÿà¤°') || 
        label.toLowerCase().contains('à®®à®°à¯à®¤à¯à®¤à¯à®µà®°à¯') || label.toLowerCase().contains('à°µà±ˆà°¦à±à°¯à±à°¡à±')) {
      return loc.diagnosePlantDiseases;
    } else if (label.toLowerCase().contains('suggest') || label.toLowerCase().contains('à¤¸à¥à¤à¤¾à¤µ') ||
               label.toLowerCase().contains('à®ªà®°à¦¿à®¨à¯à®¤à¯à®°à¯ˆ') || label.toLowerCase().contains('à°¸à±‚à°šà°¨')) {
      return loc.personalizedCropRecommendations;
    } else if (label.toLowerCase().contains('care') || label.toLowerCase().contains('à¤¦à¥‡à¤–à¤­à¤¾à¤²') ||
               label.toLowerCase().contains('à®ªà®°à®¾à®®à¤°à®¿à®ªà¯à®ªà¯') || label.toLowerCase().contains('à°¸à°‚à°°à°•à±à°·à°£')) {
      return loc.smartPlantCareGuidance;
    } else if (label.toLowerCase().contains('tips') || label.toLowerCase().contains('à¤Ÿà¤¿à¤ªà¥à¤¸') ||
               label.toLowerCase().contains('à®•à¯à®±à®¿à®ªà¯à®ªà¯à®•à®³à¯') || label.toLowerCase().contains('à°šà°¿à°Ÿà±à°•à°¾à°²à±')) {
      return loc.sustainableFarmingPractices;
    } else if (label.toLowerCase().contains('rover') || label.toLowerCase().contains('à¤°à¥‹à¤µà¤°') ||
               label.toLowerCase().contains('à®°à¯‹à®µà®°à¯') || label.toLowerCase().contains('à°°à±‹à°µà°°à±')) {
      return loc.controlSmartRovers;
    }
    return loc.aiPoweredFarmingAssistant;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      drawer: const MenuPage(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              TeraFarmHubAppBar(
                title: loc.appTitle,
                subtitle: loc.welcomeTo,
              ),
              const SizedBox(height: 16),
              _buildLocationWidget(loc),
              const SizedBox(height: 20),

              // Buyer/Farmer toggle + language (overflow-safe)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ModeLanguageBar(
                  isSellerMode: true,
                ),
              ),


              const SizedBox(height: 24),

              // AI Tools Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F7F3),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 15,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF8B5CF6),
                                    const Color(0xFF7C3AED),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.psychology,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              loc.aiTools,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          loc.aiPoweredFarmingAssistant,
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 20),
                    
                        // Tool buttons grid (2x2 layout for 4 tools)
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          childAspectRatio: 0.95,
                          children: [
                            _buildToolButton(loc.plantDoctor, _getToolDescription(loc.plantDoctor, loc), () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const TeradocApp()));
                            }, buttonDescription: loc.diagnosePlantDiseases),
                            _buildToolButton(loc.plantSuggest, _getToolDescription(loc.plantSuggest, loc), () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const RecommendationForm()));
                            }, buttonDescription: loc.personalizedCropRecommendations),
                            _buildToolButton(loc.plantCareAI, _getToolDescription(loc.plantCareAI, loc), () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const PlantCareApp()));
                            }, buttonDescription: loc.smartPlantCareGuidance),
                            _buildToolButton(loc.greenTips, _getToolDescription(loc.greenTips, loc), () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SustainablePage()));
                            }, buttonDescription: loc.sustainableFarmingPractices),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

