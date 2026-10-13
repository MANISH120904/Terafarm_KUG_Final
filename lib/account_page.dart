import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_page.dart';
import 'edit_profile_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({Key? key}) : super(key: key);

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage>
    with TickerProviderStateMixin {
  bool _animate = false;

  Future<Map<String, dynamic>> _fetchUserDetails() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      return userDoc.data() ?? {};
    }
    return {};
  }

  void _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  // Award XP and update level logic.
  // Daily task completion awards 5 XP and weekly tasks award 10 XP.
  // This function is for testing or syncing XP when required.
  void _updateXP(int xpEarned) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final userDoc = await userRef.get();
      if (userDoc.exists) {
        int currentXP = userDoc['xp'] ?? 0;
        int currentLevel = userDoc['level'] ?? 2;
        currentXP += xpEarned;
        while (currentXP >= _getLevelUpThreshold(currentLevel)) {
          currentXP -= _getLevelUpThreshold(currentLevel);
          currentLevel++;
        }
        await userRef.update({'xp': currentXP, 'level': currentLevel});
      }
    }
  }

  // This helper calculates the dynamic XP threshold: increases by 5 per level.
  int _getLevelUpThreshold(int level) => 20 + (level - 1) * 5;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _animate = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchUserDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading profile"));
          }

          final userDetails = snapshot.data ?? {};
          int level = userDetails['level'] ?? 2;
          int xp = userDetails['xp'] ?? 0;
          int threshold = _getLevelUpThreshold(level);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.grey[200],
                            backgroundImage:
                                userDetails['profileImage'] != null
                                    ? NetworkImage(userDetails['profileImage'])
                                    : null,
                            child:
                                userDetails['profileImage'] == null
                                    ? const Icon(Icons.person, size: 50)
                                    : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.orange,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const EditProfilePage(),
                                    ),
                                  );
                                },
                                child: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        userDetails['username'] ?? 'User Name',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Buyer / Seller",
                        style: TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: () => _showLevelRoadmap(context),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              child: Text(
                                "Lvl $level",
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: threshold > 0 ? xp / threshold : 0,
                                  backgroundColor: Colors.grey,
                                  color: Colors.blue,
                                  minHeight: 5,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "$xp/$threshold XP",
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buildAnimatedTile(
                  0,
                  _infoTile(
                    Icons.phone,
                    userDetails['phone'] ?? '+91 00000 00000',
                  ),
                ),
                _buildAnimatedTile(
                  1,
                  _infoTile(
                    Icons.email_outlined,
                    userDetails['email'] ?? 'example@email.com',
                  ),
                ),
                const SizedBox(height: 20),
                _buildAnimatedTile(
                  2,
                  _menuTile(Icons.favorite_border, 'My Orders'),
                ),
                _buildAnimatedTile(
                  3,
                  _menuTile(Icons.local_play_outlined, 'Badges'),
                ),
                _buildAnimatedTile(
                  4,
                  _menuTile(Icons.location_on_outlined, 'My Addresses'),
                ),
                _buildAnimatedTile(
                  5,
                  _menuTile(Icons.list_alt_rounded, 'My List'),
                ),
                _buildAnimatedTile(
                  6,
                  _menuTile(
                    Icons.logout,
                    'Logout',
                    onTap: () => _logout(context),
                    isLogout: true,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimatedTile(int index, Widget child) {
    return AnimatedSlide(
      offset: _animate ? Offset.zero : const Offset(0, 0.3),
      duration: Duration(milliseconds: 300 + (index * 100)),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        duration: Duration(milliseconds: 300 + (index * 100)),
        opacity: _animate ? 1 : 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: child,
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: Colors.deepPurple),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  Widget _menuTile(
    IconData icon,
    String label, {
    VoidCallback? onTap,
    bool isLogout = false,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: isLogout ? Colors.red : Colors.orange),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          color: isLogout ? Colors.red : Colors.black,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showLevelRoadmap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      "🎯 Level Roadmap",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(10, (index) {
                    int level = index + 1;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            level <= 20 ? Colors.green : Colors.grey,
                        child: Text("$level"),
                      ),
                      title: Text("Level $level"),
                      subtitle: Text("Reward: To be announced"),
                      trailing:
                          level == 20
                              ? const Icon(
                                Icons.check_circle,
                                color: Colors.blue,
                              )
                              : null,
                    );
                  }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
