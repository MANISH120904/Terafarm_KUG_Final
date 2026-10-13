/// Local crop suggestion rules ported from backend/app.py (no Cloud Run needed).
class LocalCropService {
  static List<String> suggestCrops({
    required String landSize,
    required String budget,
    required String duration,
    required String state,
  }) {
    final stateLower = state.toLowerCase().trim();
    final suggestions = <String>[];

    if (['punjab', 'haryana', 'uttar pradesh', 'up'].contains(stateLower)) {
      suggestions.addAll(['Wheat', 'Rice']);
    } else if (['maharashtra', 'karnataka', 'andhra pradesh', 'telangana']
        .contains(stateLower)) {
      suggestions.addAll(['Sugarcane', 'Cotton']);
    } else if (['kerala', 'tamil nadu', 'tn'].contains(stateLower)) {
      suggestions.addAll(['Banana', 'Coconut']);
    } else {
      suggestions.addAll(['Tomato', 'Onion', 'Potato']);
    }

    final land = double.tryParse(landSize) ?? 1;
    final budgetVal = double.tryParse(budget) ?? 10000;

    if (land < 1) {
      return ['Spinach', 'Lettuce', 'Mint'];
    }
    if (budgetVal < 5000) {
      suggestions.addAll(['Cabbage', 'Okra']);
    }

    // duration is accepted for API parity; short cycles bias leafy greens
    final days = int.tryParse(duration) ?? 90;
    if (days <= 45) {
      suggestions.addAll(['Spinach', 'Radish', 'Coriander']);
    }

    return suggestions.toSet().toList();
  }
}
