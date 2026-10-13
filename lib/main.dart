import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'landing_page.dart';
import 'plant_growth_analysis_page.dart';
import 'l10n/app_localizations.dart';
import 'package:TeraFarm/providers/weather_provider.dart';
import 'package:TeraFarm/Cloud Notification/notification_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load saved locale from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final savedLocaleCode = prefs.getString('locale_code');
  final initialLocale = savedLocaleCode != null
      ? Locale(savedLocaleCode)
      : const Locale('en');

  // Initialize Firebase first
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('✅ Firebase initialized successfully');

    // Initialize Weather Notification System
    final notificationManager = NotificationManager();
    await notificationManager.initialize();
    debugPrint('✅ Weather notification system initialized');
  } catch (e) {
    debugPrint('❌ Error initializing services: $e');
    // Continue anyway - app can still run without notifications
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(initialLocale),
        ),
        ChangeNotifierProvider(
          create: (_) => WeatherProvider(),
        ),
      ],
      child: const TeraFarmApp(),
    ),
  );
}

class LocaleProvider extends ChangeNotifier {
  Locale _locale;
  Locale get locale => _locale;

  LocaleProvider(this._locale);

  Future<void> setLocale(Locale locale) async {
    if (!AppLocalizations.supportedLocales.contains(locale)) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale_code', locale.languageCode);
  }
}

class TeraFarmApp extends StatelessWidget {
  const TeraFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LocaleProvider>(
      builder: (context, localeProvider, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: localeProvider.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supportedLocales) {
            if (locale == null) return supportedLocales.first;
            for (var supported in supportedLocales) {
              if (supported.languageCode == locale.languageCode) {
                return supported;
              }
            }
            return supportedLocales.first;
          },
          title: 'TeraFarm',
          home: const AuthWrapper(),
          routes: {
            '/growth-analysis': (_) => const PlantGrowthAnalysisPage(),
          },
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return const LandingPage();
  }
}
