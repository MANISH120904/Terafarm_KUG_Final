import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'landing_page.dart';
import 'plant_growth_analysis_page.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_locales.dart';
import 'package:TeraFarm/providers/weather_provider.dart';
import 'package:TeraFarm/Cloud Notification/notification_manager.dart';

/// Completes when Firebase (and light prefs) are ready for UI that needs them.
final Completer<void> appBootstrap = Completer<void>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Paint UI immediately — never await network/plugins before first frame.
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LocaleProvider(AppLocales.fallback),
        ),
        ChangeNotifierProvider(
          create: (_) => WeatherProvider(),
        ),
      ],
      child: const TeraFarmApp(),
    ),
  );

  unawaited(_bootstrapApp());
}

Future<void> _bootstrapApp() async {
  try {
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 2));
      final code = prefs.getString('locale_code');
      if (code != null) {
        // Locale applied after first frame via provider if needed.
        debugPrint('Locale from prefs: $code');
      }
    } catch (e) {
      debugPrint('Prefs load skipped: $e');
    }

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 12));
    }
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ Firebase init issue (continuing): $e');
  } finally {
    if (!appBootstrap.isCompleted) {
      appBootstrap.complete();
    }
  }

  // Notifications / FCM / location after UI is visible.
  unawaited(_initBackgroundServices());
}

Future<void> _initBackgroundServices() async {
  try {
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (Firebase.apps.isEmpty) return;
    final notificationManager = NotificationManager();
    await notificationManager
        .initialize()
        .timeout(const Duration(seconds: 20));
    debugPrint('✅ Weather notification system initialized');
  } catch (e) {
    debugPrint('❌ Background services init skipped: $e');
  }
}

class LocaleProvider extends ChangeNotifier {
  Locale _locale;
  Locale get locale => _locale;

  LocaleProvider(this._locale);

  Future<void> setLocale(Locale locale) async {
    final resolved = AppLocales.resolve(locale);
    if (!AppLocales.isSupported(resolved)) return;
    _locale = resolved;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locale_code', resolved.languageCode);
  }

  void setLocaleSync(Locale locale) {
    final resolved = AppLocales.resolve(locale);
    if (!AppLocales.isSupported(resolved)) return;
    _locale = resolved;
    notifyListeners();
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
          locale: AppLocales.resolve(localeProvider.locale),
          supportedLocales: AppLocales.supported,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, _) => AppLocales.resolve(locale),
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _waitForBootstrap();
  }

  Future<void> _waitForBootstrap() async {
    // Cap wait so we never stay stuck on splash forever.
    try {
      await appBootstrap.future.timeout(const Duration(seconds: 15));
    } catch (_) {}
    if (!mounted) return;

    // Apply saved locale after prefs/Firebase path had a chance to run.
    try {
      final prefs = await SharedPreferences.getInstance()
          .timeout(const Duration(seconds: 1));
      final code = prefs.getString('locale_code');
      if (code != null && mounted) {
        context.read<LocaleProvider>().setLocaleSync(
              AppLocales.fromCode(code),
            );
      }
    } catch (_) {}

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Same green as landing — avoids white screen while Firebase starts.
      return const Scaffold(
        backgroundColor: Color(0xFF1E633A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return const LandingPage();
  }
}
