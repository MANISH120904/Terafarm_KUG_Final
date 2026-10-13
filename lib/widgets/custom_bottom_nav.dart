import 'package:flutter/material.dart';

import '../services/navigation_service.dart';
import '../l10n/app_localizations.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  
  const CustomBottomNav({
    Key? key,
    required this.currentIndex,
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
            fontSize: 11,
            letterSpacing: 0.3,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 10,
          ),
          onTap: (i) {
            NavigationService.navigateToPage(context, i, currentIndex);
          },
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentIndex == 0 
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: currentIndex == 0 
                    ? Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      )
                    : null,
                ),
                child: const Icon(Icons.home_rounded, size: 22),
              ),
              label: loc.home,
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentIndex == 1 
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: currentIndex == 1 
                    ? Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      )
                    : null,
                ),
                child: const Icon(Icons.shopping_bag_outlined, size: 20),
              ),
              label: loc.market,
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentIndex == 2 
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: currentIndex == 2 
                    ? Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      )
                    : null,
                ),
                child: const Icon(Icons.auto_awesome, size: 20),
              ),
              label: loc.tools,
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentIndex == 3 
                    ? Colors.white.withOpacity(0.2)
                    : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: currentIndex == 3 
                    ? Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1.5,
                      )
                    : null,
                ),
                child: const Icon(Icons.people_outline, size: 20),
              ),
              label: loc.community,
            ),
          ],
        ),
      ),
    );
  }
}
