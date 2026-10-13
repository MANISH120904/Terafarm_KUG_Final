import 'package:flutter/material.dart';

import '../seller_page.dart';
import '../marketplace.dart';
import '../ai_page.dart';
import '../Community_page.dart';
import '../home_page.dart';
import '../main_navigation.dart';

class NavigationService {
  static const int homeIndex = 0;
  static const int marketIndex = 1;
  static const int aiIndex = 2;
  static const int communityIndex = 3;

  // Page route mapping
  static Widget getPageByIndex(int index) {
    switch (index) {
      case homeIndex:
        return const SellerPage();
      case marketIndex:
        return const MarketplacePage();
      case aiIndex:
        return const AIPage();
      case communityIndex:
        return const CommunityPage();
      default:
        return const SellerPage();
    }
  }

  // Navigate to page with static bottom navigation
  static void navigateToPage(BuildContext context, int targetIndex, int currentIndex) {
    if (targetIndex == currentIndex) return;

    final wrapper = StaticNavigationWrapper.of(context);
    if (wrapper != null) {
      // Use the static navigation wrapper if available
      wrapper.onPageChanged(targetIndex);
    } else {
      // Fallback to previous navigation for backward compatibility
      final targetPage = getPageByIndex(targetIndex);
      
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetPage,
          transitionDuration: const Duration(milliseconds: 400),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Smooth scale and fade transition
            var scaleAnimation = Tween<double>(
              begin: 0.85,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ));
            
            var fadeAnimation = Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ));
            
            return FadeTransition(
              opacity: fadeAnimation,
              child: ScaleTransition(
                scale: scaleAnimation,
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  // Navigate to buyer/farmer toggle with static navigation
  static void navigateToBuyerSeller(BuildContext context, bool isSeller) {
    final wrapper = StaticNavigationWrapper.of(context);
    if (wrapper != null) {
      // Use the static navigation wrapper if available
      wrapper.onModeChanged(!isSeller); // isBuyerMode = !isSeller
    } else {
      // Fallback to previous navigation for backward compatibility
      Widget targetPage = isSeller ? const SellerPage() : const HomePage();
      
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => targetPage,
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: animation,
                child: child,
              ),
            );
          },
        ),
      );
    }
  }

  // Get page title by index
  static String getPageTitle(int index) {
    switch (index) {
      case homeIndex:
        return 'Home';
      case marketIndex:
        return 'Marketplace';
      case aiIndex:
        return 'AI Tools';
      case communityIndex:
        return 'Community';
      default:
        return 'TeraFarm';
    }
  }
}
