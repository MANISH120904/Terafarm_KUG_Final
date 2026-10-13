import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:latlong2/latlong.dart' as latLong;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

import 'address_map_picker.dart';
import 'location.dart';
import 'home_page.dart';
import 'menu_page.dart';
import 'ai_page.dart';
import 'marketplace.dart';
import 'l10n/app_localizations.dart';
import 'main.dart' show LocaleProvider;
import 'Community_page.dart';
import 'dashboard_page.dart';
import 'plant_growth_analysis_page.dart';
import 'crop_suggestion_page.dart';
import 'list_farm_page.dart';
import 'grow_plant_page.dart';
import 'widgets/weather_widget.dart';

class SellerPage extends StatefulWidget {
  const SellerPage({Key? key}) : super(key: key);

  @override
  _SellerPageState createState() => _SellerPageState();
}

class _SellerPageState extends State<SellerPage> {
  String _userAddress = '';
  late List<Map<String, dynamic>> _languages;
  bool isSeller = true;
  final Color primary = const Color(0xFF246B40);
  final GlobalKey<WeatherWidgetState> _weatherKey = GlobalKey<WeatherWidgetState>();

  @override
  void initState() {
    super.initState();
    _languages = [
      {'name': 'English', 'locale': const Locale('en')},
      {'name': 'हिन्दी', 'locale': const Locale('hi')},
      {'name': 'தமிழ்', 'locale': const Locale('ta')},
      {'name': 'తెలుగు', 'locale': const Locale('te')},
    ];
    
    _updateLocationFromService();
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
    final initial = LocationService().currentPosition != null
        ? latLong.LatLng(
            LocationService().currentPosition!.latitude,
            LocationService().currentPosition!.longitude,
          )
        : latLong.LatLng(37.7749, -122.4194);

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
      await _storeUserLocation(newAddr, lat, lng);
      LocationService().currentAddress = newAddr;
      try {
        LocationService().currentPosition = Position(
          latitude: lat,
          longitude: lng,
          timestamp: DateTime.now(),
          accuracy: 1.0,
          altitude: 0.0,
          heading: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
          altitudeAccuracy: 1.0,
          headingAccuracy: 1.0,
          isMocked: false,
        );
      } catch (_) {
        LocationService().currentPosition = null;
      }
      setState(() => _userAddress = newAddr);
    }
  }

  Widget _buildLocationWidget() {
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

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProv = Provider.of<LocaleProvider>(context);
    return Scaffold(
      drawer: const MenuPage(),
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
                  child: Stack(
                    children: [
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                      Positioned(
                        left: -8,
                        top: 18,
                        child: Builder(
                          builder: (ctx) => IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Location
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildLocationWidget(),
              ),

              const SizedBox(height: 12),

              // Buyer/Farmer toggle + language
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: ToggleButtons(
                          isSelected: [!isSeller, isSeller],
                          borderRadius: BorderRadius.circular(12),
                          fillColor: primary,
                          selectedColor: Colors.white,
                          color: primary,
                          borderColor: primary.withOpacity(0.3),
                          selectedBorderColor: primary,
                          borderWidth: 2,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Text(
                                loc.buyer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              child: Text(
                                loc.farmer,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                          onPressed: (i) {
                            setState(() => isSeller = (i == 1));
                            if (i == 0) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const HomePage()),
                              );
                            }
                          },
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: primary.withOpacity(0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          value: _languages.firstWhere(
                            (lang) =>
                                lang['locale'].languageCode ==
                                localeProv.locale.languageCode,
                            orElse: () => _languages[0],
                          ),
                          icon: Icon(Icons.arrow_drop_down, color: primary, size: 24),
                          style: TextStyle(
                            color: primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          items: _languages.map((lang) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: lang,
                              child: Text(
                                lang['name'],
                                style: TextStyle(
                                  color: primary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (newLang) {
                            if (newLang != null) {
                              localeProv.setLocale(newLang['locale'] as Locale);
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

            // Controls row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 3, // Give more space to weather button
                    child: WeatherWidget(
                      key: _weatherKey,
                      buttonText: loc.getWeather,
                      primaryColor: primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1, // Smaller farm button
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary,
                            primary.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.3),
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ListFarmPage()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.agriculture,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  loc.farm,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1, // Smaller plant button
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            primary,
                            primary.withOpacity(0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.3),
                            blurRadius: 6,
                            spreadRadius: 1,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const GrowPlantPage()),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.eco,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  loc.plant,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Features
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  FeatureCard(title: loc.myFarm),
                  FeatureCard(title: loc.dailyTasks),
                  FeatureCard(title: loc.cropSuggestion),
                  FeatureCard(title: loc.plantAR),
                ],
              ),
            ),

              const SizedBox(height: 20), // Extra space for bottom navigation
            ],
          ),
        ),
      ), // close SafeArea
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: primary,
        unselectedItemColor: Colors.grey,
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MarketplacePage()),
            );
          } else if (i == 2) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AIPage()),
            );
          } else if (i == 3) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CommunityPage()),
            );
          }
        },
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.home), label: loc.home),
          BottomNavigationBarItem(icon: const Icon(Icons.shopping_cart), label: loc.market),
          BottomNavigationBarItem(icon: const Icon(Icons.build), label: loc.tools),
          BottomNavigationBarItem(icon: const Icon(Icons.people), label: loc.community),
        ],
      ),
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
