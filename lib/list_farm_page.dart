import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart'; // for currentUser
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // New import for geolocation
import 'address_map_picker.dart'; // Import your location picker widget
import 'voice_assistance.dart';

class ListFarmPage extends StatefulWidget {
  const ListFarmPage({super.key});

  @override
  _ListFarmPageState createState() => _ListFarmPageState();
}

class _ListFarmPageState extends State<ListFarmPage> {
  final _formKey = GlobalKey<FormState>();

  // Farm Details Controllers
  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _upiIdController =
      TextEditingController(); // New UPI id controller
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _farmDescriptionController =
      TextEditingController();

  // Scale Option
  String _scaleOption = "Small Scale"; // default selection

  // Products: List of product entries
  final List<Map<String, TextEditingController>> _products = [];

  File? _selectedImage;
  bool _isUploading = false;

  // Store the chosen coordinates from the picker.
  double? _selectedLat;
  double? _selectedLng;

  @override
  void initState() {
    super.initState();
    // Start with one product entry by default.
    _addProductField();
  }

  // Dispose controllers when not needed.
  @override
  void dispose() {
    _farmNameController.dispose();
    _contactNumberController.dispose();
    _upiIdController.dispose();
    _locationController.dispose();
    _farmDescriptionController.dispose();
    for (var product in _products) {
      product['cropName']?.dispose();
      product['stock']?.dispose();
      product['price']?.dispose();
    }
    super.dispose();
  }

  // Add a new product entry (cropName, stock, price).
  void _addProductField() {
    setState(() {
      _products.add({
        'cropName': TextEditingController(),
        'stock': TextEditingController(),
        'price': TextEditingController(),
      });
    });
  }

  // Remove a product entry.
  void _removeProductField(int index) {
    setState(() {
      _products.removeAt(index);
    });
  }

