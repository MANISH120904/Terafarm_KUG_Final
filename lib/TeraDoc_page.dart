// PlantCare_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';
import 'menu_page.dart';
import 'l10n/app_localizations.dart';
import 'l10n/app_locales.dart';
import 'main.dart' show LocaleProvider;
import 'config/api_keys.dart';

void main() {
  runApp(const TeradocApp());
}

class TeradocApp extends StatelessWidget {
  const TeradocApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Must NOT nest MaterialApp — Android back on an empty nested navigator
    // calls SystemNavigator.pop() and kills the whole activity.
    return const PlantHealthScreen();
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
  String _secondaryAnalysis = '';
  bool _loading = false;
  bool _showSecondaryAnalysis = false;
  late GenerativeModel _model;
  
  late List<Map<String, dynamic>> _languages;

  // UI Colors
  final _kPrimaryGreen = const Color(0xFF2F7A3E);
  final _kLightGreen = const Color(0xFFEAF5EA);

  @override
  void initState() {
    super.initState();
    _languages = List<Map<String, dynamic>>.from(AppLocales.dropdownItems);
    const apiKey = ApiKeys.gemini;
    
    // Optimized configuration for plant disease detection
    final generationConfig = GenerationConfig(
      temperature: 0.1,        // Lower temperature for more consistent, factual responses
      topP: 0.8,              // Focused on high-probability tokens
      topK: 10,               // Limited vocabulary for more precise responses
      maxOutputTokens: 3048,  // Increased for detailed analysis
      stopSequences: ['END_ANALYSIS'], // Stop sequence for controlled output
    );
    
    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: apiKey,
      generationConfig: generationConfig,
      systemInstruction: Content.text(
        """You are PlantDoc AI, a specialized plant pathology expert with deep knowledge of:
        - Agricultural diseases and pests worldwide
        - Organic and sustainable treatment methods
        - Regional farming practices and locally available remedies
        - Plant physiology and environmental stress factors
        
        Always provide accurate, actionable advice while clearly indicating your confidence level.
        Prioritize farmer-friendly, cost-effective solutions using local resources."""
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 85, // Optimize quality vs file size
      maxWidth: 1024,   // Consistent sizing for better analysis
      maxHeight: 1024,
    );
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _analyzeImage() async {
    final localeProv = Provider.of<LocaleProvider>(context, listen: false);
    if (_selectedImage == null) return;

    setState(() {
      _loading = true;
      _analysisResult = '';
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();
      
      // Get current language for AI prompt generation
      String currentLanguage = localeProv.locale.languageCode;
      String languageName = _getLanguageNameForPrompt(currentLanguage);
      
      // Enhanced multi-stage analysis prompt for higher accuracy with multilingual support
      final enhancedPrompt = """
You are an expert plant pathologist and agricultural specialist. Analyze this plant image with scientific precision.

IMPORTANT: Respond in $languageName language. All text, explanations, and recommendations should be in $languageName.

ANALYSIS FRAMEWORK:
1. PLANT IDENTIFICATION:
   - Identify the plant species/type (crop, tree, flower, etc.)
   - Note growth stage (seedling, mature, flowering, fruiting)

2. HEALTH ASSESSMENT:
   - Overall health status (healthy, stressed, diseased, pest damage)
   - Confidence level (High/Medium/Low) based on image clarity

3. SYMPTOM ANALYSIS (if any issues detected):
   - Leaf symptoms: spots, discoloration, wilting, curling, holes, etc.
   - Stem/branch symptoms: cankers, lesions, rot, etc.
   - Root symptoms (if visible): rot, discoloration
   - Pattern: localized, systemic, progressive

4. DISEASE/PEST IDENTIFICATION:
   - Primary diagnosis with confidence percentage
   - Alternative possibilities
   - Distinguish between: fungal, bacterial, viral, nutrient deficiency, pest damage, environmental stress

5. TREATMENT RECOMMENDATIONS:
   - Immediate actions (within 24-48 hours)
   - Short-term treatment (1-2 weeks)
   - Long-term prevention
   - Organic/natural remedies prioritized
   - Local/easily available materials

6. PREVENTION STRATEGIES:
   - Cultural practices
   - Environmental management
   - Monitoring guidelines

FORMAT YOUR RESPONSE IN $languageName AS:
🌱 **PLANT TYPE:** [Species/Type in $languageName]
📊 **CONFIDENCE:** [High/Medium/Low] - [%]
🏥 **HEALTH STATUS:** [Status in $languageName]

🔍 **SYMPTOMS OBSERVED:**
[Detailed symptoms in $languageName]

🦠 **LIKELY DIAGNOSIS:**
Primary: [Disease/Issue in $languageName] ([confidence %])
Secondary: [Alternative if unsure in $languageName]

💊 **IMMEDIATE TREATMENT:**
[Step-by-step actions in $languageName]

🛡️ **PREVENTION:**
[Prevention measures in $languageName]

⚠️ **SEVERITY:** [Low/Medium/High/Critical in $languageName]

Use clear, farmer-friendly language in $languageName. If the image is unclear or you're uncertain, clearly state this in $languageName and ask for a clearer image or additional information.

REMEMBER: ALL OUTPUT MUST BE IN $languageName LANGUAGE.
""";

      final content = Content.multi([
        TextPart(enhancedPrompt),
        DataPart('image/jpeg', bytes),
      ]);
      
      final response = await _model.generateContent([content]);
      
      // Enhanced response processing
      String analysisText = response.text ?? '';
      
      // If response is empty, try candidates
      if (analysisText.isEmpty && response.candidates.isNotEmpty) {
        analysisText = response.candidates.first.content.parts
            .where((part) => part is TextPart)
            .map((part) => (part as TextPart).text)
            .join(' ');
      }
      
      // Clean and format the response
      analysisText = analysisText
          .replaceAll('*', '')
          .replaceAll('**', '')
          .trim();
      
      // If still empty, provide fallback
      if (analysisText.isEmpty) {
        analysisText = """
❌ **ANALYSIS INCOMPLETE**

I was unable to provide a detailed analysis of this image. This could be due to:
- Image quality issues (blurry, too dark, too bright)
- Plant not clearly visible
- Technical processing error

📸 **RECOMMENDATIONS:**
• Take a clearer, well-lit photo
• Focus on affected areas
• Include both close-up and wider shots
• Ensure good lighting (natural daylight preferred)

Please try uploading a new image for better results.
""";
      }

      if (!mounted) return;
      setState(() {
        _analysisResult = analysisText;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analysisResult = """
❌ **ANALYSIS ERROR**

An error occurred during analysis: ${e.toString()}

🔧 **TROUBLESHOOTING:**
• Check your internet connection
• Ensure the image file is valid
• Try a different image
• Contact support if the problem persists

Please try again with a new image.
""";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Secondary analysis for validation and additional insights
  Future<void> _getSecondOpinion() async {
    final localeProv = Provider.of<LocaleProvider>(context, listen: false);
    if (_selectedImage == null) return;

    setState(() {
      _loading = true;
      _secondaryAnalysis = '';
    });

    try {
      final bytes = await _selectedImage!.readAsBytes();
      
      // Get current language for AI prompt generation
      String currentLanguage = localeProv.locale.languageCode;
      String languageName = _getLanguageNameForPrompt(currentLanguage);
      
      final secondOpinionPrompt = """
SECONDARY PLANT HEALTH ANALYSIS - Cross-validation

IMPORTANT: Respond in $languageName language. All text, explanations, and recommendations should be in $languageName.

You are providing a second expert opinion on this plant image. Focus on:

1. VERIFICATION: Confirm or challenge the primary diagnosis
2. ALTERNATIVE DIAGNOSES: What else could this be?
3. DIFFERENTIAL DIAGNOSIS: Key distinguishing features
4. ADDITIONAL OBSERVATIONS: What might have been missed?
5. RISK ASSESSMENT: Urgency and spread potential
6. REGIONAL CONSIDERATIONS: Local climate/disease patterns

FORMAT IN $languageName:
🔄 **SECOND OPINION**
Primary diagnosis: [Agree/Disagree in $languageName] - [Reasoning in $languageName]
Alternative possibilities: [List in $languageName]
Key distinguishing features: [Details in $languageName]
Urgency level: [Low/Medium/High/Critical in $languageName]
Additional recommendations: [Specific advice in $languageName]

Be thorough but concise in $languageName. If you disagree with typical diagnoses, explain why in $languageName.

REMEMBER: ALL OUTPUT MUST BE IN $languageName LANGUAGE.
""";

      final content = Content.multi([
        TextPart(secondOpinionPrompt),
        DataPart('image/jpeg', bytes),
      ]);
      
      final response = await _model.generateContent([content]);
      String secondAnalysis = response.text ?? '';
      
      if (secondAnalysis.isEmpty && response.candidates.isNotEmpty) {
        secondAnalysis = response.candidates.first.content.parts
            .where((part) => part is TextPart)
            .map((part) => (part as TextPart).text)
            .join(' ');
      }
      
      setState(() {
        _secondaryAnalysis = secondAnalysis.replaceAll('*', '').trim();
        _showSecondaryAnalysis = true;
      });
      
    } catch (e) {
      setState(() {
        _secondaryAnalysis = "❌ **SECOND OPINION ERROR**\n\nUnable to generate secondary analysis: ${e.toString()}";
        _showSecondaryAnalysis = true;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  String _getLanguageNameForPrompt(String languageCode) {
    switch (languageCode) {
      case 'hi':
        return 'Hindi (हिन्दी)';
      case 'ta':
        return 'Tamil (தமிழ்)';
      case 'te':
        return 'Telugu (తెలుగు)';
      case 'en':
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final localeProv = Provider.of<LocaleProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      drawer: const MenuPage(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: IntrinsicHeight(
            child: Column(
        children: [
          Container(
                width: double.infinity,
                height: 112,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/top_bar.png'),
                    fit: BoxFit.cover,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 2, left: 24, right: 24),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Column(
                          children: const [
                            SizedBox(height: 15),
                            Center(
                              child: Text(
                                'Welcome to',
                                style: TextStyle(color: Colors.white, fontSize: 17),
                              ),
                            ),
                            SizedBox(height: 0),
                            Text(
                              'Plant Doc',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        left: -8,
                        top: 18,
                        child: Builder(
                          builder: (ctx) => IconButton(
                            icon: const Icon(Icons.menu, color: Colors.white),
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

          // ——— Language and Upload Section ———
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 16, top: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: Text(
                    'Upload Photo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF246B40),
                      fontFamily: 'Poppins',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 140),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<Map<String, dynamic>>(
                      isExpanded: true,
                      isDense: true,
                      value: _languages.firstWhere(
                        (lang) =>
                            lang['locale'].languageCode ==
                            localeProv.locale.languageCode,
                        orElse: () => _languages[0],
                      ),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Color(0xFF246B40),
                      ),
                      items: _languages.map((lang) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: lang,
                          child: Text(
                            lang['name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (Map<String, dynamic>? newLang) {
                        if (newLang != null) {
                          localeProv.setLocale(newLang['locale']);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ——— IMAGE PREVIEW ———
          Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _kLightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_selectedImage!, fit: BoxFit.cover),
                  )
                : const Center(
                    child: Icon(Icons.image, size: 64, color: Colors.grey),
                  ),
          ),

          // ——— CAMERA & GALLERY BUTTONS ———
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _kPrimaryGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _pickImage(ImageSource.camera),
                    child: Text(loc.camera, style: TextStyle(color: _kPrimaryGreen)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _kPrimaryGreen),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _pickImage(ImageSource.gallery),
                    child: Text(loc.gallery, style: TextStyle(color: _kPrimaryGreen)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ——— ACTION BUTTONS ———
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: _loading ? null : _analyzeImage,
                    child: _loading 
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Analyzing...', style: TextStyle(color: Colors.white)),
                            ],
                          )
                        : const Text(
                            'Analyze Plant Health',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                
                // Second Opinion Button (only show if we have an initial analysis)
                if (_analysisResult.isNotEmpty && !_loading) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _kPrimaryGreen),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      onPressed: _getSecondOpinion,
                      child: Text(
                        '🔄 Get Second Opinion',
                        style: TextStyle(fontSize: 16, color: _kPrimaryGreen),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                        _analysisResult = '';
                        _secondaryAnalysis = '';
                        _showSecondaryAnalysis = false;
                      });
                    },
                    child: const Text(
                      'Try Another Plant',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),
          
          // ——— Analysis Results ———
          if (_analysisResult.isNotEmpty)
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // Primary Analysis
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _kLightGreen,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kPrimaryGreen.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.local_hospital, color: _kPrimaryGreen, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Primary Analysis',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _kPrimaryGreen,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _analysisResult,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Secondary Analysis (if available)
                    if (_showSecondaryAnalysis && _secondaryAnalysis.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.verified, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Second Opinion',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _secondaryAnalysis,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    
                    // Tips Section
                    if (_analysisResult.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb, color: Colors.amber.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Pro Tips',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              "💡 For best results:\n"
                              "• Take photos in good natural light\n"
                              "• Include close-ups of affected areas\n"
                              "• Capture both individual leaves and overall plant\n"
                              "• Avoid blurry or shadowy images\n"
                              "• Consider multiple angles if symptoms vary",
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
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


