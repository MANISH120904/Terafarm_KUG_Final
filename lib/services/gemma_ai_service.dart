import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'model_download_manager.dart';

class GemmaAIService {
  static final GemmaAIService _instance = GemmaAIService._internal();
  factory GemmaAIService() => _instance;
  GemmaAIService._internal();

  // Simulated Gemma AI for demonstration - replace with actual FlutterGemma when available
  bool _isInitialized = false;
  List<String> _diseaseLabels = [];
  Random _random = Random();

  Future<bool> initializeGemma() async {
    if (_isInitialized) return true;

    try {
      final modelManager = ModelDownloadManager();
      final modelPath = await modelManager.getModelPath('gemma_2b_it.bin');
      
      if (modelPath == null) {
        print('Gemma model not found. Using simulated AI for demonstration.');
        // For demo purposes, we'll simulate the AI
      }

      // Load disease labels
      await _loadDiseaseLabels();
      
      _isInitialized = true;
      return true;
    } catch (e) {
      print('Error initializing Gemma: $e');
      return false;
    }
  }

  Future<void> _loadDiseaseLabels() async {
    try {
      final modelManager = ModelDownloadManager();
      final labelsPath = await modelManager.getModelPath('plant_disease_labels.txt');
      
      if (labelsPath != null) {
        final file = File(labelsPath);
        final content = await file.readAsString();
        _diseaseLabels = content.split('\n').where((line) => line.trim().isNotEmpty).toList();
      } else {
        // Fallback to embedded labels
        try {
          final data = await rootBundle.loadString('assets/plant_disease_labels.txt');
          _diseaseLabels = data.split('\n').where((line) => line.trim().isNotEmpty).toList();
        } catch (e) {
          // Use default labels as fallback
          _diseaseLabels = [
            'Apple___Apple_scab',
            'Apple___Black_rot',
            'Apple___Cedar_apple_rust',
            'Apple___healthy',
            'Blueberry___healthy',
            'Cherry_(including_sour)___Powdery_mildew',
            'Cherry_(including_sour)___healthy',
            'Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot',
            'Corn_(maize)___Common_rust_',
            'Corn_(maize)___Northern_Leaf_Blight',
            'Corn_(maize)___healthy',
            'Grape___Black_rot',
            'Grape___Esca_(Black_Measles)',
            'Grape___Leaf_blight_(Isariopsis_Leaf_Spot)',
            'Grape___healthy',
            'Orange___Haunglongbing_(Citrus_greening)',
            'Peach___Bacterial_spot',
            'Peach___healthy',
            'Pepper,_bell___Bacterial_spot',
            'Pepper,_bell___healthy',
            'Potato___Early_blight',
            'Potato___Late_blight',
            'Potato___healthy',
            'Raspberry___healthy',
            'Soybean___healthy',
            'Squash___Powdery_mildew',
            'Strawberry___Leaf_scorch',
            'Strawberry___healthy',
            'Tomato___Bacterial_spot',
            'Tomato___Early_blight',
            'Tomato___Late_blight',
            'Tomato___Leaf_Mold',
            'Tomato___Septoria_leaf_spot',
            'Tomato___Spider_mites Two-spotted_spider_mite',
            'Tomato___Target_Spot',
            'Tomato___Tomato_Yellow_Leaf_Curl_Virus',
            'Tomato___Tomato_mosaic_virus',
            'Tomato___healthy'
          ];
        }
      }
    } catch (e) {
      print('Error loading disease labels: $e');
    }
  }

  Future<Map<String, dynamic>> analyzePlantDisease({
    required Uint8List imageBytes,
    String plantType = 'unknown',
    String symptoms = 'leaf discoloration and spots',
    String growthStage = 'mature',
    String conditions = 'normal humidity and temperature',
  }) async {
    if (!_isInitialized) {
      throw Exception('Gemma AI not initialized. Call initializeGemma() first.');
    }

    try {
      // Process image for context (basic analysis)
      final imageAnalysis = await _analyzeImageContext(imageBytes);
      
      // Simulate AI analysis based on image and context
      final result = await _simulateAIAnalysis(imageAnalysis, plantType, symptoms);
      
      return result;
    } catch (e) {
      print('Error in plant disease analysis: $e');
      return {
        'disease': 'Analysis Error',
        'confidence': 0,
        'symptoms': 'Unable to analyze image',
        'treatment': 'Please try again or consult an expert',
        'prevention': 'Maintain good plant hygiene',
        'error': e.toString(),
      };
    }
  }

  Future<Map<String, dynamic>> _analyzeImageContext(Uint8List imageBytes) async {
    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        return {
          'dominantColors': 'Unable to detect',
          'quality': 'Poor',
          'indicators': 'Image processing failed'
        };
      }

      // Basic image analysis
      final width = image.width;
      final height = image.height;
      final quality = (width > 200 && height > 200) ? 'Good' : 'Fair';
      
