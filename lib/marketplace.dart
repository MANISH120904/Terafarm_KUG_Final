import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart' as latLong;

import 'address_map_picker.dart';
import 'location.dart';
import 'home_page.dart';
import 'order_list_page.dart';
import 'market_price_page.dart';
import 'shop_page.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_locales.dart';
import 'main.dart' show LocaleProvider;
import 'subsidies_page.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({Key? key}) : super(key: key);

  @override
  _MarketplacePageState createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  bool isSeller = true;
  String _userAddress = '';
  final Color primary = const Color(0xFF22C55E);

  late List<Map<String, dynamic>> _languages;

  @override
  void initState() {
    super.initState();
    _languages = List<Map<String, dynamic>>.from(AppLocales.dropdownItems);
    LocationService().addListener(_onSharedLocation);
    final cached = LocationService().currentAddress;
    if (cached != null && cached.isNotEmpty) {
      _userAddress = cached;
    } else {
      _userAddress = 'Fetching location...';
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          await LocationService().ensureLocation();
          await LocationService().saveToFirestore();
        } catch (_) {}
        _onSharedLocation();
      });
    }
  }

  @override
  void dispose() {
    LocationService().removeListener(_onSharedLocation);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _onSharedLocation();
  }

  void _onSharedLocation() {
    if (!mounted) return;
    final latest = LocationService().currentAddress;
    if (latest != null && latest.isNotEmpty && latest != _userAddress) {
      setState(() => _userAddress = latest);
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
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFF5F7F3), const Color(0xFFECF1E8)],
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

  Widget _buildFullWidthButton(String label, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF407944), const Color(0xFF2F5A32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF407944).withOpacity(0.25),
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
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
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
                    _getButtonIcon(label),
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
    );
  }

  IconData _getButtonIcon(String label) {
    final lowerLabel = label.toLowerCase();
    if (lowerLabel.contains('order') ||
        lowerLabel.contains('à¤‘à¤°à¥à¤¡à¤°') ||
        lowerLabel.contains('à®†à®°à¯à®Ÿà®°à¯') ||
        lowerLabel.contains('à°†à°°à±à°¡à°°à±')) {
      return Icons.shopping_bag_outlined;
    } else if (lowerLabel.contains('market') ||
        lowerLabel.contains('à¤¬à¤¾à¤œà¤¼à¤¾à¤°') ||
        lowerLabel.contains('à®šà®¨à¯à®¤à¯ˆ') ||
        lowerLabel.contains('à°®à°¾à°°à±à°•à±†à°Ÿà±')) {
      return Icons.trending_up;
    } else if (lowerLabel.contains('shop') ||
        lowerLabel.contains('à¤¦à¥à¤•à¤¾à¤¨') ||
        lowerLabel.contains('à®•à®Ÿà¯ˆ') ||
        lowerLabel.contains('à°¦à±à°•à°¾à°£à°‚')) {
      return Icons.store_outlined;
    } else if (lowerLabel.contains('schemes') ||
        lowerLabel.contains('à¤¯à¥‹à¤œà¤¨à¤¾à¤à¤‚') ||
        lowerLabel.contains('à®¤à®¿à®Ÿà¯à®Ÿà®™à¯à®•à®³à¯') ||
        lowerLabel.contains('à°ªà°¥à°•à°¾à°²à±')) {
      return Icons.policy_outlined;
    }
    return Icons.business;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProv = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.welcomeTo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        loc.appTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
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

              const SizedBox(height: 20),

              // Buyer/Farmer toggle + language
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
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const HomePage(),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        !isSeller
                                            ? const Color(0xFFF0FDF4)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(13),
                                    boxShadow:
                                        !isSeller
                                            ? [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                            : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.shopping_cart_outlined,
                                        size: 16,
                                        color:
                                            !isSeller
                                                ? const Color(0xFF16A34A)
                                                : Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        loc.buyer,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color:
                                              !isSeller
                                                  ? const Color(0xFF16A34A)
                                                  : Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => isSeller = true),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        isSeller
                                            ? const Color(0xFFF0FDF4)
                                            : Colors.transparent,
                                    borderRadius: BorderRadius.circular(13),
                                    boxShadow:
                                        isSeller
                                            ? [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 6,
                                                spreadRadius: 1,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                            : [],
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.agriculture,
                                        size: 16,
                                        color:
                                            isSeller
                                                ? const Color(0xFF16A34A)
                                                : Colors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        loc.farmer,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color:
                                              isSeller
                                                  ? const Color(0xFF16A34A)
                                                  : Colors.white,
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7F3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF16A34A).withOpacity(0.3),
                          ),
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
                              (l) =>
                                  l['locale'].languageCode ==
                                  localeProv.locale.languageCode,
                              orElse: () => _languages[0],
                            ),
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: const Color(0xFF16A34A),
                              size: 20,
                            ),
                            style: const TextStyle(
                              color: Color(0xFF1F2937),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            items:
                                _languages.map((l) {
                                  return DropdownMenuItem(
                                    value: l,
                                    child: Text(
                                      l['name'] as String,
                                      style: const TextStyle(
                                        color: Color(0xFF1F2937),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 12,
                                      ),
                                    ),
                                  );
                                }).toList(),
                            onChanged: (newLang) {
                              if (newLang != null) {
                                localeProv.setLocale(
                                  newLang['locale'] as Locale,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

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
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF16A34A),
                                    Color(0xFF15803D),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.grass,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Farmer Services',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Action buttons
                        _buildFullWidthButton(loc.orders, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OrderListPage(),
                            ),
                          );
                        }),
                        _buildFullWidthButton(loc.marketPriceAnalysis, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => MarketPricePage(),
                            ),
                          );
                        }),
                        _buildFullWidthButton(loc.shop, () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ShopPage()),
                          );
                        }),

                        // <<< MODIFIED BUTTON
                        // This button now uses a hardcoded string and does not require translation.
                        _buildFullWidthButton("Subsidies & Schemes", () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SubsidiesPage(),
                            ),
                          );
                        }),
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
