import 'package:latlong2/latlong.dart' as latLong;
import 'address_map_picker.dart';
import 'location.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';

import 'colab_page.dart';
import 'forum_page.dart';
import 'leaderboard_page.dart';

import 'l10n/app_localizations.dart';
import 'main.dart' show LocaleProvider;
import 'services/navigation_service.dart';
import 'voice_assistance.dart';

class CommunityPage extends StatefulWidget {
  const CommunityPage({Key? key}) : super(key: key);
  @override
  _CommunityPageState createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> with TickerProviderStateMixin {
  String _userAddress = '';
  late List<Map<String, dynamic>> _languages;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  late Timer? _shimmerTimer;

  @override
  void initState() {
    super.initState();
    // Initialize language options for dropdown
    _languages = [
      {'name': 'English', 'locale': const Locale('en')},
      {'name': 'हिन्दी', 'locale': const Locale('hi')},
      {'name': 'தமிழ்', 'locale': const Locale('ta')},
      {'name': 'తెలుగు', 'locale': const Locale('te')},
    ];
    
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
    
    _updateLocation();
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
    _updateLocation();
  }

  void _updateLocation() {
    final latest = LocationService().currentAddress ?? '';
    if (latest != _userAddress) {
      setState(() => _userAddress = latest);
    }
  }

  Future<void> _chooseMapLocation() async {
    final initialLL = LocationService().currentPosition != null
        ? latLong.LatLng(
            LocationService().currentPosition!.latitude,
            LocationService().currentPosition!.longitude,
          )
        : latLong.LatLng(37.7749, -122.4194);

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => AddressMapPicker(initialLocation: initialLL)),
    );
    if (result != null) {
      final newAddr = result['address'] as String;
      LocationService().currentAddress = newAddr;
      setState(() => _userAddress = newAddr);
      // you can update LocationService().currentPosition similarly if you want
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

  Widget _buildButton(String label, VoidCallback onTap, {Color? color, String? description}) {
    // Define colors to match each page's actual theme
    Color buttonColor = const Color(0xFF16A34A); // Default green
    
    if (label.toLowerCase().contains('collaborate') || label.toLowerCase().contains('सहयोग') || 
        label.toLowerCase().contains('ஒத்துழைப்பு') || label.toLowerCase().contains('సహకారం')) {
      buttonColor = const Color(0xFF246B40); // Dark green matching ColaPage
    } else if (label.toLowerCase().contains('forum') || label.toLowerCase().contains('मंच') ||
               label.toLowerCase().contains('மன்றம்') || label.toLowerCase().contains('వేదిక')) {
      buttonColor = const Color(0xFF246B40); // Dark green matching ForumPage
    } else if (label.toLowerCase().contains('leaderboard') || label.toLowerCase().contains('लीडरबोर्ड') ||
               label.toLowerCase().contains('தலைவர் பலகை') || label.toLowerCase().contains('లీడర్‌బోర్డ్')) {
      buttonColor = const Color(0xFF407944); // Dark green matching marketplace features
    }
    
    if (color != null) buttonColor = color;
    
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(
              minHeight: description != null ? 120 : 100,
              maxHeight: description != null ? 140 : 120,
            ),
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  buttonColor,
                  buttonColor.withOpacity(0.8),
                  buttonColor.withOpacity(0.9),
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.3),
                  buttonColor.withOpacity(0.9),
                  buttonColor,
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
                  color: buttonColor.withOpacity(0.25),
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
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(
                      0.2 + (_shimmerAnimation.value > 0.15 && _shimmerAnimation.value < 0.85 
                        ? 0.2 * (1 - ((_shimmerAnimation.value - 0.5).abs() * 2)) 
                        : 0.0)
                    ),
                    borderRadius: BorderRadius.circular(10),
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
                          color: buttonColor.withOpacity(
                            0.3 * (1 - ((_shimmerAnimation.value - 0.5).abs() * 2))
                          ),
                          blurRadius: 6,
                          spreadRadius: 0,
                          offset: const Offset(1, 1),
                        ),
                    ],
                  ),
                  child: Icon(
                    _getCommunityIcon(label),
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Dynamic font size based on available space
                      double fontSize = 14;
                      if (label.length > 12) {
                        fontSize = 12;
                      }
                      if (label.length > 16) {
                        fontSize = 11;
                      }
                      
                      return Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: fontSize,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      );
                    },
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getCommunityIcon(String label) {
    if (label.toLowerCase().contains('collaborate') || label.toLowerCase().contains('सहयोग') || 
        label.toLowerCase().contains('ஒத்துழைப்பு') || label.toLowerCase().contains('సహకారం')) {
      return Icons.handshake_outlined;
    } else if (label.toLowerCase().contains('forum') || label.toLowerCase().contains('मंच') ||
               label.toLowerCase().contains('மன்றம்') || label.toLowerCase().contains('వేదిక')) {
      return Icons.forum_outlined;
    } else if (label.toLowerCase().contains('leaderboard') || label.toLowerCase().contains('लीडरबोर्ड') ||
               label.toLowerCase().contains('தலைவர் பலகை') || label.toLowerCase().contains('లీడర్‌బోర్డ్')) {
      return Icons.leaderboard_outlined;
    }
    return Icons.people_outline;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProv = Provider.of<LocaleProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      floatingActionButton: const VoiceAssistantWidget(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top banner
              Container(
                width: double.infinity,
                height: 112,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                      image: AssetImage('assets/top_bar.png'),
                      fit: BoxFit.cover),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(
                      top: 8, bottom: 2, left: 24, right: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 15),
                      Text(loc.welcomeTo,
                          style:
                              const TextStyle(color: Colors.white, fontSize: 17)),
                      Text(loc.appTitle,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Location
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildLocationWidget(loc),
              ),

              const SizedBox(height: 12),
              // Buyer/Farmer toggle + language chooser
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF16A34A),
                              const Color(0xFF15803D),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  NavigationService.navigateToBuyerSeller(context, false);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        loc.buyer,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  NavigationService.navigateToBuyerSeller(context, true);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0FDF4),
                                    borderRadius: BorderRadius.circular(13),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.agriculture,
                                        size: 16,
                                        color: const Color(0xFF16A34A),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        loc.farmer,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: const Color(0xFF16A34A),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7F3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Map<String, dynamic>>(
                            value: _languages.firstWhere(
                              (lang) =>
                                  (lang['locale'] as Locale).languageCode ==
                                  localeProv.locale.languageCode,
                              orElse: () => _languages[0],
                            ),
                            icon: Icon(Icons.keyboard_arrow_down_rounded, 
                                     color: const Color(0xFF16A34A), size: 20),
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            items: _languages.map((lang) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: lang,
                                child: Text(
                                  lang['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (lang) {
                              if (lang != null) {
                                localeProv.setLocale(lang['locale']);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
              // Community Features Grid
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
                                Icons.people_outline,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              loc.communityFeatures,
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
                          loc.connectCollaborateGrow,
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF6B7280),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 20),
                        GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          childAspectRatio: 0.9, // Slightly reduced to give more height
                          children: [
                            _buildButton(
                              loc.collaborate, 
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ColabPage()),
                                );
                              },
                              description: loc.workTogetherProjects,
                            ),
                            _buildButton(
                              loc.forum, 
                              () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ForumPage()),
                                );
                              },
                              description: loc.discussShareIdeas,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          child: _buildButton(
                            loc.leaderboard, 
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const LeaderboardPage()),
                              );
                            },
                            description: loc.topPerformingFarmers,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20), // Extra space for bottom navigation
            ],
          ),
        ),
      ),
    );
  }
}
