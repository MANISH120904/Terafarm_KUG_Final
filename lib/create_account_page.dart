import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ✅ Firestore import
import 'login_page.dart';
import 'services/google_auth_service.dart';
import 'utils/fcm_token_manager.dart';

class CreateAccountPage extends StatefulWidget {
  const CreateAccountPage({super.key});

  @override
  _CreateAccountPageState createState() => _CreateAccountPageState();
}

class _CreateAccountPageState extends State<CreateAccountPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // ✅ Firestore instance
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController =
      TextEditingController(); // ✅ Username field
  final TextEditingController phoneController =
      TextEditingController(); // ✅ Phone field

  bool _isLoading = false; // Add a loading state

  void _registerUser() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });
    try {
      // Create user in Firebase Authentication
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      // Store additional user details in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'username': usernameController.text.trim(),
        'email': emailController.text.trim(),
        'phone': phoneController.text.trim(),
        'uid': userCredential.user!.uid,
      });

      // Setup weather notifications for new user
      _setupWeatherNotifications();

      // Redirect to Login Page after successful signup
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  void _signUpWithGoogle() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      UserCredential? userCredential = await _googleAuthService.signInWithGoogle();
      if (userCredential != null && userCredential.user != null) {
        // Setup weather notifications for new user
        _setupWeatherNotifications();
        
        // Redirect to home page or wherever appropriate after successful Google sign-up
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully signed up with Google!')),
        );
        // Navigate to your home page here
        // Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google Sign-up failed: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Setup weather notifications for new user
  void _setupWeatherNotifications() async {
    try {
      debugPrint('🌤️ Setting up weather notifications for new user...');
      
      // Use the centralized FCM Token Manager for new users
      final fcmManager = FCMTokenManager();
      final success = await fcmManager.onSignup(); // Simplified method for signup
      
      if (success) {
        debugPrint('✅ Weather notifications enabled for new user!');
        debugPrint('📱 User will receive personalized weather notifications');
      } else {
        debugPrint('⚠️ Weather notifications setup incomplete');
      }
    } catch (e) {
      debugPrint('❌ Error setting up weather notifications: $e');
      // Don't show error - this is background feature
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // ✅ Ensure background is transparent
      body: SafeArea( // ✅ Add SafeArea to avoid overlapping with system UI
        child: SingleChildScrollView( // ✅ Wrap with SingleChildScrollView
          child: Container(
            width: double.infinity,
            height: MediaQuery.of(context).size.height, // ✅ Adjust height dynamically
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              image: DecorationImage(
                image: AssetImage("assets/create_account_bg.png"),
                fit: BoxFit.cover,
              ),
            ),
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 50),
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
                Text(
                  "Create an Account",
                  style: TextStyle(fontSize: 22, color: Colors.orangeAccent),
                ),
                SizedBox(height: 20),

                _buildTextField("Username", usernameController), // ✅ Username field
                _buildTextField("Email Address", emailController),
                _buildTextField(
                  "Phone Number",
                  phoneController,
                ), // ✅ Phone number field
                _buildTextField("Password", passwordController, isPassword: true),

                SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _isLoading ? null : _registerUser, // Disable button when loading
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Create an account",
                              style: TextStyle(fontSize: 18, color: Colors.white),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward, color: Colors.white),
                          ],
                        ),
                ),
                
                SizedBox(height: 20),
                
                // Divider with "OR"
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.white70, thickness: 1)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.white70, thickness: 1)),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // Google Sign-up Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  onPressed: _isLoading ? null : _signUpWithGoogle,
                  icon: Image.asset(
                    'assets/google.png',
                    height: 24,
                    width: 24,
                  ),
                  label: Text(
                    'Sign up with Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                
                SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => LoginPage()),
                      );
                    },
                    child: Text(
                      "Already have an account? Login",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
