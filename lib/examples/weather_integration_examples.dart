import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:TeraFarm/services/weather_notification_service.dart';
import 'package:TeraFarm/widgets/weather_notification_widgets.dart';

/// Example: Settings page with weather notification controls
class WeatherSettingsPage extends StatelessWidget {
  const WeatherSettingsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Notifications'),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Show current location
          const WeatherLocationCard(),
          
          const SizedBox(height: 16),
          
          // Toggle notifications on/off
          const Card(
            child: WeatherNotificationToggle(),
          ),
          
          const SizedBox(height: 16),
          
          // Information card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'About Weather Forecasts',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow('📍', 'Based on your location'),
                  _buildInfoRow('🌤️', 'Current weather updates'),
                  _buildInfoRow('🔮', 'Tomorrow\'s forecast'),
                  _buildInfoRow('🌧️', 'Rain probability alerts'),
                  _buildInfoRow('⏰', 'Updates every 30 minutes'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

/// Example: Login page that automatically sets up weather notifications
class LoginPageExample extends StatefulWidget {
  const LoginPageExample({Key? key}) : super(key: key);

  @override
  State<LoginPageExample> createState() => _LoginPageExampleState();
}

class _LoginPageExampleState extends State<LoginPageExample> {
  final _weatherService = WeatherNotificationService();
  bool _isSettingUpWeather = false;

  /// Called after successful login
  Future<void> _onLoginSuccess(User user) async {
    print('✅ User logged in: ${user.email}');

    // Setup weather notifications automatically
    setState(() => _isSettingUpWeather = true);

    try {
      final success = await _weatherService.initialize();

      if (success) {
        print('✅ Weather notifications setup complete!');
        
        // Show success message
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🌤️ Weather notifications enabled for your location!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Navigate to home page
        // Navigator.pushReplacement(...);
      } else {
        print('⚠️ Weather notifications setup failed');
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Could not enable weather notifications'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print('❌ Error setting up weather: $e');
    } finally {
      if (mounted) {
        setState(() => _isSettingUpWeather = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _isSettingUpWeather
            ? const WeatherNotificationSetup()
            : ElevatedButton(
                onPressed: () {
                  // Your login logic here
                  // After successful login, call:
                  // _onLoginSuccess(user);
                },
                child: const Text('Login'),
              ),
      ),
    );
  }
}

/// Example: Home page with weather notification status
class HomePageExample extends StatefulWidget {
  const HomePageExample({Key? key}) : super(key: key);

  @override
  State<HomePageExample> createState() => _HomePageExampleState();
}

class _HomePageExampleState extends State<HomePageExample> {
  final _weatherService = WeatherNotificationService();
  bool _isSetup = false;
  bool _isChecking = true;

  @override
  void initState() {
    super.initState();
    _checkWeatherSetup();
  }

  Future<void> _checkWeatherSetup() async {
    final isSetup = await _weatherService.isUserSetup();
    setState(() {
      _isSetup = isSetup;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wb_sunny),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const WeatherSettingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Show setup prompt if not configured
          if (_isChecking)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (!_isSetup)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.wb_sunny, size: 48, color: Colors.orange),
                    const SizedBox(height: 12),
                    const Text(
                      'Enable Weather Forecasts',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Get personalized weather updates for your location',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () async {
                        setState(() => _isChecking = true);
                        await _weatherService.initialize();
                        await _checkWeatherSetup();
                      },
                      icon: const Icon(Icons.check),
                      label: const Text('Enable Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 32),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Weather Notifications Active',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'You\'ll receive weather forecasts every 30 minutes',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WeatherSettingsPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Other home page content...
        ],
      ),
    );
  }
}

/// Example: Profile/Settings page integration
class ProfilePageExample extends StatelessWidget {
  const ProfilePageExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'),
      ),
      body: ListView(
        children: [
          // User info section
          const ListTile(
            leading: CircleAvatar(child: Icon(Icons.person)),
            title: Text('User Name'),
            subtitle: Text('user@example.com'),
          ),

          const Divider(),

          // Weather notifications section
          const ListTile(
            leading: Icon(Icons.wb_sunny, color: Colors.orange),
            title: Text('Weather Notifications'),
            subtitle: Text('Manage your weather forecast settings'),
            trailing: Icon(Icons.arrow_forward_ios),
            onTap: null, // Navigate to WeatherSettingsPage
          ),

          const WeatherNotificationToggle(),

          const Divider(),

          // Other settings...
        ],
      ),
    );
  }
}
