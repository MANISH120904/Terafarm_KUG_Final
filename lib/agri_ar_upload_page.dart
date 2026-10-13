import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'l10n/app_localizations.dart';

/// AgriAR Upload Page - Upload 3D models and assets to Firebase for AR viewing
/// Supports: .glb, .gltf, .fbx, .obj, and associated textures
class AgriARUploadPage extends StatefulWidget {
  const AgriARUploadPage({Key? key}) : super(key: key);

  @override
  State<AgriARUploadPage> createState() => _AgriARUploadPageState();
}

class _AgriARUploadPageState extends State<AgriARUploadPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _categoryController = TextEditingController();
  
  File? _selectedModelFile;
  File? _thumbnailFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _selectedCategory = 'crops';
  
  final List<String> _categories = [
    'crops',
    'equipment',
    'animals',
    'plants',
    'tools',
    'infrastructure',
    'other'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickModelFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['glb', 'gltf', 'fbx', 'obj', 'zip'],
      );

      if (result != null) {
        setState(() {
          _selectedModelFile = File(result.files.single.path!);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selected: ${result.files.single.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickThumbnail() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (image != null) {
        setState(() {
          _thumbnailFile = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error picking thumbnail: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadModel() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedModelFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a 3D model file'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final modelFileName = '${timestamp}_${_selectedModelFile!.path.split('/').last}';
      final modelPath = 'ar_models/${user.uid}/$modelFileName';

      // Upload 3D model to Firebase Storage
      final modelRef = FirebaseStorage.instance.ref().child(modelPath);
      final modelUploadTask = modelRef.putFile(_selectedModelFile!);

      modelUploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      });

      await modelUploadTask;
      final modelUrl = await modelRef.getDownloadURL();

      // Upload thumbnail if available
      String? thumbnailUrl;
      if (_thumbnailFile != null) {
        final thumbnailFileName = '${timestamp}_thumbnail.jpg';
        final thumbnailPath = 'ar_models/${user.uid}/thumbnails/$thumbnailFileName';
        final thumbnailRef = FirebaseStorage.instance.ref().child(thumbnailPath);
        await thumbnailRef.putFile(_thumbnailFile!);
        thumbnailUrl = await thumbnailRef.getDownloadURL();
      }

      // Save metadata to Firestore
      final modelData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _selectedCategory,
        'modelUrl': modelUrl,
        'thumbnailUrl': thumbnailUrl,
        'uploadedBy': user.uid,
        'uploadedByEmail': user.email,
        'uploadedAt': FieldValue.serverTimestamp(),
        'fileSize': _selectedModelFile!.lengthSync(),
        'fileName': modelFileName,
        'isActive': true,
        'downloadCount': 0,
        'platform': Platform.isAndroid ? 'android' : 'ios',
      };

      await FirebaseFirestore.instance
          .collection('ar_models')
          .add(modelData);

      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ 3D Model uploaded successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Clear form
      _nameController.clear();
      _descriptionController.clear();
      setState(() {
        _selectedModelFile = null;
        _thumbnailFile = null;
        _uploadProgress = 0.0;
      });

      // Navigate back or refresh
      Navigator.of(context).pop();
      
    } catch (e) {
      setState(() {
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Upload failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload AR Model'),
        backgroundColor: const Color(0xFF4CAF50),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF4CAF50).withOpacity(0.1),
              Colors.white,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Card
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        Icon(
                          Icons.view_in_ar,
                          size: 64,
                          color: const Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload 3D Agricultural Models',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2E7D32),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supported formats: .glb, .gltf, .fbx, .obj, .zip',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Model Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Model Name *',
                    hintText: 'e.g., Rice Plant, Tractor, Cow',
                    prefixIcon: const Icon(Icons.label),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category *',
                    prefixIcon: const Icon(Icons.category),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _categories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(category.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Describe the 3D model...',
                    prefixIcon: const Icon(Icons.description),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),

                // Model File Picker
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: Icon(
                      Icons.folder_open,
                      color: const Color(0xFF4CAF50),
                    ),
                    title: Text(_selectedModelFile == null
                        ? 'Select 3D Model File *'
                        : _selectedModelFile!.path.split('/').last),
                    subtitle: _selectedModelFile != null
                        ? Text(
                            '${(_selectedModelFile!.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB')
                        : null,
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _isUploading ? null : _pickModelFile,
                  ),
                ),
                const SizedBox(height: 12),

                // Thumbnail Picker
                Card(
                  elevation: 2,
                  child: ListTile(
                    leading: _thumbnailFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _thumbnailFile!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(
                            Icons.image,
                            color: Colors.grey,
                          ),
                    title: Text(_thumbnailFile == null
                        ? 'Add Thumbnail (Optional)'
                        : 'Thumbnail Selected'),
                    subtitle: _thumbnailFile != null
                        ? Text('Tap to change')
                        : Text('Recommended: 512x512 px'),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _isUploading ? null : _pickThumbnail,
                  ),
                ),
                const SizedBox(height: 24),

                // Upload Progress
                if (_isUploading) ...[
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF4CAF50),
                    ),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      '${(_uploadProgress * 100).toStringAsFixed(1)}% Uploaded',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF4CAF50),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Upload Button
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadModel,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(
                    _isUploading ? 'Uploading...' : 'Upload to Cloud',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                ),

                const SizedBox(height: 16),

                // Info Card
                Card(
                  color: Colors.blue[50],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Your 3D models will be available in the Unity AR app for visualization.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[900],
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
        ),
      ),
    );
  }
}
