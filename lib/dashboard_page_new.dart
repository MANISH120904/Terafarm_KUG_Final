import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';

import 'grow_plant_page.dart';
import 'order_list_page.dart';
import 'list_farm_page.dart';
import 'edit_farm_page.dart';
import 'menu_page.dart';
import 'l10n/app_localizations.dart';
import 'main.dart' show LocaleProvider;

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  _DashboardPageState createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with TickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  double earnings = 5000.0;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;
  late Timer? _shimmerTimer;

  // UI Colors - Updated to match seller page
  static const _kPrimaryGreen = Color(0xFF4F7942);
  static const _kLightGreen = Color(0xFFF5F7F3);
  static const _kAccentGreen = Color(0xFF16A34A);
  static const _kDarkGreen = Color(0xFF3D5E33);

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
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProv = Provider.of<LocaleProvider>(context, listen: false);
    final sellerId = _auth.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Match seller page background
      drawer: const MenuPage(),
      body: SafeArea(
        child: Column(
          children: [
            // Top banner - matching seller page design
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
                padding: const EdgeInsets.only(top: 8, bottom: 2, left: 24, right: 24),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Welcome to',
                            style: const TextStyle(color: Colors.white, fontSize: 17),
                          ),
                          Text(
                            'Farm Dashboard',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
                    Positioned(
                      right: 0,
                      top: 18,
                      child: Row(
                        children: [
                          // Language picker
                          DropdownButtonHideUnderline(
                            child: DropdownButton<Locale>(
                              icon: const Icon(Icons.language, color: Colors.white),
                              value: localeProv.locale,
                              dropdownColor: _kPrimaryGreen,
                              items: AppLocalizations.supportedLocales
                                  .map((l) => DropdownMenuItem(
                                        value: l,
                                        child: Text(
                                          l.languageCode.toUpperCase(),
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (locale) {
                                if (locale != null) {
                                  localeProv.setLocale(locale);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Main content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0), // Increased padding
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildChartSection(sellerId, loc),
                      const SizedBox(height: 24),
                      _buildEarningsCard(loc),
                      const SizedBox(height: 24),
                      _buildDashboardButtons(loc),
                      const SizedBox(height: 24),
                      _buildFarmSection(sellerId, loc),
                      const SizedBox(height: 24),
                      _buildProductListingsTable(sellerId, loc),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartSection(String sellerId, AppLocalizations loc) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kLightGreen,
                _kLightGreen,
                _kLightGreen.withOpacity(0.9),
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.3),
                _kLightGreen.withOpacity(0.9),
                _kLightGreen,
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
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _kPrimaryGreen.withOpacity(0.15),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 4),
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
                        Icons.analytics_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      loc.farmDashboardTitle,
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
                  'Monthly orders analytics',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                _buildEnhancedBarChart(sellerId, loc),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEarningsCard(AppLocalizations loc) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _kAccentGreen,
                _kAccentGreen,
                _kAccentGreen.withOpacity(0.9),
                Colors.white.withOpacity(0.95),
                Colors.white.withOpacity(0.3),
                _kAccentGreen.withOpacity(0.9),
                const Color(0xFF15803D),
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
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _kAccentGreen.withOpacity(0.25),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 4),
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
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      if (_shimmerAnimation.value > 0.15 && _shimmerAnimation.value < 0.85)
                        BoxShadow(
                          color: Colors.white.withOpacity(
                            0.8 * (1 - ((_shimmerAnimation.value - 0.5).abs() * 2))
                          ),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 0),
                        ),
                    ],
                  ),
                  child: const Icon(Icons.monetization_on, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.totalEarnings,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "₹${earnings.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEnhancedBarChart(String sellerId, AppLocalizations loc) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0);

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('orders').where('sellerId', isEqualTo: sellerId).snapshots(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_kPrimaryGreen),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    loc.loading,
                    style: TextStyle(
                      color: _kPrimaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (snap.hasError) {
          return Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                "${loc.error}: ${snap.error}",
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }
        
        if (!snap.hasData) {
          return Container(
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(child: Text(loc.noData)),
          );
        }

        final orders = snap.data!.docs.where((doc) {
          final orderDateRaw = doc['orderDate'];
          DateTime d;
          if (orderDateRaw is Timestamp) {
            d = orderDateRaw.toDate();
          } else if (orderDateRaw is String) {
            d = DateTime.tryParse(orderDateRaw) ?? DateTime(2000);
          } else {
            d = DateTime(2000);
          }
          return !d.isBefore(start) && !d.isAfter(end);
        }).toList();

        final counts = {for (var i = 1; i <= end.day; i++) i: 0};
        for (var o in orders) {
          final orderDateRaw = o['orderDate'];
          DateTime d;
          if (orderDateRaw is Timestamp) {
            d = orderDateRaw.toDate();
          } else if (orderDateRaw is String) {
            d = DateTime.tryParse(orderDateRaw) ?? DateTime(2000);
          } else {
            d = DateTime(2000);
          }
          final day = d.day;
          counts[day] = (counts[day] ?? 0) + 1;
        }

        final bars = counts.entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.toDouble(),
                width: 8,
                borderRadius: BorderRadius.circular(4),
                gradient: LinearGradient(
                  colors: [
                    _kPrimaryGreen,
                    _kAccentGreen,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              )
            ],
          );
        }).toList();

        return Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 1,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: BarChart(
            BarChartData(
              barGroups: bars,
              alignment: BarChartAlignment.spaceAround,
              maxY: (counts.values.isEmpty ? 10 : counts.values.reduce(max) + 2).toDouble(),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (group) => _kPrimaryGreen,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '${group.x.toInt()}th\n${rod.toY.round()} orders',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      return v.toInt() % 5 == 0 || v.toInt() == 1
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                v.toInt().toString(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            )
                          : const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) {
                      if (v.toInt() % 2 == 0 && v > 0) {
                        return Text(
                          v.toInt().toString(),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.shade200,
                    strokeWidth: 1,
                  );
                },
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDashboardButtons(AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color: _kLightGreen,
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
                      _kAccentGreen,
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
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _dashButton(
            loc.listFarm,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => ListFarmPage())),
            icon: Icons.list_alt,
          ),
          const SizedBox(height: 12),
          _dashButton(
            loc.growPlant,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrowPlantPage())),
            icon: Icons.local_florist,
          ),
          const SizedBox(height: 12),
          _dashButton(
            loc.ordersPageTitle,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderListPage())),
            icon: Icons.shopping_basket,
          ),
        ],
      ),
    );
  }

  Widget _dashButton(String text, VoidCallback onTap, {IconData? icon}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon ?? Icons.arrow_forward, color: Colors.white),
      label: Text(text, style: const TextStyle(fontSize: 16, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _kPrimaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: _kPrimaryGreen.withOpacity(0.3),
      ),
    );
  }

  Widget _buildFarmSection(String sellerId, AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color: _kLightGreen,
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
                      const Color(0xFF059669),
                      const Color(0xFF047857),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.agriculture,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                loc.yourFarm,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Center(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('farms').where('sellerId', isEqualTo: sellerId).snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox();
                final farms = snap.data!.docs;
                if (farms.isEmpty) {
                  return Text(
                    loc.noFarmRegistered,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 16,
                    ),
                  );
                }
                final farm = farms.first;
                return ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => EditFarmPage(farmId: farm.id)));
                  },
                  icon: const Icon(Icons.edit, color: Colors.white),
                  label: Text(farm['farmName'] as String? ?? loc.yourFarm,
                      style: const TextStyle(color: Colors.white, fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                    shadowColor: _kPrimaryGreen.withOpacity(0.3),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductListingsTable(String sellerId, AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        color: _kLightGreen,
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
                      const Color(0xFFEAB308),
                      const Color(0xFFCA8A04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.inventory,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                loc.productListings,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('farms').where('sellerId', isEqualTo: sellerId).snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) return const SizedBox();
                final docs = snap.data!.docs;
                final rows = <DataRow>[];
                var idx = 1;
                for (var d in docs) {
                  final prods = (d.data() as Map<String, dynamic>)['products'] as List? ?? [];
                  for (var p in prods) {
                    rows.add(DataRow(cells: [
                      DataCell(Text((idx++).toString())),
                      DataCell(Text(p['cropName'] ?? '')),
                      DataCell(Text("${p['stock in kgs'] ?? ''} Kg")),
                      DataCell(Text("₹${p['pricePerKg'] ?? ''}")),
                    ]));
                  }
                }
                if (rows.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      loc.noProductsFound,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: [
                      DataColumn(label: Text(loc.tableIndex, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.tableCrop, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.tableStock, style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text(loc.tablePricePerKg, style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: rows,
                    headingRowColor: WidgetStateProperty.all(_kLightGreen),
                    dataRowColor: WidgetStateProperty.all(Colors.white),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
