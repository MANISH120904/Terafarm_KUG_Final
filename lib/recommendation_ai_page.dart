import 'package:flutter/material.dart';
import 'menu_page.dart';

class RecommendationForm extends StatefulWidget {
  const RecommendationForm({super.key});

  @override
  _RecommendationFormState createState() => _RecommendationFormState();
}

class _RecommendationFormState extends State<RecommendationForm> {
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _areaSizeController = TextEditingController();
  final TextEditingController _dailyTimeController = TextEditingController();

  // UI Colors
  static const _kPrimaryGreen = Color(0xFF2F7A3E);
  static const _kLightGreen = Color(0xFFEAF5EA);
  static const _kFieldBorder = Color(0xFFB7D8B7);

  // Dropdown values for space type and time unit
  final List<String> _spaceTypes = ['Balcony', 'Terrace', 'Garden'];
  String _selectedSpaceType = 'Balcony';

  final List<String> _timeUnits = ['hours', 'mins'];
  String _selectedTimeUnit = 'hours';

  String _result = '';

  // This function collects the input and prints a static recommendation message.
  void _getRecommendation() {
    // Retrieve input values
    final String city = _cityController.text;
    final String areaSize = _areaSizeController.text;
    final String dailyTime = _dailyTimeController.text;
    final String spaceType = _selectedSpaceType;
    final String timeUnit = _selectedTimeUnit;

    // Build a static recommendation message based on the input
    final String recommendation = "Based on your input:\n"
        "City: $city\n"
        "Area Size: $areaSize m²\n"
        "Space Type: $spaceType\n"
        "Daily Care Time: $dailyTime $timeUnit\n\n"
        "We recommend trying a high-light exposure plant care system for optimal growth.";

    // Update the UI to display the result
    setState(() {
      _result = recommendation;
    });

    // Optionally, print the output to the console for debugging
    print("Static Recommendation:\n$recommendation");
  }

  @override
  void dispose() {
    _cityController.dispose();
    _areaSizeController.dispose();
    _dailyTimeController.dispose();
    super.dispose();
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
                  padding: const EdgeInsets.only(top: 8, bottom: 2, left: 24, right: 24),
                  child: Stack(
                    children: [
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
                      Positioned.fill(
                        child: Column(
                          children: const [
                            SizedBox(height: 16),
                            Center(
                              child: Text(
                                'Plant\nSuggest',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 25,
                                  fontWeight: FontWeight.bold,
                                  height: 1.25,
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // City Input
              TextField(
                controller: _cityController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Enter Your City",
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
                    borderSide: const BorderSide(color: _kPrimaryGreen, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Area Size Input
              TextField(
                controller: _areaSizeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Area Size (in square meters)",
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
                    borderSide: const BorderSide(color: _kPrimaryGreen, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Dropdown for Type of Space
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kFieldBorder),
                ),
                child: Row(
                  children: [
                    const Text(
                      "Select Space Type:",
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: _selectedSpaceType,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: _kPrimaryGreen),
                      items: _spaceTypes.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 16)),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedSpaceType = newValue!;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Daily Care Time Input and Time Unit Dropdown
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _dailyTimeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: "Daily Care Time",
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
                          borderSide: const BorderSide(color: _kPrimaryGreen, width: 2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kFieldBorder),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedTimeUnit,
                      underline: const SizedBox(),
                      icon: const Icon(Icons.arrow_drop_down, color: _kPrimaryGreen),
                      items: _timeUnits.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontSize: 16)),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedTimeUnit = newValue!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Button to trigger the static recommendation
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _getRecommendation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimaryGreen,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text(
                    "Get My Recommendation",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Display the static result
              if (_result.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: _kLightGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _result,
                    style: const TextStyle(fontSize: 16, color: Colors.black87),
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


