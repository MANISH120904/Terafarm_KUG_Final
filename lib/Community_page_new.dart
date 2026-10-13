import 'package:latlong2/latlong.dart' as latLong;
import 'address_map_picker.dart';
import 'location.dart';
import 'package:geolocator/geolocator.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'seller_page.dart';
import 'ai_page.dart';
import 'marketplace.dart';
import 'colab_page.dart';
import 'forum_page.dart';
import 'leaderboard_page.dart';
import 'home_page.dart';

import 'l10n/app_localizations.dart';
import 'main.dart' show LocaleProvider;

class CommunityPage extends StatefulWidget {
  const CommunityPage({Key? key}) : super(key: key);
  @override
  _CommunityPageState createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  String _userAddress = '';
  bool _isSeller = true;
  late List<Map<String, dynamic>> _languages;

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
    _updateLocation();
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
    final initial = LocationService().currentPosition != null
        ? latLong.LatLng(
            LocationService().currentPosition!.latitude,
            LocationService().currentPosition!.longitude,
          )
        : latLong.LatLng(37.7749, -122.4194);

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
          builder: (_) => AddressMapPicker(initialLocation: initial)),
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
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withOpacity(0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            spreadRadius: 3,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFF246B40).withOpacity(0.12),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF246B40),
                  const Color(0xFF246B40).withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF246B40).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(Icons.location_on, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _userAddress.isNotEmpty
                  ? _userAddress
                  : loc.fetchingLocation,
              style: const TextStyle(
                color: Color(0xFF246B40),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.left,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF246B40).withOpacity(0.1),
                  const Color(0xFF246B40).withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF246B40).withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _chooseMapLocation(),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.map, 
                    color: Color(0xFF246B40), 
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF246B40),
              const Color(0xFF246B40).withOpacity(0.8),
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
            onTap: onTap,
            child: Container(
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
                      _getCommunityIcon(label),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      label,
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
    final primary = const Color(0xFF246B40);

    return Scaffold(
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
              // Toggle + language
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withOpacity(0.95),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: const Color(0xFF246B40).withOpacity(0.1),
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ToggleButtons(
                        isSelected: [_isSeller == false, _isSeller == true],
                        borderRadius: BorderRadius.circular(15),
                        fillColor: const Color(0xFF246B40),
                        selectedColor: Colors.white,
                        color: const Color(0xFF246B40),
                        borderColor: const Color(0xFF246B40).withOpacity(0.3),
                        selectedBorderColor: const Color(0xFF246B40),
                        borderWidth: 2,
                        splashColor: const Color(0xFF246B40).withOpacity(0.1),
                        highlightColor: const Color(0xFF246B40).withOpacity(0.05),
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 18,
                                  color: _isSeller == false ? Colors.white : const Color(0xFF246B40),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loc.buyer,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    letterSpacing: 0.3,
                                    color: _isSeller == false ? Colors.white : const Color(0xFF246B40),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.agriculture_outlined,
                                  size: 18,
                                  color: _isSeller == true ? Colors.white : const Color(0xFF246B40),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  loc.farmer,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    letterSpacing: 0.3,
                                    color: _isSeller == true ? Colors.white : const Color(0xFF246B40),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onPressed: (i) {
                          if (i == 0) {
                            Navigator.pushReplacement(context,
                                MaterialPageRoute(builder: (_) => const HomePage()));
                          } else {
                            setState(() => _isSeller = true);
                          }
                        },
                      ),
                    ),
                    const Spacer(),
                    // language dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.white.withOpacity(0.95),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 12,
                            spreadRadius: 2,
                            offset: const Offset(0, 3),
                          ),
                          BoxShadow(
                            color: const Color(0xFF246B40).withOpacity(0.1),
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF246B40),
                                  const Color(0xFF246B40).withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF246B40).withOpacity(0.3),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.language,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<Map<String, dynamic>>(
                              value: _languages.firstWhere(
                                (lang) => lang['locale'] == localeProv.locale,
                                orElse: () => _languages[0],
                              ),
                              items: _languages.map((lang) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: lang,
                                  child: Text(
                                    lang['name'] as String,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF246B40),
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (newLang) {
                                if (newLang != null) {
                                  localeProv.setLocale(newLang['locale'] as Locale);
                                }
                              },
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF246B40).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Color(0xFF246B40),
                                  size: 16,
                                ),
                              ),
                              style: const TextStyle(
                                color: Color(0xFF246B40),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              dropdownColor: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              elevation: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildButton(loc.collaborate, () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ColabPage()));
                    }),
                    _buildButton(loc.forum, () {
                      Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ForumPage()));
                    }),
                    _buildButton(loc.leaderboard, () {
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LeaderboardPage()));
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 20), // Extra space for bottom navigation
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        currentIndex: 3,
        onTap: (i) {
          switch (i) {
            case 0:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const SellerPage()));
              break;
            case 1:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const MarketplacePage()));
              break;
            case 2:
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const AIPage()));
              break;
            // 3: current
          }
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: loc.home),
          BottomNavigationBarItem(
              icon: const Icon(Icons.shopping_cart), label: loc.market),
          BottomNavigationBarItem(
              icon: const Icon(Icons.build), label: loc.tools),
          BottomNavigationBarItem(
              icon: const Icon(Icons.people), label: loc.community),
        ],
      ),
    );
  }
}
