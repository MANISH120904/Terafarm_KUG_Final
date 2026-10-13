import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'location.dart';
import 'l10n/app_localizations.dart';
import 'providers/weather_provider.dart';
import 'services/live_weather_service.dart';
import 'test_notification_page.dart';

class WeatherPage extends StatefulWidget {
  const WeatherPage({Key? key}) : super(key: key);

  @override
  _WeatherPageState createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> with SingleTickerProviderStateMixin {
  bool _loading = true;
  double? _temperature;
  int? _humidity;
  String? _condition;
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      var pos = LocationService().currentPosition;
      if (pos == null) {
        await LocationService().determinePosition();
        pos = LocationService().currentPosition;
      }
      if (pos == null) throw Exception('Could not determine location');

      final weather = await LiveWeatherService.byCoordinates(
        lat: pos.latitude,
        lon: pos.longitude,
      );
      if (!mounted) return;
      setState(() {
        _temperature = weather.temperatureC;
        _humidity = weather.humidity;
        _condition = weather.condition;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Color> _getWeatherGradient() {
    final condition = _condition?.toLowerCase() ?? '';
    
    if (condition.contains('rain') || condition.contains('drizzle')) {
      // Rainy: Deep Blue or Slate Grey
      return [const Color(0xFF4A6572), const Color(0xFF6C8EBF), const Color(0xFF90CAF9)];
    } else if (condition.contains('clear') || condition.contains('sunny')) {
      // Sunny/Clear: Bright Yellow or Light Orange
      return [const Color(0xFFFDB813), const Color(0xFFFFE066), const Color(0xFF87CEEB)];
    } else if (condition.contains('partly') && condition.contains('cloud')) {
      // Partly Cloudy: Light Blue-Grey
      return [const Color(0xFFCFCFCF), const Color(0xFFFFE89C), const Color(0xFFA3C4DC)];
    } else if (condition.contains('cloud') || condition.contains('overcast')) {
      // Cloudy/Overcast: Grey
      return [const Color(0xFFB0BEC5), const Color(0xFF90A4AE), const Color(0xFFECEFF1)];
    } else if (condition.contains('storm') || condition.contains('thunder')) {
      // Thunderstorm: Dark Grey or Blackish Blue
      return [const Color(0xFF37474F), const Color(0xFFFDD835), const Color(0xFF673AB7)];
    } else if (condition.contains('snow')) {
      // Snowy: White or Light Grey
      return [const Color(0xFFFFFFFF), const Color(0xFFE0F7FA), const Color(0xFFB0BEC5)];
    } else if (condition.contains('fog') || condition.contains('mist')) {
      // Fog/Mist: Pale Grey
      return [const Color(0xFFECEFF1), const Color(0xFFB3C0C8), const Color(0xFFDDE5E9)];
    } else if (condition.contains('tornado') || condition.contains('extreme')) {
      // Tornado/Extreme: Charcoal or Black
      return [const Color(0xFF212121), const Color(0xFFFF3D00), const Color(0xFFFF9800)];
    } else {
      // Default
      return [const Color(0xFF87CEEB), const Color(0xFFB0BEC5), const Color(0xFFECEFF1)];
    }
  }

  IconData _getWeatherIcon() {
    final condition = _condition?.toLowerCase() ?? '';
    
    if (condition.contains('rain') || condition.contains('drizzle')) {
      return Icons.grain;
    } else if (condition.contains('clear') || condition.contains('sunny')) {
      return Icons.wb_sunny;
    } else if (condition.contains('cloud')) {
      return Icons.cloud;
    } else if (condition.contains('storm')) {
      return Icons.flash_on;
    } else if (condition.contains('snow')) {
      return Icons.ac_unit;
    } else {
      return Icons.wb_cloudy;
    }
  }

  Widget _buildWeatherIcon() {
    final icon = _getWeatherIcon();
    return Icon(icon, color: Colors.white, size: 60);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final gradientColors = _getWeatherGradient();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(loc.getWeather),
        backgroundColor: gradientColors.first,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: _loading
              ? const CircularProgressIndicator(color: Colors.white)
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (_, child) {
                    return Container(
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1 + _controller.value * 0.1),
                            blurRadius: 20 + (20 * _controller.value),
                            spreadRadius: 2,
                          ),
                        ],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildWeatherIcon(),
                          const SizedBox(height: 20),
                          Text(
                            '${_temperature?.toStringAsFixed(1)}°C',
                            style: const TextStyle(
                                fontSize: 48, 
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    offset: Offset(2, 2),
                                    blurRadius: 4,
                                  ),
                                ]),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _condition ?? '',
                            style: const TextStyle(
                                fontSize: 24, 
                                color: Colors.white,
                                fontWeight: FontWeight.w300,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    offset: Offset(1, 1),
                                    blurRadius: 2,
                                  ),
                                ]),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.water_drop, color: Colors.white.withOpacity(0.8), size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '$_humidity% RH',
                                style: const TextStyle(
                                    fontSize: 18, 
                                    color: Colors.white,
                                    fontWeight: FontWeight.w300),
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          // Test Notification Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    print("Weather page: Test button pressed");
                                    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
                                    await weatherProvider.sendTestNotification();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Test notification sent! Check your notification panel.'),
                                        backgroundColor: Colors.green,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  } catch (e) {
                                    print("Weather page: Error sending test notification: $e");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error sending notification: $e'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.notifications, color: Colors.white),
                                label: const Text('Test', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.withOpacity(0.7),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    print("Weather page: Alert button pressed");
                                    final weatherProvider = Provider.of<WeatherProvider>(context, listen: false);
                                    // Manually trigger a weather alert check
                                    weatherProvider.setAlert("Test Alert: Heavy rain is expected in your area. Protect your crops!");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Weather alert triggered! Check your notification panel.'),
                                        backgroundColor: Colors.orange,
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  } catch (e) {
                                    print("Weather page: Error triggering alert: $e");
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error triggering alert: $e'),
                                        backgroundColor: Colors.red,
                                        duration: const Duration(seconds: 5),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.warning, color: Colors.white),
                                label: const Text('Alert', style: TextStyle(color: Colors.white)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange.withOpacity(0.7),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Direct test button
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const TestNotificationPage(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.settings, color: Colors.white),
                            label: const Text('Direct Test', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple.withOpacity(0.7),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
