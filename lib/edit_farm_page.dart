import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditFarmPage extends StatefulWidget {
  final String farmId;

  const EditFarmPage({super.key, required this.farmId});

  @override
  _EditFarmPageState createState() => _EditFarmPageState();
}

class _EditFarmPageState extends State<EditFarmPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _scaleOption = "Small Scale"; // Default scale selection
  File? _selectedImage;
  String _imageUrl = "";
  bool isLoading = true;
  List<Map<String, TextEditingController>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadFarmData();
  }

  void _loadFarmData() async {
    try {
      DocumentSnapshot farmDoc = await FirebaseFirestore.instance.collection('farms').doc(widget.farmId).get();
      if (farmDoc.exists) {
        setState(() {
          _nameController.text = farmDoc['farmName'];
          _locationController.text = farmDoc['location'];
          _contactController.text = farmDoc['contactNumber'];
          _descriptionController.text = farmDoc['farmDescription'];
          _scaleOption = farmDoc['scale'] ?? "Small Scale";
          _imageUrl = farmDoc['imageUrl'] ?? "";

          // Load products
          List<dynamic> productList = farmDoc['products'] ?? [];
          _products = productList.map((product) {
            Map<String, dynamic> productMap = product as Map<String, dynamic>;
            return {
              'cropName': TextEditingController(text: productMap['cropName'] ?? ""),
              'stock': TextEditingController(text: productMap['stock in kgs'] ?? ""),
              'price': TextEditingController(text: productMap['pricePerKg'] ?? ""),
            };
          }).toList();

          if (_products.isEmpty) _addProductField(); // Ensure at least one product field
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Farm data not found.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error loading farm data: $e")));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _addProductField() {
    setState(() {
      _products.add({
        'cropName': TextEditingController(),
        'stock': TextEditingController(),
        'price': TextEditingController(),
      });
    });
  }

  void _removeProductField(int index) {
    setState(() {
      _products.removeAt(index);
    });
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _updateFarm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    String imageUrl = _imageUrl;

    // Upload new image if selected
    if (_selectedImage != null) {
      try {
        String fileName = DateTime.now().millisecondsSinceEpoch.toString();
        Reference storageRef = FirebaseStorage.instance.ref("farm_images/$fileName.jpg");
        UploadTask uploadTask = storageRef.putFile(_selectedImage!);
        TaskSnapshot snapshot = await uploadTask;
        imageUrl = await snapshot.ref.getDownloadURL();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error uploading image: $e")));
        setState(() => isLoading = false);
        return;
      }
    }

    // Prepare product list
    List<Map<String, dynamic>> productData = _products.map((product) {
      return {
        'cropName': product['cropName']!.text.trim(),
        'stock in kgs': product['stock']!.text.trim(),
        'pricePerKg': product['price']!.text.trim(),
      };
    }).toList();

    // Update Firestore
    await FirebaseFirestore.instance.collection('farms').doc(widget.farmId).update({
      'farmName': _nameController.text.trim(),
      'location': _locationController.text.trim(),
      'contactNumber': _contactController.text.trim(),
      'farmDescription': _descriptionController.text.trim(),
      'scale': _scaleOption,
      'products': productData,
      'imageUrl': imageUrl,
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Farm updated successfully!")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Edit Farm")),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image Selection
                      if (_imageUrl.isNotEmpty) Image.network(_imageUrl, height: 100),
                      if (_selectedImage != null) Image.file(_selectedImage!, height: 100),
                      ElevatedButton(onPressed: _pickImage, child: Text("Change Image")),
                      SizedBox(height: 10),

                      // Farm Name
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(labelText: "Farm Name"),
                        validator: (value) => value!.isEmpty ? "Enter farm name" : null,
                      ),
                      SizedBox(height: 10),

                      // Location
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(labelText: "Location"),
                        validator: (value) => value!.isEmpty ? "Enter location" : null,
                      ),
                      SizedBox(height: 10),

                      // Contact Number
                      TextFormField(
                        controller: _contactController,
                        decoration: InputDecoration(labelText: "Contact Number"),
                        validator: (value) => value!.isEmpty ? "Enter contact number" : null,
                      ),
                      SizedBox(height: 10),

                      // Farm Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: InputDecoration(labelText: "Farm Description"),
                        validator: (value) => value!.isEmpty ? "Enter farm description" : null,
                      ),
                      SizedBox(height: 10),

                      // Scale Selection
                      Text("Scale:"),
                      Row(
                        children: [
                          Radio<String>(
                            value: "Small Scale",
                            groupValue: _scaleOption,
                            onChanged: (value) => setState(() => _scaleOption = value!),
                          ),
                          Text("Small Scale"),
                          Radio<String>(
                            value: "Large Scale",
                            groupValue: _scaleOption,
                            onChanged: (value) => setState(() => _scaleOption = value!),
                          ),
                          Text("Large Scale"),
                        ],
                      ),
                      SizedBox(height: 10),

                      // Products
                      Text("Products:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 10),
                      Column(
                        children: _products.asMap().entries.map((entry) {
                          int index = entry.key;
                          var product = entry.value;
                          return Card(
                            margin: EdgeInsets.symmetric(vertical: 8.0),
                            elevation: 2,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Product ${index + 1}:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  SizedBox(height: 8),
                                  TextFormField(
                                    controller: product['cropName'],
                                    decoration: InputDecoration(labelText: "Crop Name"),
                                    validator: (value) => value!.isEmpty ? "Enter crop name" : null,
                                  ),
                                  SizedBox(height: 8),
                                  TextFormField(
                                    controller: product['stock'],
                                    decoration: InputDecoration(labelText: "Stock in Kgs"),
                                    validator: (value) => value!.isEmpty ? "Enter stock in kgs" : null,
                                  ),
                                  SizedBox(height: 8),
                                  TextFormField(
                                    controller: product['price'],
                                    decoration: InputDecoration(labelText: "Price Per Kg"),
                                    validator: (value) => value!.isEmpty ? "Enter price per kg" : null,
                                  ),
                                  if (_products.length > 1)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: () => _removeProductField(index),
                                        child: Text("Remove Product", style: TextStyle(color: Colors.red)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      ElevatedButton(onPressed: _addProductField, child: Text("Add Product")),
                      SizedBox(height: 20),

                      // Update Button
                      Center(
                        child: ElevatedButton(
                          onPressed: _updateFarm,
                          child: Text("Update Farm"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
