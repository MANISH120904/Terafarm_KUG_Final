import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'main_navigation.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  Timer? _redirectTimer;

  @override
  void initState() {
    super.initState();
    _redirectTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      try {
        if (FirebaseAuth.instance.currentUser != null) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) =>
                  MainNavigation(isBuyerMode: true),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      } catch (e) {
        debugPrint('Auth redirect skipped: $e');
      }
    });
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isLoggedIn = false;
    try {
      isLoggedIn = FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      isLoggedIn = false;
    }
    // Match TeraFarm sibling landing dimensions / spacing
    final logoTopGap = isLoggedIn ? 20.0 : 60.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: const Color(0xFF1E633A),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Short screens: scroll. Normal phones: Spacers push logo/tagline
            // to middle/bottom like the original layout.
            final useSpacers = constraints.maxHeight >= 560;

            final column = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 80),
                const Text(
                  'TeraFarm',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text.rich(
                  TextSpan(
                    text: 'Grow, Sell, ',
                    style: const TextStyle(fontSize: 20, color: Colors.white),
                    children: [
                      TextSpan(
                        text: 'Connect!',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.orangeAccent.shade100,
                        ),
                      ),
                    ],
                  ),
                ),
                if (useSpacers) const Spacer() else SizedBox(height: logoTopGap),
                if (useSpacers) SizedBox(height: logoTopGap),
                Center(
                  child: Image.asset('assets/logo.png', width: 250),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Transform.translate(
                    offset: const Offset(10, 0),
                    child: Image.asset(
                      'assets/terafarm_logo.png',
                      width: 250,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                if (useSpacers) const Spacer() else const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'Earn. Eat fresh.\nBuild a greener city.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),
                if (!isLoggedIn)
                  Center(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginPage(),
                          ),
                        );
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 50),
              ],
            );

            if (useSpacers) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: column,
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: column,
            );
          },
        ),
      ),
    );
  }
}
