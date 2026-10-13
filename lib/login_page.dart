import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io' show Platform;
import 'main_navigation.dart';
import 'create_account_page.dart';
import 'services/google_auth_service.dart';
import 'services/dev_auth_helper.dart';
import 'utils/fcm_token_manager.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore_firestore = FirebaseFirestore.instance;
  final GoogleAuthService _googleAuthService = GoogleAuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false; // State variable to track loading

  void _loginUser(BuildContext context) async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // Setup weather notifications after successful login
      _setupWeatherNotifications(context);

      // Navigate directly to MainNavigation (buyer mode) after successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainNavigation(isBuyerMode: true)),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Login Failed: ${e.toString()}")));
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  void _loginWithGoogle(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential? userCredential = await _googleAuthService.signInWithGoogle();
      
      if (userCredential != null) {
        // Setup weather notifications after successful login
        _setupWeatherNotifications(context);
        
        // Navigate to MainNavigation after successful Google login
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainNavigation(isBuyerMode: true)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_googleAuthService.getErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Developer bypass for emulator testing
  void _devLogin(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final UserCredential? userCredential = await DevAuthHelper.signInAsFarmer();
      
      if (userCredential != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🧪 Logged in as Test Farmer'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Setup weather notifications after successful login
        _setupWeatherNotifications(context);
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainNavigation(isBuyerMode: true)),
        );
      } else if (DevAuthHelper.isOffline && DevAuthHelper.offlineProfile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offline dev mode enabled – data will not sync.'),
            backgroundColor: Colors.orange,
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => MainNavigation(isBuyerMode: true)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Dev login failed: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Setup weather notifications for logged in user
  void _setupWeatherNotifications(BuildContext context) async {
    try {
      debugPrint('🌤️ Setting up weather notifications for logged-in user...');
      
      // Use the centralized FCM Token Manager
      final fcmManager = FCMTokenManager();
      final tokenUpdated = await fcmManager.onLogin(); // Simplified method for login
      
      if (tokenUpdated) {
        debugPrint('✅ FCM token and location updated successfully!');
        debugPrint('� User will receive personalized weather notifications');
        
        // Optional: Show success message to user
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🌤️ Weather notifications enabled!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        debugPrint('⚠️ FCM token update incomplete');
        debugPrint('💡 User may need to grant permissions manually');
      }
    } catch (e) {
      debugPrint('❌ Error setting up weather notifications: $e');
      // Don't show error to user - this is a background feature
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset:
          true, // Allow layout to adjust when keyboard appears
      backgroundColor: Colors.transparent, // Ensure transparency
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(
                0.3,
              ), // Semi-transparent white overlay
              image: DecorationImage(
                image: AssetImage("assets/login_bg.png"),
                fit: BoxFit.cover,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20).copyWith(
              top: MediaQuery.of(context).padding.top + 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: Duration(
                      milliseconds: 300,
                    ), // Smooth animation duration
                    curve: Curves.easeInOut, // Smooth easing curve
                    padding: EdgeInsets.only(
                      top: 40,
                      bottom:
                          MediaQuery.of(context).viewInsets.bottom +
                          20, // Adjust for keyboard
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Hello!",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(
                            height: 10,
                          ), // Add spacing between "Hello!" and "Login"
                          Text(
                            "Login",
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.orangeAccent,
                            ),
                          ),
                          SizedBox(
                            height: 30,
                          ), // Add spacing before the text fields

                          _buildTextField("Email Address", emailController),
                          SizedBox(
                            height: 15,
                          ), // Add spacing between the text fields
                          _buildTextField(
                            "Password",
                            passwordController,
                            isPassword: true,
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom Section
                Column(
                  children: [
                    _isLoading
                        ? CircularProgressIndicator() // Show loading indicator
                        : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed: () => _loginUser(context),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Login",
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_forward, color: Colors.white),
                            ],
                          ),
                        ),
                    
                    SizedBox(height: 15),
                    
                    // Divider with "OR"
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.5))),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 15),
                          child: Text(
                            "OR",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.white.withOpacity(0.5))),
                      ],
                    ),
                    
                    SizedBox(height: 15),
                    
                    // Google Sign-in Button
                    _isLoading
                        ? Container() // Hide Google button when loading
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            onPressed: () => _loginWithGoogle(context),
                            icon: Image.asset(
                              'assets/google.png', // Make sure you have Google logo in assets
                              height: 24,
                              width: 24,
                            ),
                            label: Text(
                              "Continue with Google",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                    
                    SizedBox(height: 20),
                    
                    // Developer Mode Button (Emulator only)
                    if (Platform.isAndroid)
                      Column(
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.orangeAccent,
                              side: BorderSide(color: Colors.orangeAccent),
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            onPressed: () => _devLogin(context),
                            icon: Icon(Icons.science, size: 20),
                            label: Text(
                              DevAuthHelper.isOffline
                                  ? "🛟 Dev Login (Offline)"
                                  : "🧪 Dev Login (Emulator)",
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            DevAuthHelper.isOffline
                                ? "Offline mode: local data only"
                                : "Test account: farmer@terafarm.dev",
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.6),
                              fontSize: 11,
                            ),
                          ),
                          SizedBox(height: 15),
                        ],
                      ),
                    
                    Center(
                      child: TextButton(
                        onPressed:
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateAccountPage(),
                              ),
                            ),
                        child: Text(
                          "Don't have an account? Sign up",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.white)),
        SizedBox(height: 5),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        SizedBox(height: 10),
      ],
    );
  }
}
