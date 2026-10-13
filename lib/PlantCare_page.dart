// PlantCare_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'l10n/app_localizations.dart';
import 'address_map_picker.dart';
import 'main.dart' show LocaleProvider;
import 'menu_page.dart';
import 'config/api_keys.dart';

// Remove the main() function since this is not the main entry point
// void main() {
//   runApp(PlantCareApp());
// }

class PlantCareApp extends StatelessWidget {
  const PlantCareApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Use the existing global MaterialApp context instead of creating a new one
    return const FarmAiPage();
  }
}

class FarmAiPage extends StatefulWidget {
  const FarmAiPage({super.key});
  @override
  State<FarmAiPage> createState() => _FarmAiPageState();
}

class _FarmAiPageState extends State<FarmAiPage> {
  final _cityController  = TextEditingController();
  final _plantController = TextEditingController();

  late List<Map<String, dynamic>> _languages;
  
  bool _loadingWeather = false, _loadingAdvice = false;
  double? _temperature, _latitude, _longitude;
  int? _humidity;
  String? _condition, _advice, _currentAddress;

  late GenerativeModel _geminiModel;

  @override
  void dispose() {
    _plantController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  // UI Colors
  static const _kPrimaryGreen = Color(0xFF2F7A3E);
  static const _kLightGreen   = Color(0xFFEAF5EA);
  static const _kFieldBorder  = Color(0xFFB7D8B7);

  @override
  void initState() {
    super.initState();
    _plantController.clear();
    
    _languages = [
      {'name': 'English', 'locale': const Locale('en')},
      {'name': 'हिन्दी',  'locale': const Locale('hi')},
      {'name': 'தமிழ்',  'locale': const Locale('ta')},
      {'name': 'తెలుగు','locale': const Locale('te')},
    ];
    
    const geminiApiKey = ApiKeys.gemini;
    _geminiModel = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7, topP: 0.9, topK: 40, maxOutputTokens: 256,
      ),
    );
  }

  Future<LatLng> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception("Location services disabled.");
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) throw Exception("Permissions denied.");
    }
    if (perm == LocationPermission.deniedForever) {
      throw Exception("Permissions permanently denied.");
    }
    final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    return LatLng(pos.latitude, pos.longitude);
  }

  Future<void> _openMapPicker() async {
    LatLng initial;
    try {
      initial = await _getCurrentLocation();
    } catch (_) {
      initial = const LatLng(13.0827, 80.2707);
    }
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddressMapPicker(initialLocation: initial),
    );
    if (result != null) {
      setState(() {
        _latitude       = result['lat'] as double;
        _longitude      = result['lng'] as double;
        _currentAddress = result['address'] as String;
        _cityController.text = _currentAddress!;
      });
    }
  }

  Future<void> _getWeather() async {
    setState(() {
      _loadingWeather = true;
      _advice         = null;
    });

    final key   = '994SBTQFYTXZJPS5YLZP5FWGW';
    final query = (_latitude != null && _longitude != null)
        ? '$_latitude,$_longitude'
        : _cityController.text.trim();
    final uri = Uri.https(
      'weather.visualcrossing.com',
      '/VisualCrossingWebServices/rest/services/timeline/$query',
      {
        'unitGroup'  : 'metric',
        'include'    : 'current',
        'key'        : key,
        'contentType': 'json',
      },
    );

    try {
      final res = await http.get(uri);
      if (res.statusCode != 200) {
        throw Exception('Weather fetch failed: ${res.statusCode}');
      }
      final data = json.decode(res.body) as Map<String, dynamic>;
      final curr = data['currentConditions'] as Map<String, dynamic>;
      setState(() {
        _temperature = (curr['temp']    as num).toDouble();
        _humidity    = (curr['humidity'] as num).toInt();
        _condition   = curr['conditions'] as String;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _loadingWeather = false);
    }
  }

  Future<String> _translatePrompt(String text) async {
    final loc = AppLocalizations.of(context)!;
    if (loc.localeName == 'en') return text;
    final prompt = '${loc.translationInstruction}\n\n$text';
    final resp = await _geminiModel.generateContent([
      Content.multi([TextPart(prompt)])
    ]);
    return (resp.text ?? resp.candidates.first.content as String).trim();
  }

  Future<void> _getAdvice() async {
    if (_temperature == null || _condition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.fetchWeatherFirst)),
      );
      return;
    }
    setState(() {
      _loadingAdvice = true;
      _advice        = null;
    });

    final basePrompt = '''
You are an expert agricultural advisor.
Given:
• Plant: ${_plantController.text.trim()}
• Location: ${_currentAddress ?? _cityController.text.trim()}
• Current: ${_temperature!.toStringAsFixed(1)}°C, $_humidity% RH, $_condition

Provide creative, emoji‑enhanced, actionable tips. Short, engaging, specific.
Include YouTube links in the user’s language.
''';

    try {
      final prompt = await _translatePrompt(basePrompt);
      final resp = await _geminiModel.generateContent([
        Content.multi([TextPart(prompt)])
      ]);
      setState(() {
        _advice = (resp.text ?? resp.candidates.first.content as String)
            .replaceAll('*', '')
            .trim();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _loadingAdvice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc        = AppLocalizations.of(context)!;
    final localeProv = Provider.of<LocaleProvider>(context, listen: true);

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
                          children: [
                            const SizedBox(height: 15),
                            Center(
                              child: Text(
                                loc.welcomeTo,
                                style: const TextStyle(color: Colors.white, fontSize: 17),
                              ),
                            ),
                            const SizedBox(height: 0),
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
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    // Language Selection
                    Align(
                      alignment: Alignment.centerRight,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<Map<String, dynamic>>(
                          value: _languages.firstWhere(
                            (lang) => (lang['locale'] as Locale).languageCode == 
                                      localeProv.locale.languageCode,
                            orElse: () => _languages[0],
                          ),
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF246B40)),
                          items: _languages.map((lang) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: lang,
                              child: Text(lang['name']),
                            );
                          }).toList(),
                          onChanged: (newLang) {
                            if (newLang != null) {
                              localeProv.setLocale(newLang['locale']);
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // City Input
                    TextField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: loc.enterCity,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.location_on, color: _kPrimaryGreen),
                          onPressed: _openMapPicker,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _kFieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _kPrimaryGreen, width: 2),
                        ),
                      ),
                      onChanged: (_) {
                        setState(() {
                          _latitude = null;
                          _longitude = null;
                          _currentAddress = null;
                        });
                      },
                      onSubmitted: (_) => _getWeather(),
                    ),
                    const SizedBox(height: 12),
                    // Get Weather Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: _loadingWeather ? null : _getWeather,
                        child: Text(
                          _loadingWeather ? loc.loading : loc.getWeather,
                          style: const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),

                    // ——— UPDATED WEATHER CARD UI ———
                    if (_temperature != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: _kLightGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Icon Avatar
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Image.asset(
                                  'assets/plant_bot.png', // add in pubspec.yaml
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Text info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Temperature: ${_temperature!.toStringAsFixed(2)} C',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Humidity: ${_humidity}%',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Condition: $_condition',
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                    // Plant input & advice (unchanged)…
                    TextField(
                      controller: _plantController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white,
                        hintText: loc.enterPlant,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _kFieldBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _kPrimaryGreen, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kPrimaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: (_loadingAdvice || _temperature == null)
                            ? null
                            : _getAdvice,
                        child: Text(
                          _loadingAdvice ? loc.loading : loc.getTips,
                          style:
                              const TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),

                    if (_advice != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: _kLightGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Text(_advice!),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: _kPrimaryGreen),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: () {
                            setState(() {
                              _temperature = null;
                              _humidity    = null;
                              _condition   = null;
                              _advice      = null;
                            });
                          },
                          child: Text(
                            loc.tryAnother,
                            style:
                                TextStyle(color: _kPrimaryGreen, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
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
