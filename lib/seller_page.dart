import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart' as latLong;
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'dart:math';

import 'address_map_picker.dart';
import 'location.dart';
import 'menu_page.dart';
import 'l10n/app_localizations.dart';
import 'dashboard_page.dart';
import 'plant_growth_analysis_page.dart';
import 'crop_suggestion_page.dart';
import 'list_farm_page.dart';
import 'grow_plant_page.dart';
import 'widgets/weather_widget.dart';
import 'widgets/mode_language_bar.dart';
import 'widgets/tera_farm_hub_app_bar.dart';
class SellerPage extends StatefulWidget {
  const SellerPage({Key? key}) : super(key: key);

  @override
  _SellerPageState createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> with TickerProviderStateMixin {
  String _userAddress = '';
  bool isSeller = true;
  final Color primary = const Color(0xFF246B40);
  final GlobalKey<WeatherWidgetState> _weatherKey = GlobalKey<WeatherWidgetState>();
  String? _userProfileImage;
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
    
    LocationService().addListener(_onSharedLocation);
    final cached = LocationService().currentAddress;
    if (cached != null && cached.isNotEmpty) {
      _userAddress = cached;
    }
    _syncFromSharedLocation();
    _fetchUserProfile();
  }

  void _startShimmerCycle() {
    // Start the first animation immediately
    _shimmerController.forward().then((_) {
      _shimmerController.reset();
    });
    
    // Set up timer to repeat every 8 seconds (increased for more realistic timing)
    _shimmerTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      _shimmerController.forward().then((_) {
        _shimmerController.reset();
      });
    });
  }

  @override
  void dispose() {
    LocationService().removeListener(_onSharedLocation);
    _shimmerController.dispose();
    _shimmerTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncFromSharedLocation();
  }

  void _syncFromSharedLocation() {
    final latest = LocationService().currentAddress;
    if (latest != null && latest.isNotEmpty && latest != _userAddress) {
      setState(() => _userAddress = latest);
    } else if ((latest == null || latest.isEmpty) && _userAddress.isEmpty) {
      _fetchUserLocation();
    }
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
      await LocationService().ensureLocation();
      final addr = LocationService().currentAddress ?? '';
      if (!mounted) return;
      setState(() => _userAddress =
          addr.isNotEmpty ? addr : loc.unableFetchLocation);
      await LocationService().saveToFirestore();
    } catch (_) {
      if (!mounted) return;
      setState(() => _userAddress = LocationService().currentAddress?.isNotEmpty == true
          ? LocationService().currentAddress!
          : loc.unableFetchLocation);
    }
  }

  Future<void> _fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _userProfileImage = data['profileImage'] as String?;
        });
      }
    } catch (e) {
      // Handle error silently, keep default icon
    }
  }

  Future<void> _chooseMapLocation() async {
    final pos = LocationService().currentPosition;
    final initial = pos != null
        ? latLong.LatLng(pos.latitude, pos.longitude)
        : const latLong.LatLng(13.0827, 80.2707);

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

  Widget _buildLocationWidget() {
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
                  : AppLocalizations.of(context)!.fetchingLocation,
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

  Widget _buildQuickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors[0].withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard(String title, IconData icon, List<Color> colors) {
    // Check if this is the "My Farm" card and we have a profile image
    bool isMyFarm = title == 'My Farm' || title == 'मेरी फ़सल' || title == 'என் பண்ணை' || title == 'నా రైతుపంట';
    bool hasProfileImage = isMyFarm && _userProfileImage != null && _userProfileImage!.isNotEmpty;
    
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          height: 115, // Increased height specifically for Tamil text
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors[0],
                colors[1],
                colors[0].withOpacity(0.9),
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.3),
                colors[1].withOpacity(0.9),
                colors[0],
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
                (_shimmerAnimation.value * 0.1) - 0.05, // Subtle rotation for realism
              ),
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: colors[0].withOpacity(0.4),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
              if (_shimmerAnimation.value > 0.05 && _shimmerAnimation.value < 0.95)
                BoxShadow(
                  color: Colors.white.withOpacity(
                    0.6 * 
                    (1 - ((_shimmerAnimation.value - 0.5).abs() * 2)) *
                    (sin(_shimmerAnimation.value * 3.14159) * 0.5 + 0.5) // Sine wave for smooth intensity
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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
            switch (title) {
              case 'My Farm':
              case 'मेरी फ़सल':
              case 'என் பண்ணை':
              case 'నా రైతుపంట':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
                break;
              case 'Daily Tasks':
              case 'दैनिक कार्य':
              case 'நாள்பட்டுப் பணிகள்':
              case 'దైనందిన పనులు':
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PlantGrowthAnalysisPage()));
                break;
              case 'Crop Suggestion':
              case 'फसल सुझाव':
              case 'பயிர் ஆலோசனை':
              case 'పంట సూచన':
                Navigator.push(context, MaterialPageRoute(builder: (_) => CropSuggestionPage()));
                break;
              case 'Plant AR':
              case 'प्लांट एआर':
              case 'தாவரார்':
              case 'ప్లాంట్ ఏఆర్':
                final uri = Uri.parse('arapp://open?scene=ARScene');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(AppLocalizations.of(context)!.arAppNotInstalled)),
                  );
                }
                break;
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(18), // Increased padding
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center, // Changed to center
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.2 + (_shimmerAnimation.value > 0.15 && _shimmerAnimation.value < 0.85 
                        ? 0.2 * (1 - ((_shimmerAnimation.value - 0.5).abs() * 2)) 
                        : 0.0)
                    ),
                    borderRadius: BorderRadius.circular(12), // Increased border radius
                    boxShadow: [
                      if (_shimmerAnimation.value > 0.15 && _shimmerAnimation.value < 0.85)
                        BoxShadow(
                          color: Colors.white.withOpacity(
                            0.8 * 
                            (1 - ((_shimmerAnimation.value - 0.5).abs() * 2)) *
                            (sin(_shimmerAnimation.value * pi * 2) * 0.3 + 0.7) // Smooth pulsing
                          ),
                          blurRadius: 8 + (_shimmerAnimation.value * 4),
                          spreadRadius: 1,
                          offset: const Offset(0, 0),
                        ),
                      // Subtle colored glow from main card color
                      if (_shimmerAnimation.value > 0.2 && _shimmerAnimation.value < 0.8)
                        BoxShadow(
                          color: colors[0].withOpacity(
                            0.3 * (1 - ((_shimmerAnimation.value - 0.5).abs() * 2))
                          ),
                          blurRadius: 6,
                          spreadRadius: 0,
                          offset: const Offset(1, 1),
                        ),
                    ],
                  ),
                  child: hasProfileImage 
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          _userProfileImage!,
                          width: 22, // Slightly larger
                          height: 22,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              icon,
                              color: Colors.white,
                              size: 22,
                            );
                          },
                        ),
                      )
                    : Icon(
                        icon,
                        color: Colors.white,
                        size: 22, // Slightly larger
                      ),
                ),
                const SizedBox(height: 8), // Reduced spacing for more text room
                // Text with proper container and dynamic sizing
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 1), // Reduced horizontal padding
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate dynamic font size based on text length and available space
                      double baseFontSize = 12;
                      double dynamicFontSize = baseFontSize;
                      
                      // Adjust font size based on text length for different languages
                      if (title.length > 15) {
                        dynamicFontSize = 10; // Smaller for very long text
                      } else if (title.length > 12) {
                        dynamicFontSize = 11; // Medium size for moderately long text
                      }
                      
                      // Special handling for Tamil text which tends to be longer
                      if (title.contains('ஆலோசனை') || title.contains('பணிகள்') || title.contains('பண்ணை') || 
                          title.contains('தாவரார்') || title.contains('மருத்துவர்')) {
                        dynamicFontSize = min(dynamicFontSize, 9.5); // Even smaller for complex Tamil words
                      }
                      
                      return Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: dynamicFontSize,
                          fontWeight: FontWeight.bold,
                          height: 1.0, // Very tight line height to maximize space
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
        );
      },
    );
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

              // Location
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildLocationWidget(),
              ),

              const SizedBox(height: 20),

              // Buyer/Farmer toggle + language (overflow-safe)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ModeLanguageBar(
                  isSellerMode: isSeller,
                  onSellerSelected: (v) => setState(() => isSeller = v),
                ),
              ),

              const SizedBox(height: 24),

            // Quick Actions Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Weather widget
                  WeatherWidget(
                    key: _weatherKey,
                    buttonText: loc.getWeather,
                    primaryColor: const Color(0xFF16A34A),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Quick actions grid
                  Container(
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
                                      const Color(0xFF16A34A),
                                      const Color(0xFF15803D),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.dashboard_customize,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  loc.quickActions,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _buildQuickActionCard(
                                  icon: Icons.agriculture,
                                  title: loc.farm,
                                  subtitle: loc.manageFarms,
                                  colors: [const Color(0xFF16A34A), const Color(0xFF15803D)],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => ListFarmPage()),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildQuickActionCard(
                                  icon: Icons.eco,
                                  title: loc.plant,
                                  subtitle: loc.trackGrowth,
                                  colors: [const Color(0xFF16A34A), const Color(0xFF15803D)],
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const GrowPlantPage()),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Main Features
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        loc.farmFeatures,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Feature cards grid
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildFeatureCard(loc.myFarm, Icons.agriculture, [const Color(0xFF4F7942), const Color(0xFF3D5E33)])),
                          const SizedBox(width: 16), // Increased spacing
                          Expanded(child: _buildFeatureCard(loc.dailyTasks, Icons.task_alt, [const Color(0xFF4F7942), const Color(0xFF3D5E33)])),
                        ],
                      ),
                      const SizedBox(height: 16), // Increased spacing
                      Row(
                        children: [
                          Expanded(child: _buildFeatureCard(loc.cropSuggestion, Icons.lightbulb_outline, [const Color(0xFF4F7942), const Color(0xFF3D5E33)])),
                          const SizedBox(width: 16), // Increased spacing
                          Expanded(child: _buildFeatureCard(loc.plantAR, Icons.view_in_ar, [const Color(0xFF4F7942), const Color(0xFF3D5E33)])),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      ), // close SafeArea
    );
  }
}

