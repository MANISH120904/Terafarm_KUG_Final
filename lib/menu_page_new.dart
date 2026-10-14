import 'package:TeraFarm/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'account_page.dart';
import 'home_page.dart';
import 'services/dev_auth_helper.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({Key? key}) : super(key: key);

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  late Future<Map<String, String>> _userDataFuture;

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
  }

  Future<Map<String, String>> _fetchUserData() async {
    try {
      if (DevAuthHelper.isOffline && DevAuthHelper.offlineProfile != null) {
        final profile = DevAuthHelper.offlineProfile!;
        return {
          'username': profile.displayName.isNotEmpty ? profile.displayName : 'Farmer',
          'profileImage': '',
          'email': profile.email,
        };
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return {'username': 'Farmer', 'profileImage': '', 'email': ''};
      }

      String username = user.displayName ?? '';
      String profileImage = user.photoURL ?? '';
      String email = user.email ?? '';

      if (username.isEmpty && email.isNotEmpty) {
        final localPart = email.split('@').first;
        if (localPart.isNotEmpty) {
          username = localPart[0].toUpperCase() + localPart.substring(1);
        }
      }
      if (username.isEmpty) {
        username = 'Farmer';
      }

      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            final firestoreName = data['username'] ??
                data['displayName'] ??
                data['name'] ??
                data['fullName'];
            if (firestoreName != null && firestoreName.toString().trim().isNotEmpty) {
              username = firestoreName.toString().trim();
            }

            final firestoreImage = data['profileImage'] ??
                data['photoURL'] ??
                data['imageUrl'];
            if (firestoreImage != null && firestoreImage.toString().trim().isNotEmpty) {
              profileImage = firestoreImage.toString().trim();
            }

            final firestoreEmail = data['email'];
            if (firestoreEmail != null && firestoreEmail.toString().trim().isNotEmpty) {
              email = firestoreEmail.toString().trim();
            }
          }
        }
      } catch (firestoreError) {
        debugPrint('Firestore fetch error in MenuPage: $firestoreError');
      }

      return {
        'username': username,
        'profileImage': profileImage,
        'email': email,
      };
    } catch (e) {
      debugPrint('Error in _fetchUserData: $e');
      final fallbackUser = FirebaseAuth.instance.currentUser;
      return {
        'username': fallbackUser?.displayName ?? (fallbackUser?.email?.split('@').first ?? 'Farmer'),
        'profileImage': fallbackUser?.photoURL ?? '',
        'email': fallbackUser?.email ?? '',
      };
    }
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 5,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF246B40).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF246B40),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey.shade400,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF246B40),
                    const Color(0xFF2E8B57),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF246B40).withOpacity(0.3),
                    blurRadius: 15,
                    spreadRadius: 3,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: DrawerHeader(
                decoration: const BoxDecoration(color: Colors.transparent),
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: FutureBuilder<Map<String, String>>(
                  future: _userDataFuture,
                  builder: (context, snapshot) {
                    final data = snapshot.data ?? {};
                    final fallbackUser = FirebaseAuth.instance.currentUser;
                    final username = (data['username'] != null && data['username']!.isNotEmpty)
                        ? data['username']!
                        : (fallbackUser?.displayName?.isNotEmpty == true
                            ? fallbackUser!.displayName!
                            : (fallbackUser?.email?.split('@').first ?? loc.userName));
                    final profileImage = data['profileImage'] ?? fallbackUser?.photoURL ?? '';
                    final email = data['email'] ?? fallbackUser?.email ?? '';

                    return Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                spreadRadius: 2,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: profileImage.isNotEmpty
                              ? CircleAvatar(
                                  radius: 25,
                                  backgroundImage: NetworkImage(profileImage),
                                )
                              : const CircleAvatar(
                                  radius: 25,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.account_circle,
                                    size: 32,
                                    color: Color(0xFF246B40),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                username.isNotEmpty ? username : loc.userName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (email.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildMenuItem(
                      icon: Icons.account_circle,
                      title: loc.account,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const AccountPage(),
                            transitionDuration: const Duration(milliseconds: 300),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              var scaleAnimation = Tween<double>(
                                begin: 0.9,
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
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      icon: Icons.home,
                      title: loc.home,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
                            transitionDuration: const Duration(milliseconds: 300),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              var scaleAnimation = Tween<double>(
                                begin: 0.9,
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
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      icon: Icons.shopping_bag,
                      title: loc.myOrders,
                      onTap: () {
                        // TODO: Implement My Orders page navigation
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildMenuItem(
                      icon: Icons.agriculture,
                      title: loc.farm,
                      onTap: () {
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const HomePage(),
                            transitionDuration: const Duration(milliseconds: 300),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              var scaleAnimation = Tween<double>(
                                begin: 0.9,
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
                      },
                    ),
                    
                    const Spacer(),
                    
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 30),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red.shade500,
                            Colors.orange.shade600,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(15),
                          onTap: () => _logout(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.logout,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  loc.logout,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
