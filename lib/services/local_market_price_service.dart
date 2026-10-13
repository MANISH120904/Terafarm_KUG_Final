/// Offline mandi-style prices for hackathon demo (no Render / Agmarknet required).
class LocalMarketPriceService {
  static const List<String> defaultCommodities = [
    'Tomato',
    'Onion',
    'Potato',
    'Rice',
    'Wheat',
    'Banana',
    'Coconut',
    'Cotton',
    'Sugarcane',
    'Okra',
    'Cabbage',
    'Spinach',
  ];

  static List<String> commoditiesForState(String state) {
    // Same list for all states in demo mode
    return List<String>.from(defaultCommodities);
  }

  static List<Map<String, dynamic>> pricesFor({
    required String state,
    required String commodity,
  }) {
    final seed = (state.length * 17 + commodity.length * 31) % 100;
    final base = 800 + seed * 12;
    final markets = [
      'Central Mandi',
      'APMC Yard',
      'Local Wholesale',
    ];

    return List.generate(3, (i) {
      final modal = base + i * 45;
      return {
        'state': state,
        'district': 'Demo District',
        'market': markets[i],
        'commodity': commodity,
        'variety': 'FAQ',
        'arrival_date': DateTime.now()
            .subtract(Duration(days: i))
            .toIso8601String()
            .split('T')
            .first,
        'min_price': '${modal - 80}',
        'max_price': '${modal + 120}',
        'modal_price': '$modal',
      };
    });
  }
}
