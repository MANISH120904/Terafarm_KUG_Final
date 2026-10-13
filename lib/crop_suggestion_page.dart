import 'package:flutter/material.dart';
import 'menu_page.dart';
import 'services/local_crop_service.dart';

class CropSuggestionPage extends StatefulWidget {
  const CropSuggestionPage({super.key});

  @override
  State<CropSuggestionPage> createState() => _CropSuggestionPageState();
}

class _CropSuggestionPageState extends State<CropSuggestionPage> {
  final TextEditingController landController = TextEditingController();
  final TextEditingController budgetController = TextEditingController();
  final TextEditingController durationController = TextEditingController();
  final TextEditingController stateController = TextEditingController();

  // UI Colors
  static const _kPrimaryGreen = Color(0xFF2F7A3E);
  static const _kLightGreen = Color(0xFFEAF5EA);
  static const _kFieldBorder = Color(0xFFB7D8B7);

  String result = '';
  bool isLoading = false;

  Future<void> getSuggestion() async {
    final land = landController.text.trim();
    final budget = budgetController.text.trim();
    final duration = durationController.text.trim();
    final state = stateController.text.trim();

    if (land.isEmpty || budget.isEmpty || duration.isEmpty || state.isEmpty) {
      setState(() {
        result = '⚠️ Please fill in all fields.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      result = '';
    });

    try {
      // Local rules (ported from backend/app.py) — no Cloud Run required
      await Future<void>.delayed(const Duration(milliseconds: 250));
      final crops = LocalCropService.suggestCrops(
        landSize: land,
        budget: budget,
        duration: duration,
        state: state,
      );
      setState(() {
        result = crops.isNotEmpty
            ? '🌱 Suggested Crops: ${crops.join(', ')}'
            : '❌ No suitable crops found.';
      });
    } catch (e) {
      setState(() {
        result = '❌ Error: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const MenuPage(),
      bottomNavigationBar: Container(
        width: double.infinity,
        height: 70,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bottom_bar.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top banner with image background
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
                  padding: const EdgeInsets.only(
                    top: 8,
                    bottom: 2,
                    left: 24,
                    right: 24,
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        left: -8,
                        top: 18,
                        child: Builder(
                          builder:
                              (ctx) => IconButton(
                                icon: const Icon(
                                  Icons.menu,
                                  color: Colors.white,
                                ),
                                onPressed: () => Scaffold.of(ctx).openDrawer(),
                              ),
                        ),
                      ),
                      Positioned.fill(
                        child: Column(
                          children: const [
                            SizedBox(height: 24),
                            Center(
                              child: Text(
                                'Crop\nSuggestion',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: landController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Land Size (in acres)',
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kFieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _kPrimaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: budgetController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Budget (in ₹)',
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kFieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _kPrimaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Duration (in months)',
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kFieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _kPrimaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: stateController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'State',
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: _kFieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                            color: _kPrimaryGreen,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : getSuggestion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child:
                            isLoading
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text(
                                  'Suggest Crops',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (result.isNotEmpty)
                      Container(
                        decoration: BoxDecoration(
                          color: _kLightGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          result,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
