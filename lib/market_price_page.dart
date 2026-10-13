import 'package:flutter/material.dart';
import 'services/agmarknet_market_price_service.dart';
import 'theme/tera_farm_theme.dart';
import 'widgets/tera_farm_scaffold.dart';

class MarketPricePage extends StatefulWidget {
  const MarketPricePage({super.key});

  @override
  State<MarketPricePage> createState() => _MarketPricePageState();
}

class _MarketPricePageState extends State<MarketPricePage> {
  String? selectedState;
  String? selectedCommodity;

  final List<String> states = [
    'Andhra Pradesh',
    'Arunachal Pradesh',
    'Assam',
    'Bihar',
    'Chhattisgarh',
    'Goa',
    'Gujarat',
    'Haryana',
    'Himachal Pradesh',
    'Jharkhand',
    'Karnataka',
    'Kerala',
    'Madhya Pradesh',
    'Maharashtra',
    'Manipur',
    'Meghalaya',
    'Mizoram',
    'Nagaland',
    'Odisha',
    'Punjab',
    'Rajasthan',
    'Sikkim',
    'Tamil Nadu',
    'Telangana',
    'Tripura',
    'Uttar Pradesh',
    'Uttarakhand',
    'West Bengal',
    'Delhi',
  ];
  List<String> commodities = [];
  List<Map<String, dynamic>> priceHistory = [];

  bool loadingCommodities = false;
  bool loadingPrices = false;
  String? error;
  String? sourceNote;
  bool isLive = false;

  Future<void> _fetchCommodities() async {
    if (selectedState == null) return;
    setState(() {
      loadingCommodities = true;
      commodities = [];
      selectedCommodity = null;
      priceHistory = [];
      error = null;
      sourceNote = null;
      isLive = false;
    });

    try {
      final list =
          await AgmarknetMarketPriceService.commoditiesForState(selectedState!);
      if (!mounted) return;
      setState(() {
        commodities = list;
        if (commodities.isEmpty) {
          error = 'No produce found for $selectedState.';
        }
        loadingCommodities = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Could not load commodities.';
        loadingCommodities = false;
      });
    }
  }

  Future<void> _fetchPrices() async {
    if (selectedState == null || selectedCommodity == null) return;
    setState(() {
      loadingPrices = true;
      priceHistory = [];
      error = null;
      sourceNote = null;
    });

    try {
      final result = await AgmarknetMarketPriceService.pricesFor(
        state: selectedState!,
        commodity: selectedCommodity!,
      );
      if (!mounted) return;
      setState(() {
        priceHistory = result.rows;
        isLive = result.isLive;
        sourceNote = result.isLive
            ? 'Live Agmarknet / data.gov.in'
            : (result.note ?? 'Demo prices');
        if (priceHistory.isEmpty) {
          error = 'No price data for $selectedCommodity in $selectedState.';
        }
        loadingPrices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Could not load prices.';
        loadingPrices = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TeraFarmScaffold(
      mode: TeraFarmScaffoldMode.inner,
      title: 'Market Price Analysis',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TeraFarmSurfaceCard(
              margin: EdgeInsets.zero,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Select State'),
                    value: selectedState,
                    items: states
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (s) {
                      setState(() => selectedState = s);
                      _fetchCommodities();
                    },
                  ),
                  const SizedBox(height: 16),
                  if (loadingCommodities)
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    )
                  else if (commodities.isNotEmpty)
                    DropdownButtonFormField<String>(
                      decoration:
                          const InputDecoration(labelText: 'Select Produce'),
                      value: selectedCommodity,
                      items: commodities
                          .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (c) {
                        setState(() => selectedCommodity = c);
                        _fetchPrices();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (sourceNote != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLive
                        ? TeraFarmColors.accent.withOpacity(0.15)
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    sourceNote!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isLive
                          ? TeraFarmColors.primaryDark
                          : Colors.orange.shade800,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            if (loadingPrices)
              const CircularProgressIndicator()
            else if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 8),
            if (!loadingPrices && error == null && priceHistory.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: priceHistory.length,
                  itemBuilder: (_, i) {
                    final row = priceHistory[i];
                    final variety = (row['variety'] ?? '').toString();
                    final district = (row['district'] ?? '').toString();
                    final minP = row['min_price'];
                    final maxP = row['max_price'];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              TeraFarmColors.accent.withOpacity(0.2),
                          child: const Icon(Icons.storefront,
                              color: TeraFarmColors.primary),
                        ),
                        title: Text(
                          '${row['market']} — ₹${row['modal_price']} / quintal',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          [
                            if (district.isNotEmpty) district,
                            if (variety.isNotEmpty) variety,
                            row['arrival_date'] ?? '',
                            if (minP != null &&
                                maxP != null &&
                                '$minP'.isNotEmpty)
                              'Min ₹$minP · Max ₹$maxP',
                          ]
                              .where((e) => e.toString().trim().isNotEmpty)
                              .join(' · '),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