      // Simple color analysis
      final pixels = image.getBytes();
      int greenCount = 0;
      int brownCount = 0;
      int yellowCount = 0;
      
      for (int i = 0; i < pixels.length; i += 4) {
        final r = pixels[i];
        final g = pixels[i + 1];
        final b = pixels[i + 2];
        
        if (g > r && g > b) greenCount++;
        if (r > 100 && g > 60 && b < 60) brownCount++;
        if (r > 200 && g > 200 && b < 100) yellowCount++;
      }
      
      final totalPixels = pixels.length ~/ 4;
      final dominantColors = <String>[];
      
      if (greenCount > totalPixels * 0.3) dominantColors.add('green');
      if (brownCount > totalPixels * 0.2) dominantColors.add('brown');
      if (yellowCount > totalPixels * 0.15) dominantColors.add('yellow');
      
      final indicators = <String>[];
      if (brownCount > totalPixels * 0.25) indicators.add('possible disease spots');
      if (yellowCount > totalPixels * 0.2) indicators.add('yellowing leaves');
      if (dominantColors.isEmpty) indicators.add('unclear plant material');
      
      return {
        'dominantColors': dominantColors.isNotEmpty ? dominantColors.join(', ') : 'mixed',
        'quality': quality,
        'indicators': indicators.isNotEmpty ? indicators.join(', ') : 'healthy appearance'
      };
    } catch (e) {
      return {
        'dominantColors': 'Analysis failed',
        'quality': 'Unknown',
        'indicators': 'Error in image processing'
      };
    }
  }

  Future<Map<String, dynamic>> _simulateAIAnalysis(
    Map<String, dynamic> imageAnalysis,
    String plantType,
    String symptoms,
  ) async {
    // Simulate AI processing delay
    await Future.delayed(Duration(seconds: 2));
    
    // Select a random disease from the available labels
    final diseaseIndex = _random.nextInt(_diseaseLabels.length);
    final selectedDisease = _diseaseLabels[diseaseIndex];
    
    // Extract plant and disease info
    final parts = selectedDisease.split('___');
    final plant = parts.length > 0 ? parts[0].replaceAll('_', ' ') : 'Unknown Plant';
    final disease = parts.length > 1 ? parts[1].replaceAll('_', ' ') : 'Unknown Disease';
    
    // Determine confidence based on image analysis
    int confidence = 70; // Base confidence
    
    // Adjust confidence based on image indicators
    final indicators = imageAnalysis['indicators'] as String;
    if (indicators.contains('disease spots')) confidence += 15;
    if (indicators.contains('yellowing')) confidence += 10;
    if (indicators.contains('healthy')) confidence = _random.nextInt(30) + 85; // High confidence for healthy
    if (imageAnalysis['quality'] == 'Good') confidence += 5;
    
    confidence = confidence.clamp(45, 95);
    
    // Generate treatment based on disease type
    String treatment = _generateTreatment(disease);
    String prevention = _generatePrevention(disease);
    String symptomsDesc = _generateSymptoms(disease, indicators);
    
    return {
      'disease': disease.isEmpty ? 'Unidentified Disease' : disease,
      'confidence': confidence,
      'symptoms': symptomsDesc,
      'treatment': treatment,
      'prevention': prevention,
      'plantType': plant,
      'imageQuality': imageAnalysis['quality'],
      'dominantColors': imageAnalysis['dominantColors'],
    };
  }

  String _generateTreatment(String disease) {
    final treatmentMap = {
      'healthy': 'Plant appears healthy. Continue current care practices.',
      'Apple scab': 'Apply fungicide containing myclobutanil or propiconazole. Remove infected leaves and improve air circulation.',
      'Black rot': 'Remove infected plant parts immediately. Apply copper-based fungicide and ensure good drainage.',
      'Cedar apple rust': 'Apply preventive fungicide sprays in early spring. Remove nearby juniper plants if possible.',
      'Powdery mildew': 'Apply sulfur-based fungicide or neem oil. Improve air circulation and avoid overhead watering.',
      'Cercospora leaf spot': 'Use crop rotation and apply fungicide containing azoxystrobin or propiconazole.',
      'Common rust': 'Apply fungicide containing mancozeb or chlorothalonil. Plant resistant varieties.',
      'Northern Leaf Blight': 'Remove infected debris and apply fungicide. Use resistant corn varieties.',
      'Esca': 'Prune infected parts and apply wound sealant. No curative treatment available.',
      'Leaf blight': 'Apply copper-based fungicide and remove infected leaves. Improve plant spacing.',
      'Haunglongbing': 'No cure available. Remove infected trees and control psyllid vectors.',
      'Bacterial spot': 'Apply copper-based bactericide. Remove infected plant parts and improve air circulation.',
      'Early blight': 'Apply fungicide containing chlorothalonil or mancozeb. Practice crop rotation.',
      'Late blight': 'Apply fungicide containing metalaxyl or copper. Remove infected plants immediately.',
      'Leaf Mold': 'Improve ventilation and reduce humidity. Apply fungicide if severe.',
      'Septoria leaf spot': 'Apply fungicide and remove infected leaves. Use mulch to prevent soil splash.',
      'Spider mites': 'Increase humidity and apply miticide. Use beneficial insects like predatory mites.',
      'Target Spot': 'Apply fungicide containing azoxystrobin. Remove plant debris and improve air circulation.',
      'Tomato Yellow Leaf Curl Virus': 'Remove infected plants and control whitefly vectors. Use resistant varieties.',
      'Tomato mosaic virus': 'Remove infected plants and disinfect tools. Use virus-free seeds.',
      'Leaf scorch': 'Ensure adequate watering and mulch around plants. Provide shade during hot weather.',
    };
    
    for (final key in treatmentMap.keys) {
      if (disease.toLowerCase().contains(key.toLowerCase())) {
        return treatmentMap[key]!;
      }
    }
    
    return 'Remove affected plant parts, improve growing conditions, and consult local agricultural extension for specific treatment recommendations.';
  }

  String _generatePrevention(String disease) {
    final preventionMap = {
      'healthy': 'Maintain proper watering, fertilization, and pest management practices.',
      'fungal': 'Ensure good air circulation, avoid overhead watering, practice crop rotation, and use disease-resistant varieties.',
      'bacterial': 'Use clean tools, avoid working with wet plants, maintain proper plant spacing, and use pathogen-free seeds.',
      'viral': 'Control insect vectors, use virus-free planting material, and remove infected plants promptly.',
      'pest': 'Monitor regularly, encourage beneficial insects, maintain plant health, and use appropriate pest control measures.',
    };
    
    if (disease.toLowerCase().contains('virus')) return preventionMap['viral']!;
    if (disease.toLowerCase().contains('bacterial') || disease.toLowerCase().contains('spot')) return preventionMap['bacterial']!;
    if (disease.toLowerCase().contains('mite') || disease.toLowerCase().contains('pest')) return preventionMap['pest']!;
    if (disease.toLowerCase().contains('healthy')) return preventionMap['healthy']!;
    
    return preventionMap['fungal']!;
  }

  String _generateSymptoms(String disease, String indicators) {
    final symptomMap = {
      'scab': 'Dark, scaly lesions on leaves and fruits',
      'rot': 'Brown to black rotting areas, often with concentric rings',
      'rust': 'Orange to reddish-brown pustules on leaf surfaces',
      'mildew': 'White powdery coating on leaves and stems',
      'blight': 'Brown to black spots with yellow halos, leaf wilting',
      'spot': 'Circular spots with distinct borders, may have yellow halos',
      'virus': 'Yellowing, mottling, stunted growth, leaf curling',
      'mites': 'Stippled leaves, fine webbing, yellowing',
      'healthy': 'No visible disease symptoms, normal growth and coloration',
    };
    
    for (final key in symptomMap.keys) {
      if (disease.toLowerCase().contains(key)) {
        return '${symptomMap[key]}. ${indicators.isNotEmpty ? "Observed: $indicators" : ""}';
      }
    }
    
    return 'Visible symptoms include discoloration, spots, or abnormal growth patterns. $indicators';
  }

  Future<String> getCropRecommendations({
    required String soilType,
    required String climate,
    required String season,
    String? location,
  }) async {
    if (!_isInitialized) {
      throw Exception('Gemma AI not initialized. Call initializeGemma() first.');
    }

    // Simulate AI processing
    await Future.delayed(Duration(seconds: 1));

    return '''
Based on your conditions:
- Soil Type: $soilType
- Climate: $climate  
- Season: $season
- Location: ${location ?? 'Not specified'}

RECOMMENDED CROPS:

1. **Tomatoes** (High suitability)
   - Planting: Start seeds indoors 6-8 weeks before last frost
   - Care: Provide support, regular watering, and balanced fertilizer
   - Harvest: 70-85 days from transplant
   - Market potential: High demand, good profitability

2. **Leafy Greens** (Medium-High suitability)
   - Planting: Direct sow or transplant, succession planting recommended
   - Care: Consistent moisture, partial shade in hot weather
   - Harvest: 30-60 days from planting
   - Market potential: Steady demand, quick turnover

3. **Root Vegetables** (Medium suitability)
   - Planting: Direct sow according to variety requirements
   - Care: Loose, well-draining soil, minimal fertilizer
   - Harvest: 60-120 days from planting
   - Market potential: Good storage crops, stable prices

GENERAL RECOMMENDATIONS:
- Test soil pH and adjust if necessary
- Implement crop rotation to prevent disease buildup
- Consider water availability and irrigation needs
- Monitor local market prices and demand
''';
  }

  void dispose() {
    _isInitialized = false;
  }
}
