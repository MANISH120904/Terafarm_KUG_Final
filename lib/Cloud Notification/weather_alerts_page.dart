import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'weather_notification_service.dart';

/// Weather Alerts History Page
/// Displays all weather alerts received by the user
class WeatherAlertsPage extends StatefulWidget {
  const WeatherAlertsPage({Key? key}) : super(key: key);

  @override
  State<WeatherAlertsPage> createState() => _WeatherAlertsPageState();
}

class _WeatherAlertsPageState extends State<WeatherAlertsPage> {
  final WeatherNotificationService _weatherService = WeatherNotificationService();

  @override
  void initState() {
    super.initState();
    _weatherService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Alerts'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _weatherService.checkWeatherAlerts();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Checking for weather alerts...')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Current Weather Card
          _buildCurrentWeatherCard(),
          
          const Divider(height: 1),
          
          // Alerts History
          Expanded(
            child: _buildAlertsHistory(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _weatherService.sendDailyForecast();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Forecast notification sent!')),
            );
          }
        },
        icon: const Icon(Icons.wb_sunny),
        label: const Text('Daily Forecast'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  Widget _buildCurrentWeatherCard() {
    return FutureBuilder<Position?>(
      future: _weatherService.getCurrentLocation(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final position = snapshot.data!;
        return FutureBuilder<Map<String, dynamic>?>(
          future: _weatherService.fetchWeatherData(position.latitude, position.longitude),
          builder: (context, weatherSnapshot) {
            if (!weatherSnapshot.hasData) {
              return const Card(
                margin: EdgeInsets.all(16),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final weather = weatherSnapshot.data!;
            final temp = weather['main']['temp'];
            final condition = weather['weather'][0]['main'];
            final description = weather['weather'][0]['description'];
            final humidity = weather['main']['humidity'];
            final windSpeed = weather['wind']['speed'];

            return Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📍 Current Location',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        IconButton(
                          icon: const Icon(Icons.location_on),
                          onPressed: () {
                            _weatherService.getCurrentLocation();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${temp.toStringAsFixed(1)}°C',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                            Text(
                              condition,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _weatherInfoRow(Icons.water_drop, '$humidity%'),
                            const SizedBox(height: 8),
                            _weatherInfoRow(Icons.air, '${windSpeed.toStringAsFixed(1)} m/s'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _weatherInfoRow(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildAlertsHistory() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('weather_alerts')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wb_sunny, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'No weather alerts yet',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                SizedBox(height: 8),
                Text(
                  'You\'ll be notified of severe weather',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            
            final title = data['title'] ?? 'Weather Alert';
            final message = data['message'] ?? '';
            final location = data['location'] ?? 'Unknown';
            final timestamp = data['timestamp'] as Timestamp?;
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _getAlertColor(title),
                  child: _getAlertIcon(title),
                ),
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(message),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        if (timestamp != null)
                          Text(
                            _formatTimestamp(timestamp),
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                      ],
                    ),
                  ],
                ),
                isThreeLine: true,
              ),
            );
          },
        );
      },
    );
  }

  Color _getAlertColor(String title) {
    if (title.contains('Extreme') || title.contains('Severe')) {
      return Colors.red;
    } else if (title.contains('Heavy') || title.contains('High')) {
      return Colors.orange;
    } else if (title.contains('Cold')) {
      return Colors.blue;
    }
    return Colors.green;
  }

  Icon _getAlertIcon(String title) {
    if (title.contains('Heat')) {
      return const Icon(Icons.wb_sunny, color: Colors.white);
    } else if (title.contains('Cold')) {
      return const Icon(Icons.ac_unit, color: Colors.white);
    } else if (title.contains('Storm') || title.contains('Thunder')) {
      return const Icon(Icons.flash_on, color: Colors.white);
    } else if (title.contains('Rain')) {
      return const Icon(Icons.water_drop, color: Colors.white);
    } else if (title.contains('Wind')) {
      return const Icon(Icons.air, color: Colors.white);
    }
    return const Icon(Icons.warning, color: Colors.white);
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  void dispose() {
    _weatherService.dispose();
    super.dispose();
  }
}
