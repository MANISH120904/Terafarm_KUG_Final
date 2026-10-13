import 'package:flutter/material.dart';

import 'seller_page.dart';
import 'marketplace.dart';
import 'ai_page.dart';
import 'Community_page.dart';
import 'home_page.dart';
import 'services/navigation_service.dart';
import 'l10n/app_localizations.dart';

class MainNavigation extends StatefulWidget {
  final int initialIndex;
  final bool isBuyerMode;
  
  const MainNavigation({
    Key? key,
    this.initialIndex = 0,
    this.isBuyerMode = false,
  }) : super(key: key);

  @override
  _MainNavigationState createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  bool _isBuyerMode = false;
  
  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _isBuyerMode = widget.isBuyerMode;
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _toggleBuyerSellerMode(bool isBuyer) {
    setState(() {
      _isBuyerMode = isBuyer;
      _currentIndex = 0; // Reset to home when switching modes
    });
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case NavigationService.homeIndex:
        return _isBuyerMode ? const HomePage() : const SellerPage();
      case NavigationService.marketIndex:
        return const MarketplacePage();
      case NavigationService.aiIndex:
        return const AIPage();
      case NavigationService.communityIndex:
        return const CommunityPage();
      default:
        return _isBuyerMode ? const HomePage() : const SellerPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeInOut,
        switchOutCurve: Curves.easeInOut,
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.95,
                end: 1.0,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: StaticNavigationWrapper(
            currentIndex: _currentIndex,
            isBuyerMode: _isBuyerMode,
            onPageChanged: _onPageChanged,
            onModeChanged: _toggleBuyerSellerMode,
            child: _getCurrentPage(),
          ),
        ),
      ),
      bottomNavigationBar: _isBuyerMode ? null : StaticBottomNav(
        currentIndex: _currentIndex,
        onTap: _onPageChanged,
      ),
    );
  }
}

class StaticNavigationWrapper extends InheritedWidget {
  final int currentIndex;
  final bool isBuyerMode;
  final Function(int) onPageChanged;
  final Function(bool) onModeChanged;

  const StaticNavigationWrapper({
    Key? key,
    required this.currentIndex,
    required this.isBuyerMode,
    required this.onPageChanged,
    required this.onModeChanged,
    required Widget child,
  }) : super(key: key, child: child);

  static StaticNavigationWrapper? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<StaticNavigationWrapper>();
  }

  @override
  bool updateShouldNotify(StaticNavigationWrapper oldWidget) {
    return currentIndex != oldWidget.currentIndex || 
           isBuyerMode != oldWidget.isBuyerMode;
  }
}

class StaticBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  
  const StaticBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF407944),
            const Color(0xFF2F5A32),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF407944).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, -5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white.withOpacity(0.6),
          currentIndex: currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 10,
            letterSpacing: 0.1,
            height: 1.1,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 9,
            height: 1.1,
          ),
          selectedFontSize: 10,
          unselectedFontSize: 9,
          onTap: onTap,
          items: [
            BottomNavigationBarItem(
              icon: _NavIcon(Icons.home_rounded, 0),
              label: loc.home,
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(Icons.shopping_bag_outlined, 1),
              label: loc.market,
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(Icons.auto_awesome, 2),
              label: loc.tools,
            ),
            BottomNavigationBarItem(
              icon: _NavIcon(Icons.people_outline, 3),
              label: loc.community,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final int index;
  
  const _NavIcon(this.icon, this.index);

  @override
  Widget build(BuildContext context) {
    final wrapper = StaticNavigationWrapper.of(context);
    final isSelected = wrapper?.currentIndex == index;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected 
          ? Colors.white.withOpacity(0.2)
          : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isSelected 
          ? Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1.5,
            )
          : null,
      ),
      child: Icon(icon, size: 22),
    );
  }
}
