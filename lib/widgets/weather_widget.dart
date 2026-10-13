import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:TeraFarm/providers/weather_provider.dart';
import 'dart:math';

class WeatherWidget extends StatefulWidget {
  final String buttonText;
  final Color primaryColor;

  const WeatherWidget({
    Key? key,
    required this.buttonText,
    required this.primaryColor,
  }) : super(key: key);

  @override
  WeatherWidgetState createState() => WeatherWidgetState();
}

class WeatherWidgetState extends State<WeatherWidget> with TickerProviderStateMixin {
  // Weather state is now managed by WeatherProvider

  late AnimationController _animationController;
  late AnimationController _buttonController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    
    // Main fade animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Button hover/press animation controller
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    // Wave background animation controller
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    
    // Check if weather data already exists, if so show it with animation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<WeatherProvider>(context, listen: false);
      if (provider.showWeather) {
        // Weather already exists, show it with smooth animation
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _buttonController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  Future<void> fetchWeather() async {
    // Delegate fetch to provider
    final provider = Provider.of<WeatherProvider>(context, listen: false);
    await provider.fetchWeather();
    // Restart fade animation on each fetch
    if (_animationController.isCompleted) _animationController.reset();
    _animationController.forward();
  }

  /// Maps a temperature (°C) to the hex‑based colors you supplied
  Color _getTempColor(double? t) {
    if (t == null) return widget.primaryColor;

    if (t <= -50)            return const Color(0xFF9C619B);
    else if (t <= -40)       return const Color.fromARGB(255, 253, 189, 255);
    else if (t <= -30)       return const Color(0xFFCE00D7);
    else if (t <= -20)       return const Color.fromARGB(255, 184, 184, 224);
    else if (t <= -10)       return const Color(0xFF5B97F8);
    else if (t <= 0)         return const Color(0xFF81E8FF);
    else if (t <= 5)         return const Color.fromARGB(255, 218, 242, 214);
    else if (t <= 15)        return const Color.fromARGB(255, 61, 230, 249);
    else if (t <= 25)        return const Color.fromARGB(255, 253, 183, 19);
    else if (t <= 35)        return const Color.fromARGB(255, 253, 183, 19);
    else if (t <= 45)        return const Color.fromARGB(255, 195, 195, 0);
    else /* >45 */           return const Color.fromARGB(255, 255, 0, 0);
  }

  IconData _getWeatherIcon(String? condition) {
    if (condition == null) return Icons.wb_sunny;
    final lc = condition.toLowerCase();
    if (lc.contains('heavy rain') || lc.contains('downpour')) return Icons.thunderstorm;
    if (lc.contains('rain') || lc.contains('shower'))          return Icons.grain;
    if (lc.contains('drizzle') || lc.contains('light rain'))   return Icons.water_drop;
    if (lc.contains('thunderstorm') || lc.contains('thunder')) return Icons.flash_on;
    if (lc.contains('storm'))                                  return Icons.bolt;
    if (lc.contains('partly cloudy') || lc.contains('partly cloud')) return Icons.wb_sunny;
    if (lc.contains('overcast') || lc.contains('cloudy'))      return Icons.cloud;
    if (lc.contains('clear') || lc.contains('sunny'))          return Icons.wb_sunny;
    if (lc.contains('blizzard'))                              return Icons.severe_cold;
    if (lc.contains('snow') || lc.contains('sleet'))           return Icons.ac_unit;
    if (lc.contains('fog') || lc.contains('mist') || lc.contains('haze')) return Icons.foggy;
    if (lc.contains('windy') || lc.contains('wind'))           return Icons.air;
    return Icons.wb_cloudy;
  }

  // Helper method to validate if an alert should be displayed as a banner
  bool _isValidWeatherAlert(String alert) {
    // Don't show generic error messages as weather alerts
    if (alert.toLowerCase().contains('could not fetch') ||
        alert.toLowerCase().contains('api error') ||
        alert.toLowerCase().contains('network error') ||
        alert.toLowerCase().contains('connection failed')) {
      return false;
    }
    
    // Only show actual weather-related alerts
    if (alert.toLowerCase().contains('rain') ||
        alert.toLowerCase().contains('storm') ||
        alert.toLowerCase().contains('snow') ||
        alert.toLowerCase().contains('sleet') ||
        alert.toLowerCase().contains('weather alert') ||
        alert.toLowerCase().contains('wind') ||
        alert.toLowerCase().contains('temperature')) {
      return true;
    }
    
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Wrap in Consumer to rebuild on provider updates
    return Consumer<WeatherProvider>(
      builder: (context, provider, child) {
        final showWeather = provider.showWeather;
        final loadingWeather = provider.loadingWeather;
        final temperature = provider.temperature;
        final humidity = provider.humidity;
        final condition = provider.condition;
        final alert = provider.alert; // Get weather alert
        final bgColor = showWeather
            ? _getTempColor(temperature)
            : widget.primaryColor;

        return Column(
          children: [
            // Weather alert banner (if any) - but exclude generic error messages
            if (alert != null && _isValidWeatherAlert(alert))
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.shade600,
                      Colors.red.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        alert,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            // Main weather widget
            Container(
              decoration: BoxDecoration(
                gradient: showWeather
                    ? LinearGradient(
                        colors: [
                          bgColor,
                          bgColor.withOpacity(0.8),
                          bgColor.withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        stops: const [0.0, 0.5, 1.0],
                      )
                    : LinearGradient(
                        colors: [
                          bgColor,
                          bgColor.withOpacity(0.9),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: showWeather
                    ? [
                        BoxShadow(
                          color: bgColor.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        ),
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 1,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: bgColor.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: loadingWeather ? null : fetchWeather,
                  onLongPress: () {
                    // Long press to send test notification
                    provider.sendTestNotification();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Test weather notification sent!'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                    child: _buildButtonContent(loadingWeather, showWeather, temperature, humidity, condition),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildButtonContent(bool loadingWeather, bool showWeather, double? temperature, int? humidity, String? condition) {
    if (loadingWeather) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Loading...',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    
    if (showWeather) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              _getWeatherIcon(condition),
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${temperature?.toStringAsFixed(1)}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                ),
              ),
              Text(
                '${humidity}% humidity',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return Text(
      widget.buttonText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  // Getters for parent access, delegate to provider
  bool get isShowingWeather =>
      Provider.of<WeatherProvider>(context, listen: false).showWeather;
  bool get isLoading =>
      Provider.of<WeatherProvider>(context, listen: false).loadingWeather;
  double? get temperature =>
      Provider.of<WeatherProvider>(context, listen: false).temperature;
  int? get humidity =>
      Provider.of<WeatherProvider>(context, listen: false).humidity;
  String? get condition =>
      Provider.of<WeatherProvider>(context, listen: false).condition;
}

// Custom painter for animated wave background
class WavePainter extends CustomPainter {
  final double animation;
  final Color color;

  WavePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final waveHeight = size.height * 0.1;
    final waveLength = size.width;
    final waveOffset = animation * waveLength;

    path.moveTo(-waveLength + waveOffset, size.height * 0.7);
    
    for (double x = -waveLength + waveOffset; x <= size.width + waveLength; x += 20) {
      final y = size.height * 0.7 + 
          waveHeight * sin((x - waveOffset) * 2 * pi / waveLength) +
          waveHeight * 0.5 * sin((x - waveOffset) * 4 * pi / waveLength);
      path.lineTo(x, y);
    }
    
    path.lineTo(size.width + waveLength, size.height);
    path.lineTo(-waveLength + waveOffset, size.height);
    path.close();

    canvas.drawPath(path, paint);
    
    // Second wave layer
    final paint2 = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
      
    final path2 = Path();
    path2.moveTo(-waveLength + waveOffset * 1.5, size.height * 0.8);
    
    for (double x = -waveLength + waveOffset * 1.5; x <= size.width + waveLength; x += 20) {
      final y = size.height * 0.8 + 
          waveHeight * 0.7 * sin((x - waveOffset * 1.5) * 3 * pi / waveLength);
      path2.lineTo(x, y);
    }
    
    path2.lineTo(size.width + waveLength, size.height);
    path2.lineTo(-waveLength + waveOffset * 1.5, size.height);
    path2.close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
