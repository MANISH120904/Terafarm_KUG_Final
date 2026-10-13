import 'package:flutter/material.dart';
import 'services/local_market_price_service.dart';

class MarketPricePage extends StatefulWidget {
  const MarketPricePage({super.key});

  @override
  State<MarketPricePage> createState() => _MarketPricePageState();
}

class _MarketPricePageState extends State<MarketPricePage> {
  String? selectedState;
  String? selectedCommodity;

  final List<String> states = [
    "Andhra Pradesh",
    "Arunachal Pradesh",
    "Assam",
    "Bihar",
    "Chhattisgarh",
    "Goa",
    "Gujarat",
    "Haryana",
    "Himachal Pradesh",
    "Jharkhand",
    "Karnataka",
    "Kerala",
    "Madhya Pradesh",
    "Maharashtra",
    "Manipur",
    "Meghalaya",
    "Mizoram",
    "Nagaland",
    "Odisha",
    "Punjab",
    "Rajasthan",
    "Sikkim",
    "Tamil Nadu",
    "Telangana",
    "Tripura",
    "Uttar Pradesh",
    "Uttarakhand",
    "West Bengal",
    "Delhi",
  ];
  List<String> commodities = [];
  List<Map<String, dynamic>> priceHistory = [];

  bool loadingCommodities = false;
  bool loadingPrices = false;
  String? error;

  Future<void> _fetchCommodities() async {
    if (selectedState == null) return;
    setState(() {
      loadingCommodities = true;
      commodities = [];
      selectedCommodity = null;
      priceHistory = [];
      error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 200));
    setState(() {
      commodities =
          LocalMarketPriceService.commoditiesForState(selectedState!);
      if (commodities.isEmpty) {
        error = 'No produce found for $selectedState.';
      }
      loadingCommodities = false;
    });
  }

  Future<void> _fetchPrices() async {
    if (selectedState == null || selectedCommodity == null) return;
    setState(() {
      loadingPrices = true;
      priceHistory = [];
      error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 200));
    setState(() {
      priceHistory = LocalMarketPriceService.pricesFor(
        state: selectedState!,
        commodity: selectedCommodity!,
      );
      if (priceHistory.isEmpty) {
        error = 'No price data for $selectedCommodity in $selectedState.';
      }
      loadingPrices = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Market Price Analysis')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(labelText: 'Select State'),
              value: selectedState,
              items:
                  states
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
              onChanged: (s) {
                setState(() => selectedState = s);
                _fetchCommodities();
              },
            ),
            const SizedBox(height: 16),
            if (loadingCommodities)
              CircularProgressIndicator()
            else if (commodities.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: InputDecoration(labelText: 'Select Produce'),
                value: selectedCommodity,
                items:
                    commodities
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                onChanged: (c) {
                  setState(() => selectedCommodity = c);
                  _fetchPrices();
                },
              ),
            const SizedBox(height: 16),
            if (loadingPrices)
              CircularProgressIndicator()
            else if (error != null)
              Text(error!, style: TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            if (!loadingPrices && error == null && priceHistory.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: priceHistory.length,
                  itemBuilder: (_, i) {
                    final row = priceHistory[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(
                          '${row['market']} — ₹${row['modal_price']} per quintal',
                        ),
                        subtitle: Text(
                          '${row['arrival_date'] ?? row['date'] ?? ''}',
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
