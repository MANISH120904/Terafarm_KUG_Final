import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key}) : super(key: key);

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _localityController = TextEditingController();
  final TextEditingController _farmNameController = TextEditingController();
  File? _selectedImage;
  String? _imageUrl;

  bool _animate = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _animate = true);
    });
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final userData = userDoc.data() ?? {};

      // Fetch farm name if the user has a farm
      final farmQuery =
          await FirebaseFirestore.instance
              .collection('farms')
              .where('sellerId', isEqualTo: user.uid)
              .limit(1)
              .get();
      final farmName =
          farmQuery.docs.isNotEmpty ? farmQuery.docs.first['farmName'] : null;

      setState(() {
        _usernameController.text = userData['username'] ?? '';
        _emailController.text = userData['email'] ?? '';
        _phoneController.text = userData['phone'] ?? '';
        _localityController.text = userData['locality'] ?? '';
        _farmNameController.text = farmName ?? '';
        _imageUrl = userData['profileImage'];
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      String? imageUrl = _imageUrl;

      try {
        if (_selectedImage != null) {
          final storageRef = FirebaseStorage.instance.ref().child(
            'profile_images/${user.uid}_profile_image.jpg',
          );
          final uploadTask = storageRef.putFile(_selectedImage!);
          final snapshot = await uploadTask.whenComplete(() => null);
          imageUrl = await snapshot.ref.getDownloadURL();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
              'username': _usernameController.text.trim(),
              'email': _emailController.text.trim(),
              'phone': _phoneController.text.trim(),
              'locality': _localityController.text.trim(),
              'profileImage': imageUrl,
            });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile updated successfully!")),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error saving profile: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 244, 143, 143),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 244, 143, 143),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _animatedFadeSlide(
                0,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      backgroundImage:
                          _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : (_imageUrl != null
                                      ? NetworkImage(_imageUrl!)
                                      : null)
                                  as ImageProvider?,
                      child:
                          _selectedImage == null && _imageUrl == null
                              ? const Icon(
                                Icons.account_circle,
                                size: 80,
                                color: Colors.grey,
                              )
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.edit, color: Colors.white),
                        onPressed: _pickImage,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _animatedFadeSlide(
                1,
                child: _buildEditableField("Username", _usernameController),
              ),
              _animatedFadeSlide(
                2,
                child: _buildEditableField(
                  "My email Address",
                  _emailController,
                ),
              ),
              _animatedFadeSlide(
                3,
                child: _buildEditableField("Phone number", _phoneController),
              ),
              _animatedFadeSlide(
                4,
                child: _buildEditableField("Locality", _localityController),
              ),
              _animatedFadeSlide(
                5,
                child: _buildEditableField(
                  "My Farm's name",
                  _farmNameController,
                ),
              ),
              const SizedBox(height: 20),
              _animatedFadeSlide(
                6,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Save"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.black, fontSize: 16)),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            suffixIcon: const Icon(Icons.edit, color: Colors.black),
          ),
          validator:
              (value) =>
                  value == null || value.isEmpty
                      ? "This field cannot be empty"
                      : null,
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  Widget _animatedFadeSlide(int index, {required Widget child}) {
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
}