class FeatureCard extends StatelessWidget {
  final String title;
  const FeatureCard({required this.title, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF246B40),
              Color(0xFF1E5A36),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF246B40).withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
            onTap: () async {
              switch (title) {
                case 'My Farm':
                case 'मेरी फ़सल':
                case 'என் பண்ணை':
                case 'నా రైతుపంట':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
                  break;
                case 'Daily Tasks':
                case 'दैनिक कार्य':
                case 'நாள்பட்டுப் பணிகள்':
                case 'దైనందిన పనులు':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const PlantGrowthAnalysisPage()));
                  break;
                case 'Crop Suggestion':
                case 'फसल सुझाव':
                case 'பயிர் ஆலோசனை':
                case 'పంట సూచన':
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CropSuggestionPage()));
                  break;
                case 'Plant AR':
                case 'प्लांट एआर':
                case 'தாவரார்':
                case 'ప్లాంట్ ఏఆర్':
                  final uri = Uri.parse('arapp://open?scene=ARScene');
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(AppLocalizations.of(context)!.arAppNotInstalled)),
                    );
                  }
                  break;
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getFeatureIcon(title),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getFeatureIcon(String title) {
    switch (title) {
      case 'My Farm':
      case 'मेरी फ़सल':
      case 'என் பண்ணை':
      case 'నా రైతుపంట':
        return Icons.agriculture;
      case 'Daily Tasks':
      case 'दैनिक कार्य':
      case 'நாள்பட்டுப் பணிகள்':
      case 'దైనందిన పనులు':
        return Icons.task_alt;
      case 'Crop Suggestion':
      case 'फसल सुझाव':
      case 'பயிர் ஆலோசனை':
      case 'పంట సూచన':
        return Icons.lightbulb_outline;
      case 'Plant AR':
      case 'प्लांट एआर':
      case 'தாவரார்':
      case 'ప్లాంట్ ఏఆర్':
        return Icons.view_in_ar;
      default:
        return Icons.eco;
    }
  }
}
