import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'config/api_keys.dart';

class TeradocApp extends StatelessWidget {
  const TeradocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Teradoc',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: const PlantHealthScreen(),
    );
  }
}

class PlantHealthScreen extends StatefulWidget {
  const PlantHealthScreen({super.key});

  @override
  State<PlantHealthScreen> createState() => _PlantHealthScreenState();
}

class _PlantHealthScreenState extends State<PlantHealthScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  String _analysisResult = '';
  bool _loading = false;
  late GenerativeModel _model;

  @override
  void initState() {
    super.initState();
    const apiKey = ApiKeys.gemini;

    final generationConfig = GenerationConfig(
      temperature: 0.8,
      topP: 0.9,
      topK: 2,
      maxOutputTokens: 2048,
    );

    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: apiKey,
      generationConfig: generationConfig,
      // Safety settings omitted as requested.
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
      _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;
    setState(() {
      _loading = true;
      _analysisResult = '';
    });

    try {
      final imageBytes = await _selectedImage!.readAsBytes();

      const promptText = "You are Teradoc, the plant doctor. "
          "Analyze the health of the plant in the provided image, identify any diseases, "
          "and provide necessary treatment recommendations.";

      final textPart = TextPart(promptText);
      final imagePart = DataPart('image/jpeg', imageBytes);

      final content = Content.multi([textPart, imagePart]);

      final response = await _model.generateContent([content]);

      final generatedText = response.text ??
          response.candidates[0].content as String? ??
          '';
      // Remove any asterisks and trim the text.
      final cleanedText = generatedText.replaceAll('*', '').trim();

      setState(() {
        _analysisResult = cleanedText.isNotEmpty
            ? cleanedText
            : 'No analysis received. Please try again.';
      });
    } catch (e) {
      setState(() {
        _analysisResult = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    // No additional controllers to dispose.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teradoc Plant Health Analyzer'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _selectedImage != null
                ? Image.file(_selectedImage!)
                : Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: const Icon(Icons.image,
                        size: 100, color: Colors.grey),
                  ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _analysisResult.isEmpty
                            ? 'No analysis yet.'
                            : _analysisResult,
                        style: const TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            const Text(
              "Warning: This application is designed exclusively for plant health analysis. "
              "Uploading images that do not depict plants may yield irrelevant or inaccurate results. "
              "Please upload only images of plants.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}