import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:TeraFarm/services/weather_notification_service.dart';

/// Simple test page to verify weather notification service
/// Run this to test the integration
class WeatherNotificationTest extends StatefulWidget {
  const WeatherNotificationTest({Key? key}) : super(key: key);

  @override
  State<WeatherNotificationTest> createState() => _WeatherNotificationTestState();
}

class _WeatherNotificationTestState extends State<WeatherNotificationTest> {
  final _service = WeatherNotificationService();
  final List<String> _logs = [];
  bool _isRunning = false;

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
    print(message);
  }

  Future<void> _runTest() async {
    setState(() {
      _isRunning = true;
      _logs.clear();
    });

    try {
      _addLog('🧪 Starting weather notification test...');

      // Test 1: Check Firebase initialization
      _addLog('1️⃣ Checking Firebase...');
      try {
        await Firebase.initializeApp();
        _addLog('   ✅ Firebase initialized');
      } catch (e) {
        _addLog('   ℹ️ Firebase already initialized');
      }

      // Test 2: Request permissions
      _addLog('2️⃣ Requesting notification permission...');
      final notifPerm = await _service.requestNotificationPermission();
      _addLog(notifPerm 
          ? '   ✅ Notification permission granted'
          : '   ❌ Notification permission denied');

      _addLog('3️⃣ Requesting location permission...');
      final locPerm = await _service.requestLocationPermission();
      _addLog(locPerm 
          ? '   ✅ Location permission granted'
          : '   ❌ Location permission denied');

      // Test 3: Get FCM token
      _addLog('4️⃣ Getting FCM token...');
      final token = await _service.getFCMToken();
      if (token != null) {
        _addLog('   ✅ FCM Token: ${token.substring(0, 20)}...');
      } else {
        _addLog('   ❌ Failed to get FCM token');
      }

      // Test 4: Get location
      _addLog('5️⃣ Getting current location...');
      final position = await _service.getCurrentLocation();
      if (position != null) {
        _addLog('   ✅ Location: ${position.latitude}, ${position.longitude}');
        
        // Test 5: Reverse geocode
        _addLog('6️⃣ Getting city name...');
        final cityInfo = await _service.getCityFromCoordinates(
          position.latitude,
          position.longitude,
        );
        _addLog('   ✅ City: ${cityInfo['name']}');
      } else {
        _addLog('   ❌ Failed to get location');
      }

      // Test 6: Full setup
      _addLog('7️⃣ Running full setup...');
      final success = await _service.setupUserForWeatherNotifications();
      _addLog(success
          ? '   ✅ Full setup successful!'
          : '   ❌ Setup failed');

      // Test 7: Verify in Firestore
      _addLog('8️⃣ Checking Firestore...');
      final isSetup = await _service.isUserSetup();
      _addLog(isSetup
          ? '   ✅ User data saved to Firestore'
          : '   ⚠️ User data not found in Firestore');

      if (isSetup) {
        final savedLocation = await _service.getUserLocation();
        _addLog('   📍 Saved location: ${savedLocation?['name']}');
      }

      _addLog('');
      _addLog('✅ TEST COMPLETE!');
      _addLog('');
      _addLog('Next steps:');
      _addLog('1. Check Firestore console for user data');
      _addLog('2. Test manual trigger:');
      _addLog('   curl https://asia-south1-terafarmsih.cloudfunctions.net/sendManualWeatherForecast');
      _addLog('3. Wait for scheduled notification (every 30 min)');

    } catch (e) {
      _addLog('❌ TEST FAILED: $e');
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Notification Test'),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text(
                  'Weather Notification Service Test',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will test permissions, location, FCM token, and Firestore integration',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isRunning ? null : _runTest,
                  icon: _isRunning
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.play_arrow),
                  label: Text(_isRunning ? 'Running...' : 'Run Test'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'Press "Run Test" to start',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _logs.length,
                    itemBuilder: (context, index) {
                      final log = _logs[index];
                      Color? textColor;
                      
                      if (log.contains('✅')) {
                        textColor = Colors.green;
                      } else if (log.contains('❌')) {
                        textColor = Colors.red;
                      } else if (log.contains('⚠️')) {
                        textColor = Colors.orange;
                      } else if (log.contains('🧪') || log.contains('TEST')) {
                        textColor = Colors.blue;
                      }

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4.0),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: textColor,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: _logs.isNotEmpty
          ? FloatingActionButton(
              onPressed: () {
                setState(() => _logs.clear());
              },
              child: const Icon(Icons.clear),
              backgroundColor: Colors.red,
            )
          : null,
    );
  }
}

/// Test app main entry point
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    print('Firebase init error: $e');
  }

  runApp(const WeatherNotificationTestApp());
}

class WeatherNotificationTestApp extends StatelessWidget {
  const WeatherNotificationTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Notification Test',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const WeatherNotificationTest(),
    );
  }
}