  // Pick an image from gallery.
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => _selectedImage = File(image.path));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("No image selected.")));
    }
  }

  // Automatically get the current location.
  Future<LatLng> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Location services are disabled.");
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Location permissions are denied");
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        "Location permissions are permanently denied. Please enable them in the settings.",
      );
    }

    final Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return LatLng(position.latitude, position.longitude);
  }

  // Opens the map picker with the device's current location pre-selected.
  Future<void> _openMapPicker() async {
    LatLng initialLocation;
    try {
      // Automatically fetch the current location.
      initialLocation = await _getCurrentLocation();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not fetch current location: $e")),
      );
      // Fall back to default location (San Francisco)
      initialLocation = LatLng(37.7749, -122.4194);
    }

    // Open a modal bottom sheet with your AddressMapPicker widget.
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled:
          true, // allows the bottom sheet to be full screen if needed
      builder: (context) => AddressMapPicker(initialLocation: initialLocation),
    );

    if (result != null) {
      setState(() {
        _locationController.text = result["address"] as String;
        _selectedLat = result["lat"] as double;
        _selectedLng = result["lng"] as double;
      });
    }
  }

  // Upload image & save farm details to Firestore.
  Future<void> _saveFarmDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    String imageUrl = "";
    if (_selectedImage != null) {
      try {
        final fileName = DateTime.now().millisecondsSinceEpoch.toString();
        final storageRef = FirebaseStorage.instance.ref(
          "farm_images/$fileName.jpg",
        );
        imageUrl =
            await (await storageRef.putFile(
              _selectedImage!,
            )).ref.getDownloadURL();
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error uploading image: $e")));
        setState(() => _isUploading = false);
        return;
      }
    }

    final productData =
        _products
            .map(
              (product) => {
                'cropName': product['cropName']!.text.trim(),
                'stock in kgs': product['stock']!.text.trim(),
                'pricePerKg': product['price']!.text.trim(),
              },
            )
            .toList();

    try {
      await FirebaseFirestore.instance.collection('farms').add({
        'farmName': _farmNameController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'upiId': _upiIdController.text.trim(), // Saving the UPI ID
        'location': _locationController.text.trim(),
        'farmDescription': _farmDescriptionController.text.trim(),
        'scale': _scaleOption,
        'products': productData,
        'imageUrl': imageUrl,
        'sellerId': FirebaseAuth.instance.currentUser!.uid,
        'timestamp': FieldValue.serverTimestamp(),
        // Optionally, store the selected coordinates.
        'latitude': _selectedLat,
        'longitude': _selectedLng,
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Farm created successfully!")));
      _formKey.currentState!.reset();
      _products.clear();
      _addProductField();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error saving farm details: $e")));
    }

    setState(() => _isUploading = false);
  }

  // Helper method to build section cards
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF246B40).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF246B40),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF246B40),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  // Helper method to build text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        onTap: onTap,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF246B40),
            size: 20,
          ),
          labelStyle: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 13,
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF246B40),
              width: 2,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.red.shade400,
              width: 1,
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.red.shade400,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      floatingActionButton: const VoiceAssistantWidget(),
      appBar: AppBar(
        title: const Text(
          "List a Farm",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF246B40),
                const Color(0xFF2E8B57),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.grey.shade50,
              Colors.white,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF246B40).withOpacity(0.1),
                          const Color(0xFF2E8B57).withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFF246B40).withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.agriculture,
                          size: 40,
                          color: const Color(0xFF246B40),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Create Your Farm Listing",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF246B40),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Share your farm details and connect with buyers",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Image upload section.
                  _buildSectionCard(
                    title: "Farm Image",
                    icon: Icons.image,
                    children: [
                      const Text(
                        "Please upload a square image:",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF246B40),
                                  const Color(0xFF2E8B57),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF246B40).withOpacity(0.3),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: _pickImage,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.camera_alt, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        "Choose File",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          if (_selectedImage != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green.shade600,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "File Chosen",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      if (_selectedImage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 15),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                height: 120,
                                width: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Farm Details section
                  _buildSectionCard(
                    title: "Farm Details",
                    icon: Icons.info_outline,
                    children: [
                      _buildTextField(
                        controller: _farmNameController,
                        label: "Farm Name",
                        icon: Icons.agriculture,
                        validator: (value) =>
                            value!.isEmpty ? "Please enter a farm name" : null,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: _contactNumberController,
                        label: "Contact Number",
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                            value!.isEmpty ? "Please enter a contact number" : null,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: _upiIdController,
                        label: "Seller UPI ID",
                        hint: "e.g., example@upi",
                        icon: Icons.payment,
                        validator: (value) =>
                            value!.isEmpty ? "Please enter your UPI ID" : null,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: _locationController,
                        label: "Location",
                        icon: Icons.location_on,
                        readOnly: true,
                        onTap: _openMapPicker,
                        validator: (value) =>
                            value!.isEmpty ? "Please select a location" : null,
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(
                        controller: _farmDescriptionController,
                        label: "Farm Description",
                        icon: Icons.description,
                        maxLines: 3,
                        validator: (value) =>
                            value!.isEmpty ? "Please enter a farm description" : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Scale Option section
                  _buildSectionCard(
                    title: "Farm Scale",
                    icon: Icons.straighten,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _scaleOption == "Small Scale"
                                    ? const Color(0xFF246B40).withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _scaleOption == "Small Scale"
                                      ? const Color(0xFF246B40)
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: RadioListTile<String>(
                                value: "Small Scale",
                                groupValue: _scaleOption,
                                onChanged: (value) => setState(() => _scaleOption = value!),
                                title: const Text(
                                  "Small Scale",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                activeColor: const Color(0xFF246B40),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _scaleOption == "Large Scale"
                                    ? const Color(0xFF246B40).withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _scaleOption == "Large Scale"
                                      ? const Color(0xFF246B40)
                                      : Colors.grey.shade300,
                                  width: 2,
                                ),
                              ),
                              child: RadioListTile<String>(
                                value: "Large Scale",
                                groupValue: _scaleOption,
                                onChanged: (value) => setState(() => _scaleOption = value!),
                                title: const Text(
                                  "Large Scale",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                activeColor: const Color(0xFF246B40),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Product Details section
                  _buildSectionCard(
                    title: "Product Details",
                    icon: Icons.inventory,
                    children: [
                      Column(
                        children: _products.asMap().entries.map((entry) {
                          int index = entry.key;
                          Map<String, TextEditingController> product = entry.value;
                          return _buildProductFields(product, index);
                        }).toList(),
                      ),
                      const SizedBox(height: 15),
                      // +Add Product Button
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.teal.shade400,
                                Colors.teal.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _addProductField,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.add, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      "Add Product",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  // Create Farm Button
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF246B40),
                          const Color(0xFF2E8B57),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF246B40).withOpacity(0.4),
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
                        onTap: _isUploading ? null : _saveFarmDetails,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_isUploading)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              const SizedBox(width: 10),
                              Text(
                                _isUploading ? "Creating Farm..." : "Create Farm",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Build one product's text fields.
  Widget _buildProductFields(
    Map<String, TextEditingController> product,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.grey.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF246B40).withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF246B40).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.grass,
                  color: Color(0xFF246B40),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                "Product ${index + 1}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF246B40),
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (_products.length > 1)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => _removeProductField(index),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.delete_outline,
                          color: Colors.red.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Crop Name
          _buildTextField(
            controller: product['cropName']!,
            label: "Crop Name",
            icon: Icons.eco,
            validator: (value) => value!.isEmpty ? "Please enter crop name" : null,
          ),
          const SizedBox(height: 15),
          
          // Stock and Price in a row
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: product['stock']!,
                  label: "Stock (kg)",
                  icon: Icons.inventory_2,
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? "Please enter stock" : null,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _buildTextField(
                  controller: product['price']!,
                  label: "Price per kg",
                  icon: Icons.currency_rupee,
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty ? "Please enter price" : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}