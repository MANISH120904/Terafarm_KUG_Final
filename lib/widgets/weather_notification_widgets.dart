import 'package:flutter/material.dart';
import 'package:TeraFarm/services/weather_notification_service.dart';

/// Widget to setup weather notifications on user login
/// Shows loading state and error handling
class WeatherNotificationSetup extends StatefulWidget {
  final VoidCallback? onSuccess;
  final VoidCallback? onError;
  final bool autoStart;

  const WeatherNotificationSetup({
    Key? key,
    this.onSuccess,
    this.onError,
    this.autoStart = true,
  }) : super(key: key);

  @override
  State<WeatherNotificationSetup> createState() => _WeatherNotificationSetupState();
}

class _WeatherNotificationSetupState extends State<WeatherNotificationSetup> {
  final _weatherService = WeatherNotificationService();
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      _setupWeatherNotifications();
    }
  }

  Future<void> _setupWeatherNotifications() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Setting up weather notifications...';
    });

    try {
      final success = await _weatherService.initialize();

      setState(() {
        _isLoading = false;
        _isSuccess = success;
        _statusMessage = success
            ? '✅ Weather notifications enabled!'
            : '❌ Failed to setup weather notifications';
      });

      if (success && widget.onSuccess != null) {
        widget.onSuccess!();
      } else if (!success && widget.onError != null) {
        widget.onError!();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = '❌ Error: $e';
      });

      if (widget.onError != null) {
        widget.onError!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Setting up weather notifications...'),
          ],
        ),
      );
    }

    if (_statusMessage != null && !widget.autoStart) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSuccess ? Icons.check_circle : Icons.error,
              color: _isSuccess ? Colors.green : Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            if (!_isSuccess)
              ElevatedButton(
                onPressed: _setupWeatherNotifications,
                child: const Text('Try Again'),
              ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

/// Button widget to manually update user location
class UpdateLocationButton extends StatefulWidget {
  const UpdateLocationButton({Key? key}) : super(key: key);

  @override
  State<UpdateLocationButton> createState() => _UpdateLocationButtonState();
}

class _UpdateLocationButtonState extends State<UpdateLocationButton> {
  final _weatherService = WeatherNotificationService();
  bool _isUpdating = false;

  Future<void> _updateLocation() async {
    setState(() => _isUpdating = true);

    final success = await _weatherService.updateUserLocation();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✅ Location updated successfully!'
              : '❌ Failed to update location',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );

    setState(() => _isUpdating = false);
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isUpdating ? null : _updateLocation,
      icon: _isUpdating
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location),
      label: Text(_isUpdating ? 'Updating...' : 'Update Location'),
    );
  }
}

/// Card widget showing user's current location for weather
class WeatherLocationCard extends StatefulWidget {
  const WeatherLocationCard({Key? key}) : super(key: key);

  @override
  State<WeatherLocationCard> createState() => _WeatherLocationCardState();
}

class _WeatherLocationCardState extends State<WeatherLocationCard> {
  final _weatherService = WeatherNotificationService();
  Map<String, dynamic>? _location;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    final location = await _weatherService.getUserLocation();
    setState(() {
      _location = location;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_location == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(Icons.location_off, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              const Text('No location set'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() => _isLoading = true);
                  await _weatherService.updateUserLocation();
                  await _loadLocation();
                },
                icon: const Icon(Icons.my_location),
                label: const Text('Set Location'),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.place, color: Colors.green),
                const SizedBox(width: 8),
                const Text(
                  'Weather Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildLocationRow('City', _location!['name'] ?? 'Unknown'),
            if (_location!['state'] != null)
              _buildLocationRow('State', _location!['state']),
            if (_location!['country'] != null)
              _buildLocationRow('Country', _location!['country']),
            _buildLocationRow(
              'Coordinates',
              '${_location!['latitude']?.toStringAsFixed(4)}, ${_location!['longitude']?.toStringAsFixed(4)}',
            ),
            const SizedBox(height: 16),
            const UpdateLocationButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }
}

/// Toggle switch for weather notifications
class WeatherNotificationToggle extends StatefulWidget {
  const WeatherNotificationToggle({Key? key}) : super(key: key);

  @override
  State<WeatherNotificationToggle> createState() => _WeatherNotificationToggleState();
}

class _WeatherNotificationToggleState extends State<WeatherNotificationToggle> {
  final _weatherService = WeatherNotificationService();
  bool _isEnabled = true;
  bool _isLoading = false;

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _isLoading = true);

    final success = value
        ? await _weatherService.enableWeatherNotifications()
        : await _weatherService.disableWeatherNotifications();

    if (success) {
      setState(() {
        _isEnabled = value;
        _isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '✅ Weather notifications enabled'
                : '⚠️ Weather notifications disabled',
          ),
        ),
      );
    } else {
      setState(() => _isLoading = false);
      
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to update notification settings'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Weather Notifications'),
      subtitle: const Text('Receive daily weather forecasts'),
      value: _isEnabled,
      onChanged: _isLoading ? null : _toggleNotifications,
      secondary: const Icon(Icons.wb_sunny),
    );
  }
}
