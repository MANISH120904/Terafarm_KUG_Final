import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../models/scheme_model.dart';
import '../config/api_keys.dart';
import 'enhanced_ai_service.dart';

class SchemeChatbotService {
  static const String _geminiApiKey = ApiKeys.gemini;
  late final GenerativeModel _model;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final EnhancedAIService _enhancedAI = EnhancedAIService(); // New enhanced AI service
  
  List<SchemeModel> _cachedSchemes = [];
  DateTime? _lastCacheUpdate;
  
  SchemeChatbotService() {
    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: _geminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 2048,
      ),
    );
  }

  /// Fetch scheme data from deployed Firebase Functions
  Future<List<Map<String, dynamic>>> _getSchemeDataFromFirebase() async {
    try {
      final response = await http.get(
        Uri.parse('https://us-central1-terafarmsih.cloudfunctions.net/getSchemeData'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Fetched ${data['totalSchemes']} schemes from ${data['dataSource']}');
          return List<Map<String, dynamic>>.from(data['schemes']);
        } else {
          print('❌ Error in response: ${data['error']}');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception fetching scheme data: $e');
    }

    // Return fallback schemes if Firebase Functions fail
    return [
      {
        'name': 'PM-KISAN Samman Nidhi',
        'amount': '₹6,000 per year',
        'category': 'Direct Benefit Transfer',
        'description': 'Direct income support to all landholding farmer families',
        'eligibility': 'All landholding farmer families',
        'applicationProcess': 'Apply at nearest Common Service Center'
      },
      {
        'name': 'Pradhan Mantri Fasal Bima Yojana',
        'amount': 'Up to ₹2,00,000',
        'category': 'Crop Insurance', 
        'description': 'Comprehensive crop insurance coverage',
        'eligibility': 'All farmers growing notified crops',
        'applicationProcess': 'Apply through banks or insurance companies'
      },
    ];
  }

  /// Extract text content from PDF documents stored in Firebase Storage
  Future<List<Map<String, String>>> _extractDocumentContent() async {
    List<Map<String, String>> documents = [];
    
    try {
      // List all files in the Schemes_for_farmers folder
      final ListResult result = await _storage.ref('Schemes_for_farmers').listAll();
      
      for (Reference ref in result.items) {
        if (ref.name.toLowerCase().endsWith('.pdf')) {
          try {
            // Get download URL
            final String downloadUrl = await ref.getDownloadURL();
            
            // For now, we'll store metadata about the document
            // In a real implementation, you'd use a PDF parsing service
            documents.add({
              'name': ref.name,
              'url': downloadUrl,
              'type': 'pdf',
              'content': 'Indian Farmer Scheme Document: ${ref.name}. This document contains comprehensive information about government schemes for farmers including eligibility criteria, benefits, application process, and contact details.',
            });
          } catch (e) {
            print('Error processing document ${ref.name}: $e');
          }
        }
      }
    } catch (e) {
      print('Error listing documents: $e');
    }
    
    return documents;
  }

  /// Create embeddings and store scheme information using Firebase Functions
  Future<void> _indexSchemeDocuments() async {
    if (_cachedSchemes.isNotEmpty && 
        _lastCacheUpdate != null && 
        DateTime.now().difference(_lastCacheUpdate!).inHours < 24) {
      return; // Use cached data if it's less than 24 hours old
    }

    try {
      // Get real scheme data from Firebase Functions
      final schemeDataList = await _getSchemeDataFromFirebase();
      _cachedSchemes.clear();

      // Convert Firebase Functions data to SchemeModel objects
      for (int i = 0; i < schemeDataList.length; i++) {
        final schemeData = schemeDataList[i];
        
        _cachedSchemes.add(SchemeModel(
          id: 'scheme_${i + 1}',
          name: schemeData['name'] ?? 'Unknown Scheme',
          description: schemeData['description'] ?? 'Government scheme for farmers',
          eligibility: schemeData['eligibility'] ?? 'As per government guidelines',
          benefits: schemeData['amount'] ?? 'Contact local office for details',
          applicationProcess: schemeData['applicationProcess'] ?? 'Apply through official channels',
          contactInfo: 'Contact local agriculture office or visit nearest CSC',
          documentUrl: 'https://us-central1-terafarmsih.cloudfunctions.net/getSchemeData',
          keywords: _generateKeywords(schemeData['name'] ?? 'scheme'),
          category: schemeData['category'] ?? 'General',
          lastUpdated: DateTime.now(),
        ));
      }
      
      print('✅ Indexed ${_cachedSchemes.length} schemes from Firebase Functions');
      _lastCacheUpdate = DateTime.now();
    } catch (e) {
      print('❌ Error indexing documents from Firebase Functions: $e');
      
      // Fallback to local scheme creation if Firebase Functions fail
      _cachedSchemes = [
        SchemeModel(
          id: 'fallback_1',
          name: 'PM-KISAN Samman Nidhi',
          description: 'Direct income support to all landholding farmer families',
          eligibility: 'All landholding farmer families',
          benefits: '₹6,000 per year',
          applicationProcess: 'Apply at nearest Common Service Center',
          contactInfo: 'Contact local agriculture office',
          documentUrl: '',
          keywords: ['pm-kisan', 'direct', 'benefit', 'transfer'],
          category: 'Direct Benefit Transfer',
          lastUpdated: DateTime.now(),
        ),
      ];
      _lastCacheUpdate = DateTime.now();
    }
  }

  /// Extract scheme details from document using Gemini
  Future<Map<String, String>> _extractSchemeDetailsFromDocument(Map<String, String> doc) async {
    try {
      final prompt = '''
Analyze this Indian farmer scheme document and extract key information:
Document: ${doc['name']}

Based on the document name and typical Indian farmer schemes, provide:
1. Scheme Name (clean, readable format)
2. Description (2-3 sentences about the scheme)
3. Eligibility (who can apply)
4. Benefits (what farmers get)
5. Application Process (how to apply)
6. Contact Info (where to get help)
7. Category (e.g., "Crop Insurance", "Subsidies", "Loans", "Technology", "Land Development")

Format as JSON:
{
  "name": "scheme name",
  "description": "description",
  "eligibility": "eligibility criteria",
  "benefits": "benefits offered",
  "applicationProcess": "how to apply",
  "contactInfo": "contact information",
  "category": "category"
}
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      if (response.text != null) {
        try {
          // Clean the response text to extract JSON
          String jsonText = response.text!;
          if (jsonText.contains('```json')) {
            jsonText = jsonText.split('```json')[1].split('```')[0];
          } else if (jsonText.contains('```')) {
            jsonText = jsonText.split('```')[1];
          }
          
          final Map<String, dynamic> result = json.decode(jsonText.trim());
          return result.map((key, value) => MapEntry(key, value.toString()));
        } catch (e) {
          print('Error parsing JSON response: $e');
        }
      }
    } catch (e) {
      print('Error extracting scheme details: $e');
    }
    
    return {};
  }

  /// Generate keywords for better matching
  List<String> _generateKeywords(String text) {
    final keywords = <String>[];
    final words = text.toLowerCase().split(RegExp(r'[^a-zA-Z0-9\u0900-\u097F]+'));
    
    for (String word in words) {
      if (word.length > 2) {
        keywords.add(word);
      }
    }
    
    // Add common farming keywords
    keywords.addAll([
      'farmer', 'agriculture', 'crop', 'subsidy', 'loan', 'insurance',
      'irrigation', 'seed', 'fertilizer', 'kisan', 'scheme', 'yojana'
    ]);
    
    return keywords.toSet().toList();
  }

  /// Find relevant schemes based on user query
  Future<List<SchemeModel>> _findRelevantSchemes(String query, UserProfile? userProfile) async {
    await _indexSchemeDocuments();
    
    List<SchemeModel> relevantSchemes = [];
    query = query.toLowerCase();
    
    // Score schemes based on relevance
    Map<SchemeModel, double> schemeScores = {};
    
    for (SchemeModel scheme in _cachedSchemes) {
      double score = 0.0;
      
      // Check name match
      if (scheme.name.toLowerCase().contains(query)) score += 3.0;
      
      // Check description match
      if (scheme.description.toLowerCase().contains(query)) score += 2.0;
      
      // Check keyword matches
      for (String keyword in scheme.keywords) {
        if (query.contains(keyword.toLowerCase())) score += 1.0;
      }
      
      // User profile matching
      if (userProfile != null) {
        if (scheme.category.toLowerCase().contains(userProfile.cropType.toLowerCase())) score += 1.5;
        if (scheme.eligibility.toLowerCase().contains(userProfile.farmSize.toLowerCase())) score += 1.0;
      }
      
      if (score > 0) {
        schemeScores[scheme] = score;
      }
    }
    
    // Sort by score and return top 5
    var sortedEntries = schemeScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    relevantSchemes = sortedEntries.take(5).map((e) => e.key).toList();
    
    return relevantSchemes;
  }

  /// Get user profile from Firestore with locale-based language preference
  Future<UserProfile?> _getUserProfile({String? locale}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Determine language from locale if provided, otherwise use stored preference
        String language = 'hindi'; // default
        if (locale != null) {
          language = _getLanguageFromLocale(locale);
        } else if (data['preferredLanguage'] != null) {
          language = data['preferredLanguage'];
        }
        
        return UserProfile(
          farmSize: data['farmSize'] ?? '',
          location: data['location']?.toString() ?? '',
          cropType: data['preferredCrops'] ?? '',
          experience: data['experience'] ?? '',
          income: data['income'] ?? '',
          interests: List<String>.from(data['interests'] ?? []),
          preferredLanguage: language,
        );
      }
    } catch (e) {
      print('Error getting user profile: $e');
    }
    return null;
  }

  /// Convert locale to language code
  String _getLanguageFromLocale(String locale) {
    switch (locale.toLowerCase()) {
      case 'en':
      case 'en_us':
      case 'en_in':
      case 'en_gb':
        return 'english';
      case 'hi':
      case 'hi_in':
        return 'hindi';
      case 'ta':
      case 'ta_in':
        return 'tamil';
      case 'te':
      case 'te_in':
        return 'telugu';
      case 'kn':
      case 'kn_in':
        return 'kannada';
      case 'bn':
      case 'bn_in':
        return 'bengali';
      case 'gu':
      case 'gu_in':
        return 'gujarati';
      case 'mr':
      case 'mr_in':
        return 'marathi';
      case 'pa':
      case 'pa_in':
        return 'punjabi';
      default:
        return 'hindi'; // Default to Hindi
    }
  }

  /// Get localized text based on user's preferred language
  Map<String, String> _getLocalizedText(String language) {
    final Map<String, Map<String, String>> localizations = {
      'hindi': {
        'greeting': '🌾 नमस्ते किसान भाई/बहन! Hello farmer friend!',
        'schemes_for_you': '🌾 यहाँ हैं आपके लिए बेहतरीन योजनाएं! Here are the best schemes for you:',
        'description': '📝 विवरण | Description:',
        'eligibility': '✅ योग्यता | Eligibility:',
        'benefits': '💰 लाभ | Benefits:',
        'application': '📋 आवेदन प्रक्रिया | Application:',
        'contact': '📞 संपर्क | Contact:',
        'document': '📄 दस्तावेज़ | Document:',
        'farmer_profile': '🧑‍🌾 किसान प्रोफाइल | Farmer Profile:',
        'farm_size': '🏞️ खेत का आकार | Farm Size:',
        'location': '📍 स्थान | Location:',
        'crop_type': '🌾 फसल का प्रकार | Crop Type:',
        'experience': '📚 अनुभव | Experience:',
        'question': '👨‍🌾 किसान का सवाल | Farmer\'s Question:',
        'best_schemes': '🌟 **आपके लिए सबसे अच्छी योजनाएं | Best Schemes for You:**',
        'financial_benefits': '💰 **पैसे का फायदा | Financial Benefits:**',
        'you_can_apply': '✅ **आप आवेदन कर सकते हैं अगर | You Can Apply If:**',
        'how_to_apply': '📋 **कैसे करें आवेदन | How to Apply:**',
        'need_help': '📞 **मदद चाहिए? संपर्क करें | Need Help? Contact:**',
        'technical_error': '😔 कुछ तकनीकी समस्या हुई है। Sorry, there was a technical problem. कृपया बाद में कोशिश करें। Please try again later. 🔄',
        'closing_message': '🤝 अधिक सहायता के लिए अपने नजदीकी कृषि कार्यालय से संपर्क करें!\nFor more help, please contact your local agriculture office! 📞\n\n🌱 खुशी से खेती करें, समृद्ध बनें! Happy farming, prosper well! 🌾',
        'could_not_understand': '😔 माफ़ करें, मैं आपका सवाल समझ नहीं पाया। Sorry, I could not understand your question. कृपया फिर से आसान भाषा में पूछें। Please ask again in simple words.'
      },
      'tamil': {
        'greeting': '🌾 வணக்கம் விவசாயி அண்ணா/அக்கா! Hello farmer friend!',
        'schemes_for_you': '🌾 உங்களுக்கான சிறந்த திட்டங்கள் இதோ! Here are the best schemes for you:',
        'description': '📝 விளக்கம் | Description:',
        'eligibility': '✅ தகுதி | Eligibility:',
        'benefits': '💰 நன்மைகள் | Benefits:',
        'application': '📋 விண்ணப்ப செயல்முறை | Application:',
        'contact': '📞 தொடர்பு | Contact:',
        'document': '📄 ஆவணம் | Document:',
        'farmer_profile': '🧑‍🌾 விவசாயி விபரம் | Farmer Profile:',
        'farm_size': '🏞️ நிலத்தின் அளவு | Farm Size:',
        'location': '📍 இடம் | Location:',
        'crop_type': '🌾 பயிர் வகை | Crop Type:',
        'experience': '📚 அனுபவம் | Experience:',
        'question': '👨‍🌾 விவசாயியின் கேள்வி | Farmer\'s Question:',
        'best_schemes': '🌟 **உங்களுக்கான சிறந்த திட்டங்கள் | Best Schemes for You:**',
        'financial_benefits': '💰 **பொருளாதார நன்மைகள் | Financial Benefits:**',
        'you_can_apply': '✅ **நீங்கள் விண்ணப்பிக்கலாம் | You Can Apply If:**',
        'how_to_apply': '📋 **எப்படி விண்ணப்பிப்பது | How to Apply:**',
        'need_help': '📞 **உதவி வேண்டுமா? தொடர்பு கொள்ளுங்கள் | Need Help? Contact:**',
        'technical_error': '😔 ஏதோ தொழில்நுட்ப பிரச்சனை ஏற்பட்டுள்ளது। Sorry, there was a technical problem. தயவுசெய்து பின்னர் முயற்சிக்கவும்। Please try again later. 🔄',
        'closing_message': '🤝 மேலும் உதவிக்கு உங்கள் அருகிலுள்ள வேளாண் அலுவலகத்தைத் தொடர்பு கொள்ளுங்கள்!\nFor more help, please contact your local agriculture office! 📞\n\n🌱 மகிழ்ச்சியாக விவசாயம் செய்யுங்கள், செழித்து வாழுங்கள்! Happy farming, prosper well! 🌾',
        'could_not_understand': '😔 மன்னிக்கவும், உங்கள் கேள்வியை என்னால் புரிந்துகொள்ள முடியவில்லை। Sorry, I could not understand your question. தயவுசெய்து எளிய மொழியில் மீண்டும் கேளுங்கள்। Please ask again in simple words.'
      },
      'telugu': {
        'greeting': '🌾 నమస్కారం రైతు అన్న/అక్క! Hello farmer friend!',
        'schemes_for_you': '🌾 మీ కోసం అత్యుత్తమ పథకాలు ఇవిగో! Here are the best schemes for you:',
        'description': '📝 వివరణ | Description:',
        'eligibility': '✅ అర్హత | Eligibility:',
        'benefits': '💰 ప్రయోజనాలు | Benefits:',
        'application': '📋 దరఖాస్తు ప్రక్రియ | Application:',
        'contact': '📞 సంపర్కం | Contact:',
        'document': '📄 పత్రం | Document:',
        'farmer_profile': '🧑‍🌾 రైతు ప్రొఫైల్ | Farmer Profile:',
        'farm_size': '🏞️ వ్యవసాయ భూమి పరిమాణం | Farm Size:',
        'location': '📍 ప్రాంతం | Location:',
        'crop_type': '🌾 పంట రకం | Crop Type:',
        'experience': '📚 అనుభవం | Experience:',
        'question': '👨‍🌾 రైతు ప్రశ్న | Farmer\'s Question:',
        'best_schemes': '🌟 **మీ కోసం అత్యుత్తమ పథకాలు | Best Schemes for You:**',
        'financial_benefits': '💰 **ఆర్థిక ప్రయోజనాలు | Financial Benefits:**',
        'you_can_apply': '✅ **మీరు దరఖాస్తు చేయవచ్చు | You Can Apply If:**',
        'how_to_apply': '📋 **ఎలా దరఖాస్తు చేయాలి | How to Apply:**',
        'need_help': '📞 **సహాయం కావాలా? సంపర్కించండి | Need Help? Contact:**',
        'technical_error': '😔 ఏదో సాంకేతిక సమస్య ఏర్పడింది। Sorry, there was a technical problem. దయచేసి తర్వాత ప్రయత్నించండి। Please try again later. 🔄',
        'closing_message': '🤝 మరింత సహాయం కోసం మీ సమీప వ్యవసాయ కార్యాలయాన్ని సంపర్కించండి!\nFor more help, please contact your local agriculture office! 📞\n\n🌱 సంతోషంగా వ్యవసాయం చేయండి, అభివృద్ధి చెందండి! Happy farming, prosper well! 🌾',
        'could_not_understand': '😔 క్షమించండి, మీ ప్రశ్నను నేను అర్థం చేసుకోలేకపోయాను। Sorry, I could not understand your question. దయచేసి సరళమైన భాషలో మళ్లీ అడగండి। Please ask again in simple words.'
      },
      'kannada': {
        'greeting': '🌾 ನಮಸ್ಕಾರ ರೈತ ಅಣ್ಣ/ಅಕ್ಕ! Hello farmer friend!',
        'schemes_for_you': '🌾 ನಿಮಗಾಗಿ ಅತ್ಯುತ್ತಮ ಯೋಜನೆಗಳು ಇಲ್ಲಿವೆ! Here are the best schemes for you:',
        'description': '📝 ವಿವರಣೆ | Description:',
        'eligibility': '✅ ಅರ್ಹತೆ | Eligibility:',
        'benefits': '💰 ಪ್ರಯೋಜನಗಳು | Benefits:',
        'application': '📋 ಅರ್ಜಿ ಪ್ರಕ್ರಿಯೆ | Application:',
        'contact': '📞 ಸಂಪರ್ಕ | Contact:',
        'document': '📄 ದಾಖಲೆ | Document:',
        'farmer_profile': '🧑‍🌾 ರೈತ ಪ್ರೊಫೈಲ್ | Farmer Profile:',
        'farm_size': '🏞️ ಜಮೀನಿನ ಗಾತ್ರ | Farm Size:',
        'location': '📍 ಸ್ಥಳ | Location:',
        'crop_type': '🌾 ಬೆಳೆ ಪ್ರಕಾರ | Crop Type:',
        'experience': '📚 ಅನುಭವ | Experience:',
        'question': '👨‍🌾 ರೈತನ ಪ್ರಶ್ನೆ | Farmer\'s Question:',
        'best_schemes': '🌟 **ನಿಮಗಾಗಿ ಅತ್ಯುತ್ತಮ ಯೋಜನೆಗಳು | Best Schemes for You:**',
        'financial_benefits': '💰 **ಆರ್ಥಿಕ ಪ್ರಯೋಜನಗಳು | Financial Benefits:**',
        'you_can_apply': '✅ **ನೀವು ಅರ್ಜಿ ಸಲ್ಲಿಸಬಹುದು | You Can Apply If:**',
        'how_to_apply': '📋 **ಹೇಗೆ ಅರ್ಜಿ ಸಲ್ಲಿಸುವುದು | How to Apply:**',
        'need_help': '📞 **ಸಹಾಯ ಬೇಕೇ? ಸಂಪರ್ಕಿಸಿ | Need Help? Contact:**',
        'technical_error': '😔 ಯಾವುದೋ ತಾಂತ್ರಿಕ ಸಮಸ್ಯೆ ಆಗಿದೆ। Sorry, there was a technical problem. ದಯವಿಟ್ಟು ನಂತರ ಪ್ರಯತ್ನಿಸಿ। Please try again later. 🔄',
        'closing_message': '🤝 ಹೆಚ್ಚಿನ ಸಹಾಯಕ್ಕಾಗಿ ನಿಮ್ಮ ಹತ್ತಿರದ ಕೃಷಿ ಕಛೇರಿಯನ್ನು ಸಂಪರ್ಕಿಸಿ!\nFor more help, please contact your local agriculture office! 📞\n\n🌱 ಸಂತೋಷದಿಂದ ಕೃಷಿ ಮಾಡಿ, ಅಭಿವೃದ್ಧಿ ಹೊಂದಿ! Happy farming, prosper well! 🌾',
        'could_not_understand': '😔 ಕ್ಷಮಿಸಿ, ನಿಮ್ಮ ಪ್ರಶ್ನೆ ನನಗೆ ಅರ್ಥವಾಗಲಿಲ್ಲ। Sorry, I could not understand your question. ದಯವಿಟ್ಟು ಸರಳ ಭಾಷೆಯಲ್ಲಿ ಮತ್ತೆ ಕೇಳಿ। Please ask again in simple words.'
      },
      'bengali': {
        'greeting': '🌾 নমস্কার কৃষক ভাই/বোন! Hello farmer friend!',
        'schemes_for_you': '🌾 আপনার জন্য সেরা প্রকল্পগুলি এখানে! Here are the best schemes for you:',
        'description': '📝 বিবরণ | Description:',
        'eligibility': '✅ যোগ্যতা | Eligibility:',
        'benefits': '💰 সুবিধা | Benefits:',
        'application': '📋 আবেদন প্রক্রিয়া | Application:',
        'contact': '📞 যোগাযোগ | Contact:',
        'document': '📄 নথি | Document:',
        'farmer_profile': '🧑‍🌾 কৃষক প্রোফাইল | Farmer Profile:',
        'farm_size': '🏞️ জমির আকার | Farm Size:',
        'location': '📍 অবস্থান | Location:',
        'crop_type': '🌾 ফসলের ধরন | Crop Type:',
        'experience': '📚 অভিজ্ঞতা | Experience:',
        'question': '👨‍🌾 কৃষকের প্রশ্ন | Farmer\'s Question:',
        'best_schemes': '🌟 **আপনার জন্য সেরা প্রকল্প | Best Schemes for You:**',
        'financial_benefits': '💰 **অর্থনৈতিক সুবিধা | Financial Benefits:**',
        'you_can_apply': '✅ **আপনি আবেদন করতে পারেন | You Can Apply If:**',
        'how_to_apply': '📋 **কীভাবে আবেদন করবেন | How to Apply:**',
        'need_help': '📞 **সাহায্য দরকার? যোগাযোগ করুন | Need Help? Contact:**',
        'technical_error': '😔 কোনো প্রযুক্তিগত সমস্যা হয়েছে। Sorry, there was a technical problem. অনুগ্রহ করে পরে চেষ্টা করুন। Please try again later. 🔄',
        'closing_message': '🤝 আরও সাহায্যের জন্য আপনার নিকটতম কৃষি অফিসে যোগাযোগ করুন!\nFor more help, please contact your local agriculture office! 📞\n\n🌱 আনন্দে চাষাবাদ করুন, সমৃদ্ধ হন! Happy farming, prosper well! 🌾',
        'could_not_understand': '😔 দুঃখিত, আমি আপনার প্রশ্নটি বুঝতে পারিনি। Sorry, I could not understand your question. অনুগ্রহ করে সহজ ভাষায় আবার জিজ্ঞাসা করুন। Please ask again in simple words.'
      },
      'gujarati': {
        'greeting': '🌾 નમસ્તે ખેડૂત ભાઈ/બહેન! Hello farmer friend!',
        'schemes_for_you': '🌾 તમારા માટે શ્રેષ્ઠ યોજનાઓ અહીં છે! Here are the best schemes for you:',
        'description': '📝 વર્ણન | Description:',
        'eligibility': '✅ પાત્રતા | Eligibility:',
        'benefits': '💰 લાભો | Benefits:',
        'application': '📋 અરજી પ્રક્રિયા | Application:',
        'contact': '📞 સંપર્ક | Contact:',
        'document': '📄 દસ્તાવેજ | Document:',
        'farmer_profile': '🧑‍🌾 ખેડૂત પ્રોફાઇલ | Farmer Profile:',
        'farm_size': '🏞️ ખેતરનું કદ | Farm Size:',
        'location': '📍 સ્થાન | Location:',
        'crop_type': '🌾 પાકનો પ્રકાર | Crop Type:',
        'experience': '📚 અનુભવ | Experience:',
        'question': '👨‍🌾 ખેડૂતનો પ્રશ્ન | Farmer\'s Question:',
        'best_schemes': '🌟 **તમારા માટે શ્રેષ્ઠ યોજનાઓ | Best Schemes for You:**',
        'financial_benefits': '💰 **આર્થિક લાભો | Financial Benefits:**',
        'you_can_apply': '✅ **તમે અરજી કરી શકો છો | You Can Apply If:**',
        'how_to_apply': '📋 **કેવી રીતે અરજી કરવી | How to Apply:**',
        'need_help': '📞 **મદદ જોઈએ? સંપર્ક કરો | Need Help? Contact:**',
        'technical_error': '😔 કોઈ તકનીકી સમસ્યા થઈ છે। Sorry, there was a technical problem. કૃપા કરીને પછીથી પ્રયાસ કરો। Please try again later. 🔄',
        'closing_message': '🤝 વધુ મદદ માટે તમારી નજીકની કૃષિ ઓફિસનો સંપર્ક કરો!\nFor more help, please contact your local agriculture office! 📞\n\n🌱 ખુશીથી ખેતી કરો, સમૃદ્ધ બનો! Happy farming, prosper well! 🌾',
        'could_not_understand': '😔 માફ કરશો, હું તમારો પ્રશ્ન સમજી શક્યો નથી। Sorry, I could not understand your question. કૃપા કરીને સરળ ભાષામાં ફરીથી પૂછો। Please ask again in simple words.'
      },
      'marathi': {
        'greeting': '🌾 नमस्कार शेतकरी भाऊ/बहीण! Hello farmer friend!',
        'schemes_for_you': '🌾 तुमच्यासाठी उत्तम योजना येथे आहेत! Here are the best schemes for you:',
        'description': '📝 तपशील | Description:',
        'eligibility': '✅ पात्रता | Eligibility:',
        'benefits': '💰 फायदे | Benefits:',
        'application': '📋 अर्ज प्रक्रिया | Application:',
        'contact': '📞 संपर्क | Contact:',
        'document': '📄 कागदपत्र | Document:',
        'farmer_profile': '🧑‍🌾 शेतकरी प्रोफाइल | Farmer Profile:',
        'farm_size': '🏞️ शेताचा आकार | Farm Size:',
        'location': '📍 स्थान | Location:',
        'crop_type': '🌾 पिकाचा प्रकार | Crop Type:',
        'experience': '📚 अनुभव | Experience:',
        'question': '👨‍🌾 शेतकऱ्यांचा प्रश्न | Farmer\'s Question:',
        'best_schemes': '🌟 **तुमच्यासाठी उत्तम योजना | Best Schemes for You:**',
        'financial_benefits': '💰 **आर्थिक फायदे | Financial Benefits:**',
        'you_can_apply': '✅ **तुम्ही अर्ज करू शकता | You Can Apply If:**',
        'how_to_apply': '📋 **अर्ज कसा करावा | How to Apply:**',
        'need_help': '📞 **मदत हवी? संपर्क करा | Need Help? Contact:**',
        'technical_error': '😔 काही तांत्रिक समस्या आली आहे। Sorry, there was a technical problem. कृपया नंतर प्रयत्न करा। Please try again later. 🔄',
        'closing_message': '🤝 अधिक मदतीसाठी तुमच्या जवळच्या कृषी कार्यालयाशी संपर्क साधा!\nFor more help, please contact your local agriculture office! 📞\n\n🌱 आनंदाने शेती करा, समृद्ध व्हा! Happy farming, prosper well! 🌾',
        'could_not_understand': '😔 माफ करा, मला तुमचा प्रश्न समजला नाही। Sorry, I could not understand your question. कृपया सोप्या भाषेत पुन्हा विचारा। Please ask again in simple words.'
      },
      'punjabi': {
        'greeting': '🌾 ਸਤ ਸ੍ਰੀ ਅਕਾਲ ਕਿਸਾਨ ਭਰਾ/ਭੈਣ! Hello farmer friend!',
        'schemes_for_you': '🌾 ਤੁਹਾਡੇ ਲਈ ਸਭ ਤੋਂ ਵਧੀਆ ਸਕੀਮਾਂ ਇੱਥੇ ਹਨ! Here are the best schemes for you:',
        'description': '📝 ਵੇਰਵਾ | Description:',
        'eligibility': '✅ ਯੋਗਤਾ | Eligibility:',
        'benefits': '💰 ਫਾਇਦੇ | Benefits:',
        'application': '📋 ਅਰਜ਼ੀ ਪ੍ਰਕਿਰਿਆ | Application:',
        'contact': '📞 ਸੰਪਰਕ | Contact:',
        'document': '📄 ਦਸਤਾਵੇਜ਼ | Document:',
        'farmer_profile': '🧑‍🌾 ਕਿਸਾਨ ਪ੍ਰੋਫਾਈਲ | Farmer Profile:',
        'farm_size': '🏞️ ਖੇਤ ਦਾ ਆਕਾਰ | Farm Size:',
        'location': '📍 ਸਥਾਨ | Location:',
        'crop_type': '🌾 ਫਸਲ ਦੀ ਕਿਸਮ | Crop Type:',
        'experience': '📚 ਤਜਰਬਾ | Experience:',
        'question': '👨‍🌾 ਕਿਸਾਨ ਦਾ ਸਵਾਲ | Farmer\'s Question:',
        'best_schemes': '🌟 **ਤੁਹਾਡੇ ਲਈ ਸਭ ਤੋਂ ਵਧੀਆ ਸਕੀਮਾਂ | Best Schemes for You:**',
        'financial_benefits': '💰 **ਵਿੱਤੀ ਫਾਇਦੇ | Financial Benefits:**',
        'you_can_apply': '✅ **ਤੁਸੀਂ ਅਰਜ਼ੀ ਦੇ ਸਕਦੇ ਹੋ | You Can Apply If:**',
        'how_to_apply': '📋 **ਅਰਜ਼ੀ ਕਿਵੇਂ ਦੇਣੀ | How to Apply:**',
        'need_help': '📞 **ਮਦਦ ਚਾਹੀਦੀ ਹੈ? ਸੰਪਰਕ ਕਰੋ | Need Help? Contact:**',
        'technical_error': '😔 ਕੋਈ ਤਕਨੀਕੀ ਸਮੱਸਿਆ ਹੋਈ ਹੈ। Sorry, there was a technical problem. ਕਿਰਪਾ ਕਰਕੇ ਬਾਅਦ ਵਿੱਚ ਕੋਸ਼ਿਸ਼ ਕਰੋ। Please try again later. 🔄',
        'closing_message': '🤝 ਹੋਰ ਮਦਦ ਲਈ ਆਪਣੇ ਨੇੜਲੇ ਖੇਤੀਬਾੜੀ ਦਫ਼ਤਰ ਨਾਲ ਸੰਪਰਕ ਕਰੋ!\nFor more help, please contact your local agriculture office! 📞\n\n🌱 ਖੁਸ਼ੀ ਨਾਲ ਖੇਤੀ ਕਰੋ, ਖੁਸ਼ਹਾਲ ਬਣੋ! Happy farming, prosper well! 🌾',
        'could_not_understand': '😔 ਮਾਫ਼ ਕਰਨਾ, ਮੈਂ ਤੁਹਾਡਾ ਸਵਾਲ ਨਹੀਂ ਸਮਝ ਸਕਿਆ। Sorry, I could not understand your question. ਕਿਰਪਾ ਕਰਕੇ ਸਾਦੀ ਭਾਸ਼ਾ ਵਿੱਚ ਦੁਬਾਰਾ ਪੁੱਛੋ। Please ask again in simple words.'
      },
      'english': {
        'greeting': '🌾 Hello farmer friend!',
        'schemes_for_you': '🌾 Here are the best schemes for you:',
        'description': '📝 Description:',
        'eligibility': '✅ Eligibility:',
        'benefits': '💰 Benefits:',
        'application': '📋 Application Process:',
        'contact': '📞 Contact:',
        'document': '📄 Document:',
        'farmer_profile': '🧑‍🌾 Farmer Profile:',
        'farm_size': '🏞️ Farm Size:',
        'location': '📍 Location:',
        'crop_type': '🌾 Crop Type:',
        'experience': '📚 Experience:',
        'question': '👨‍🌾 Farmer\'s Question:',
        'best_schemes': '🌟 **Best Schemes for You:**',
        'financial_benefits': '💰 **Financial Benefits:**',
        'you_can_apply': '✅ **You Can Apply If:**',
        'how_to_apply': '📋 **How to Apply:**',
        'need_help': '📞 **Need Help? Contact:**',
        'technical_error': '😔 Sorry, there was a technical problem. Please try again later. 🔄',
        'closing_message': '🤝 For more help, please contact your local agriculture office! 📞\n\n🌱 Happy farming, prosper well! 🌾',
        'could_not_understand': '😔 Sorry, I could not understand your question. Please ask again in simple words.'
      }
    };
    
    return localizations[language] ?? localizations['hindi']!;
  }

  /// Generate response using RAG approach with multilingual support
  Future<ChatMessage> generateResponse(String userQuery, {String? locale, Map<String, String>? farmerContext}) async {
    try {
      // Get user profile for personalization with locale
      final userProfile = await _getUserProfile(locale: locale);
      
      // Determine language from profile or locale
      String language = 'hindi';
      if (userProfile?.preferredLanguage != null) {
        language = userProfile!.preferredLanguage;
      } else if (locale != null) {
        language = _getLanguageFromLocale(locale);
      }
      
      final localTexts = _getLocalizedText(language);
      
      // Find relevant schemes
      final relevantSchemes = await _findRelevantSchemes(userQuery, userProfile);
      
      // Create context from relevant schemes
      String context = '';
      if (relevantSchemes.isNotEmpty) {
        context = '${localTexts['schemes_for_you']}\n\n';
        for (int i = 0; i < relevantSchemes.length; i++) {
          final scheme = relevantSchemes[i];
          context += '''
🌟 ${i + 1}. ${scheme.name}
   ${localTexts['description']} ${scheme.description}
   ${localTexts['eligibility']} ${scheme.eligibility}
   ${localTexts['benefits']} ${scheme.benefits}
   ${localTexts['application']} ${scheme.applicationProcess}
   ${localTexts['contact']} ${scheme.contactInfo}
   ${localTexts['document']} ${scheme.documentUrl}

''';
        }
      }
      
      // Create personalized prompt
      String profileContext = '';
      if (userProfile != null) {
        profileContext = '''
${localTexts['farmer_profile']}
- ${localTexts['farm_size']} ${userProfile.farmSize}
- ${localTexts['location']} ${userProfile.location}
- ${localTexts['crop_type']} ${userProfile.cropType}
- ${localTexts['experience']} ${userProfile.experience}

''';
      } else if (farmerContext != null && farmerContext.isNotEmpty) {
        // Use farmer context from form if available
        profileContext = '''
${localTexts['farmer_profile']}
- ${localTexts['location']} ${farmerContext['location'] ?? 'Not specified'}
- ${localTexts['farm_size']} ${farmerContext['farm_size'] ?? 'Not specified'}
- ${localTexts['crop_type']} ${farmerContext['crops'] ?? 'Not specified'}
- Income Range: ${farmerContext['income_range'] ?? 'Not specified'}

''';
      }

      // Create multilingual prompt based on user's preferred language
      String systemPrompt = _createMultilingualPrompt(language, localTexts);
      
      final prompt = '''
$systemPrompt

$profileContext

$context

${localTexts['question']} $userQuery

Please provide a clear, helpful answer in ${language == 'english' ? 'English' : 'the user\'s preferred language ($language) with English support'} that:

🎯 **Response Guidelines:**
• Use relevant emojis sparingly for clarity
• Keep formatting simple and readable
• Include exact rupee amounts (₹X,XXX) and percentages
• Use numbered steps when explaining processes
• Be encouraging and supportive
• Include practical, actionable information
• Make URLs and phone numbers clearly visible
• Use clean, organized structure

**Format Response Simply:**
- Start with a brief, friendly greeting
- Provide clear, concise information
- Use bullet points for lists
- End with helpful contact information if relevant

Keep the response clean, readable, and easy to understand without excessive formatting or boundary lines.  
• ✓ आप [specific conditions] हैं

📋 **सुपर आसान आवेदन | Super Easy Application:**
1. 🏢 Visit: [Office name + address]
2. 📄 Documents: आधार + जमीन के कागज
3. 📝 Form: Online/Offline दोनों OK
4. ⏰ Deadline: [Date] - जल्दी करें!
5. 📱 Updates: SMS में मिलेगा status

🔗 **Important Links (Click करने योग्य):**
• 🌐 Portal: [URL] - Direct apply करें
• 📱 Helpline: [Phone] - Free calling  
• 📧 Email: [Email] - Doubts पूछें

🎉 **Success Story:** 
किसान [Name] जी ने ₹XX,XXX benefit लिया!
```

Make every response feel personal, exciting, and actionable! 🚀
''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      
      // Post-process response to ensure farmer-friendly format
      String processedResponse = _makeResponseFarmerFriendly(
        response.text ?? localTexts['could_not_understand']!,
        language
      );
      
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: processedResponse,
        isUser: false,
        timestamp: DateTime.now(),
        recommendedSchemes: relevantSchemes.isNotEmpty ? relevantSchemes : null,
      );
      
    } catch (e) {
      print('Error generating response: $e');
      final language = 'hindi'; // fallback to hindi
      final localTexts = _getLocalizedText(language);
      
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: localTexts['technical_error']!,
        isUser: false,
        timestamp: DateTime.now(),
      );
    }
  }

  /// Create multilingual system prompt
  String _createMultilingualPrompt(String language, Map<String, String> localTexts) {
    final languageInstructions = {
      'hindi': 'आप एक मददगार AI सहायक हैं जो भारतीय किसान योजनाओं में विशेषज्ञ हैं। हिंदी-अंग्रेजी मिश्रित भाषा का प्रयोग करें।',
      'tamil': 'நீங்கள் இந்திய விவசாயி திட்டங்களில் நிபுணத்துவம் பெற்ற உதவிகரமான AI உதவியாளர். தமிழ்-ஆங்கில கலப்பு மொழியைப் பயன்படுத்துங்கள்।',
      'telugu': 'మీరు భారతీయ రైతు పథకాలలో నిపుణుడైన సహాయకారి AI అసిస్టెంట్. తెలుగు-ఇంగ్లీష్ మిశ్రమ భాష ఉపయోగించండి।',
      'kannada': 'ನೀವು ಭಾರತೀಯ ರೈತ ಯೋಜನೆಗಳಲ್ಲಿ ಪರಿಣಿತರಾದ ಸಹಾಯಕಾರಿ AI ಸಹಾಯಕ. ಕನ್ನಡ-ಇಂಗ್ಲಿಷ್ ಮಿಶ್ರ ಭಾಷೆಯನ್ನು ಬಳಸಿ।',
      'bengali': 'আপনি ভারতীয় কৃষক প্রকল্পে বিশেষজ্ঞ একজন সহায়ক AI সহায়ক। বাংলা-ইংরেজি মিশ্র ভাষা ব্যবহার করুন।',
      'gujarati': 'તમે ભારતીય ખેડૂત યોજનાઓમાં નિષ્ણાત મદદગાર AI સહાયક છો. ગુજરાતી-અંગ્રેજી મિશ્ર ભાષાનો ઉપયોગ કરો।',
      'marathi': 'तुम्ही भारतीय शेतकरी योजनांमध्ये तज्ञ असलेले मदतगार AI सहाय्यक आहात. मराठी-इंग्रजी मिश्र भाषेचा वापर करा।',
      'punjabi': 'ਤੁਸੀਂ ਭਾਰਤੀ ਕਿਸਾਨ ਸਕੀਮਾਂ ਵਿੱਚ ਮਾਹਰ ਇੱਕ ਮਦਦਗਾਰ AI ਸਹਾਇਕ ਹੋ। ਪੰਜਾਬੀ-ਅੰਗਰੇਜ਼ੀ ਮਿਸ਼ਰਤ ਭਾਸ਼ਾ ਦੀ ਵਰਤੋਂ ਕਰੋ।',
      'english': 'You are a helpful AI assistant specialized in Indian farmer schemes and government policies. Use clear, simple English.'
    };

    return '''
${languageInstructions[language] ?? languageInstructions['hindi']!}

Instructions for beautiful paragraph responses:
• Write responses as flowing paragraphs, not bullet points or lists
• Keep language simple and conversational like talking to a friend
• Use maximum 1-2 emojis per paragraph, not per line
• Focus on essential information: scheme name, benefit amount, how to apply
• Make it sound natural and easy to read
• No visual separators, asterisks, or excessive formatting
• Write like you're explaining to someone sitting next to you

Example of good paragraph response:
"🌾 Great news! I found two perfect schemes for you. The PM-KISAN scheme gives you ₹6,000 per year directly to your bank account and all farmers with land can apply at any CSC center. There's also Crop Insurance that provides coverage up to ₹2 lakh for crop damage, and you can apply through your bank before the sowing season starts. If you need any help with applications, just call 1551 or visit your nearest agriculture office."

Write everything as natural, flowing paragraphs!
''';
  }

  /// Make response more farmer-friendly with beautiful, clean formatting
  String _makeResponseFarmerFriendly(String response, String language) {
    String friendlyResponse = response;
    final localTexts = _getLocalizedText(language);
    
    // Fix currency placeholders first
    friendlyResponse = _fixCurrencyPlaceholders(friendlyResponse);
    
    // Remove ALL visual clutter and separators
    friendlyResponse = _beautifyResponse(friendlyResponse);
    
    // Add a simple, warm greeting
    if (!friendlyResponse.toLowerCase().contains('hello') && 
        !friendlyResponse.toLowerCase().contains('hi')) {
      friendlyResponse = '🌾 Hello! Here\'s what I found for you:\n\n$friendlyResponse';
    }
    
    // Format money amounts cleanly
    friendlyResponse = friendlyResponse.replaceAllMapped(
      RegExp(r'₹\s*(\d{1,3}(?:,\d{3})*(?:\.\d{2})?)'),
      (match) => '₹${match.group(1)}',
    );
    
    // Keep URLs clickable — label + original link (do not strip the URL)
    friendlyResponse = friendlyResponse.replaceAllMapped(
      RegExp(r'https?://[^\s\]\*\)]+'),
      (match) => '🔗 Apply Online: ${match.group(0)}',
    );
    
    // Format phone numbers nicely
    friendlyResponse = friendlyResponse.replaceAllMapped(
      RegExp(r'(\d{3,4})[-\s]?(\d{6,7})'),
      (match) => '📞 ${match.group(1)}-${match.group(2)}',
    );
    
    // Make scheme names stand out
    friendlyResponse = friendlyResponse.replaceAllMapped(
      RegExp(r'PM-KISAN|PMFBY|KCC|Fasal Bima|Kisan Credit'),
      (match) => '🏆 ${match.group(0)}',
    );
    
    // Clean up final formatting
    friendlyResponse = friendlyResponse.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    friendlyResponse = friendlyResponse.replaceAll(RegExp(r'\s{2,}'), ' ');
    
    // Ensure proper spacing around emojis
    friendlyResponse = friendlyResponse.replaceAll(RegExp(r'([^\s])([🌾🏆💰📞🔗])'), r'$1 $2');
    friendlyResponse = friendlyResponse.replaceAll(RegExp(r'([🌾🏆💰📞🔗])([^\s])'), r'$1 $2');
    
    return friendlyResponse.trim();
  }

  /// Clean and beautify the generated response - convert to paragraph format
  String _beautifyResponse(String response) {
    // Remove all boundary lines and visual separators
    response = response.replaceAll(RegExp(r'[-─═_]{3,}'), '');
    response = response.replaceAll(RegExp(r'[│┃|]{2,}'), '');
    response = response.replaceAll(RegExp(r'[┌┐└┘├┤┬┴┼╔╗╚╝╠╣╦╩╬]+'), '');
    response = response.replaceAll(RegExp(r'^\s*[-=_]+\s*$', multiLine: true), '');
    
    // Remove excessive asterisks and formatting
    response = response.replaceAll(RegExp(r'\*{2,}'), '');
    response = response.replaceAll(RegExp(r'\*([^*\n]+)\*'), r'$1');
    response = response.replaceAll(RegExp(r'_{2,}'), '');
    
    // Clean up excessive emojis (max 1 per line)
    response = response.replaceAll(RegExp(r'([🌾🏆💰📞🔗📱🌟✅❌])(\s*\1)+'), r'$1');
    
    // Remove repetitive words
    response = response.replaceAll(RegExp(r'\b(\w+)\s+\1\b'), r'$1');
    
    // Convert bullet points and lists to paragraph format
    response = response.replaceAll(RegExp(r'^\s*[•·‣⁃◦▪▫-]\s*', multiLine: true), '');
    response = response.replaceAll(RegExp(r'^\s*\d+\.\s*', multiLine: true), '');
    
    // Convert multiple short lines into flowing paragraphs
    List<String> lines = response.split('\n');
    StringBuffer paragraphBuffer = StringBuffer();
    StringBuffer currentParagraph = StringBuffer();
    
    for (String line in lines) {
      line = line.trim();
      if (line.isEmpty) {
        if (currentParagraph.isNotEmpty) {
          paragraphBuffer.writeln(currentParagraph.toString().trim());
          paragraphBuffer.writeln();
          currentParagraph.clear();
        }
      } else if (line.length < 50 && !line.contains(':') && !line.startsWith('🌾')) {
        // Short lines get merged into paragraph
        if (currentParagraph.isNotEmpty) {
          currentParagraph.write(' ');
        }
        currentParagraph.write(line);
      } else {
        // Longer lines or headers stay separate
        if (currentParagraph.isNotEmpty) {
          paragraphBuffer.writeln(currentParagraph.toString().trim());
          currentParagraph.clear();
        }
        paragraphBuffer.writeln(line);
      }
    }
    
    if (currentParagraph.isNotEmpty) {
      paragraphBuffer.writeln(currentParagraph.toString().trim());
    }
    
    response = paragraphBuffer.toString();
    
    // Remove parentheses with placeholder text
    response = response.replaceAll(RegExp(r'\([^)]*(?:Potential|Total|depending)[^)]*\)'), '');
    
    // Remove excessive spaces and newlines
    response = response.replaceAll(RegExp(r' {2,}'), ' ');
    response = response.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    response = response.replaceAll(RegExp(r'^\s+|\s+$', multiLine: true), '');
    
    return response.trim();
  }

  /// Save user profile to Firestore
  Future<void> saveUserProfile(UserProfile profile) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set({
        'farmingProfile': profile.toJson(),
        'profileUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving user profile: $e');
    }
  }

  /// Get initial greeting message with farmer info collection
  ChatMessage getInitialGreeting({String? locale}) {
    String language = 'hindi';
    if (locale != null) {
      language = _getLanguageFromLocale(locale);
    }
    
    final localTexts = _getLocalizedText(language);
    
    String greeting;
    
    if (language == 'english') {
      greeting = '''
${localTexts['greeting']}

🌾 **I'm your personal scheme assistant!**

💡 **For better suggestions, please tell me:**

🏞️ **What's your farm size?**
• Small (1-2 acres)
• Medium (3-10 acres)  
• Large (10+ acres)

📍 **Where are you from?**
• State and district

🌾 **What do you grow?**
• Rice
• Wheat
• Corn
• Vegetables
• Fruits
• Others

💰 **Your annual income range:**
• Below ₹2 lakhs
• ₹2-5 lakhs
• ₹5-10 lakhs
• Above ₹10 lakhs

✨ **Just tell me in your own words, and I'll help you find the best government schemes!**
''';
    } else if (language == 'tamil') {
      greeting = '''
${localTexts['greeting']}

🌾 **நான் உங்கள் தனிப்பட்ட திட்ட உதவியாளர்!**

💡 **சிறந்த பரிந்துரைகளுக்காக, தயவுசெய்து சொல்லுங்கள்:**

🏞️ **உங்கள் நிலத்தின் அளவு என்ன?**
• சிறிய (1-2 ஏக்கர்)
• நடுத்தர (3-10 ஏக்கர்)  
• பெரிய (10+ ஏக்கர்)

📍 **நீங்கள் எங்கிருந்து வருகிறீர்கள்?**
• மாநிலம் மற்றும் மாவட்டம்

🌾 **நீங்கள் என்ன வளர்க்கிறீர்கள்?**
• நெல்
• கோதுமை
• சோளம்
• காய்கறிகள்
• பழங்கள்
• மற்றவை

💰 **உங்கள் ஆண்டு வருமான வரம்பு:**
• ₹2 லட்சத்திற்கும் கீழே
• ₹2-5 லட்சம்
• ₹5-10 லட்சம்
• ₹10 லட்சத்திற்கும் மேலே

✨ **உங்கள் சொந்த வார்த்தைகளில் சொல்லுங்கள், சிறந்த அரசு திட்டங்களைக் கண்டுபிடிக்க உதவுவேன்!**
''';
    } else if (language == 'telugu') {
      greeting = '''
${localTexts['greeting']}

🌾 **నేను మీ వ్యక్తిగత పథకాల సహాయకుడను!**

💡 **మెరుగైన సూచనల కోసం, దయచేసి చెప్పండి:**

🏞️ **మీ పొలం పరిమాణం ఎంత?**
• చిన్నది (1-2 ఎకరాలు)
• మధ్యమమైనది (3-10 ఎకరాలు)  
• పెద్దది (10+ ఎకరాలు)

📍 **మీరు ఎక్కడ నుండి వచ్చారు?**
• రాష్ట్రం మరియు జిల్లా

🌾 **మీరు ఏమి పండిస్తారు?**
• వరి
• గోధుమలు
• మొక్కజొన్న
• కూరగాయలు
• పండ్లు
• ఇతరవి

💰 **మీ వార్షిక ఆదాయ పరిధి:**
• ₹2 లక్షలకు తక్కువ
• ₹2-5 లక్షలు
• ₹5-10 లక్షలు
• ₹10 లక్షలకు మించి

✨ **మీ స్వంత మాటల్లో చెప్పండి, ఉత్తమ ప్రభుత్వ పథకాలను కనుగొనడంలో సహాయం చేస్తాను!**
''';
    } else {
      // Hindi and bilingual version (default)
      greeting = '''
${localTexts['greeting']}

🌾 **मैं आपका व्यक्तिगत योजना सहायक हूँ! I'm your personal scheme assistant!**

💡 **बेहतर सुझाव के लिए, कृपया बताएं | For better suggestions, please tell me:**

🏞️ **आपके खेत का आकार क्या है? | What's your farm size?**
• छोटा (1-2 एकड़) | Small (1-2 acres)
• मध्यम (3-10 एकड़) | Medium (3-10 acres)  
• बड़ा (10+ एकड़) | Large (10+ acres)

📍 **आप कहाँ से हैं? | Where are you from?**
• राज्य और जिला बताएं | State and district

🌾 **आप क्या उगाते हैं? | What do you grow?**
• धान | Rice
• गेहूँ | Wheat
• मक्का | Corn
• सब्जियाँ | Vegetables
• फल | Fruits
• अन्य | Others

💰 **आपकी वार्षिक आय सीमा | Your annual income range:**
• ₹2 लाख से कम | Below ₹2 lakhs
• ₹2-5 लाख | ₹2-5 lakhs
• ₹5-10 लाख | ₹5-10 lakhs
• ₹10 लाख से अधिक | Above ₹10 lakhs

✨ **बस अपने शब्दों में बताएं, मैं आपको सबसे अच्छी सरकारी योजनाएं ढूंढने में मदद करूंगा! Just tell me in your own words, and I'll help you find the best government schemes!**
''';
    }

    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: greeting,
      isUser: false,
      timestamp: DateTime.now(),
    );
  }

  /// Check if message contains farmer profile information
  Map<String, String> extractFarmerInfo(String message) {
    Map<String, String> info = {};
    String lowerMessage = message.toLowerCase();

    // Extract farm size
    if (lowerMessage.contains('छोटा') || lowerMessage.contains('small') || 
        lowerMessage.contains('1') || lowerMessage.contains('2')) {
      info['farmSize'] = 'Small (1-2 acres)';
    } else if (lowerMessage.contains('मध्यम') || lowerMessage.contains('medium') ||
               lowerMessage.contains('3') || lowerMessage.contains('10')) {
      info['farmSize'] = 'Medium (3-10 acres)';
    } else if (lowerMessage.contains('बड़ा') || lowerMessage.contains('large') ||
               lowerMessage.contains('10+')) {
      info['farmSize'] = 'Large (10+ acres)';
    }

    // Extract crop type
    List<String> crops = [];
    if (lowerMessage.contains('धान') || lowerMessage.contains('rice')) crops.add('Rice');
    if (lowerMessage.contains('गेहूँ') || lowerMessage.contains('wheat')) crops.add('Wheat');
    if (lowerMessage.contains('मक्का') || lowerMessage.contains('corn')) crops.add('Corn');
    if (lowerMessage.contains('सब्जी') || lowerMessage.contains('vegetable')) crops.add('Vegetables');
    if (lowerMessage.contains('फल') || lowerMessage.contains('fruit')) crops.add('Fruits');
    
    if (crops.isNotEmpty) {
      info['cropType'] = crops.join(', ');
    }

    // Extract location (basic pattern matching)
    List<String> indianStates = [
      'उत्तर प्रदेश', 'up', 'uttar pradesh',
      'पंजाब', 'punjab',
      'हरियाणा', 'haryana',
      'राजस्थान', 'rajasthan',
      'मध्य प्रदेश', 'mp', 'madhya pradesh',
      'महाराष्ट्र', 'maharashtra',
      'कर्नाटक', 'karnataka',
      'तमिलनाडु', 'tamil nadu',
      'आंध्र प्रदेश', 'andhra pradesh',
      'तेलंगाना', 'telangana',
      'केरल', 'kerala',
      'गुजरात', 'gujarat',
      'पश्चिम बंगाल', 'west bengal',
      'बिहार', 'bihar',
      'ओडिशा', 'odisha'
    ];

    for (String state in indianStates) {
      if (lowerMessage.contains(state)) {
        info['location'] = state;
        break;
      }
    }

    return info;
  }

  /// Test method to verify currency fixing works correctly
  String testCurrencyFixes() {
    const testResponse = '''
    Welcome to PM-KISAN scheme! The benefit amount is \$1 per year.
    For crop insurance, you can get coverage up to \$1.
    Apply by calling \$1 your nearest bank.
    The subsidy amount is \$1Agriculture\$1 related.
    Visit CSC for \$1Farmer\$1 registration.
    ''';
    
    return _fixCurrencyPlaceholders(testResponse);
  }

  String _fixCurrencyPlaceholders(String response) {
    // Fix special patterns first (before general $1 replacement)
    Map<String, String> specialPatterns = {
      r'\$1Agriculture\$1': 'Agriculture',
      r'\$1Farmer\$1': 'Farmer', 
      r'\$1Scheme\$1': 'Scheme',
      r'Click on "New \$1 Registration\."': 'Click on "New PM-KISAN Registration."',
      r'Call \$1 your nearest bank': 'Call your nearest bank',
      r'Dial 1551 for assistance\.': 'Dial 1551 for PM-KISAN assistance.',
    };

    String fixedResponse = response;
    
    // Apply special pattern fixes first
    specialPatterns.forEach((pattern, replacement) {
      fixedResponse = fixedResponse.replaceAll(RegExp(pattern), replacement);
    });

    // Fix context-specific $1 patterns
    fixedResponse = fixedResponse.replaceAllMapped(
      RegExp(r'\$1\s*([\w\s]*(?:subsidy|amount|benefit|payment|support))'),
      (match) {
        String context = match.group(1)?.toLowerCase() ?? '';
        if (context.contains('subsidy')) {
          return 'Rs.50,000-2,00,000 ${match.group(1)}';
        } else if (context.contains('benefit')) {
          return 'Rs.6,000-12,000 ${match.group(1)}';
        } else if (context.contains('support')) {
          return 'Rs.25,000-1,00,000 ${match.group(1)}';
        }
        return 'Rs.varies ${match.group(1)}';
      },
    );

    // Replace remaining standalone $1 with appropriate amounts based on context
    List<String> sentences = fixedResponse.split('.');
    for (int i = 0; i < sentences.length; i++) {
      String sentence = sentences[i].toLowerCase();
      if (sentences[i].contains('\$1')) {
        if (sentence.contains('pm-kisan') || sentence.contains('kisan')) {
          sentences[i] = sentences[i].replaceAll('\$1', 'Rs.6,000 per year');
        } else if (sentence.contains('insurance') || sentence.contains('coverage')) {
          sentences[i] = sentences[i].replaceAll('\$1', 'Rs.2,00,000');
        } else if (sentence.contains('credit') || sentence.contains('loan')) {
          sentences[i] = sentences[i].replaceAll('\$1', 'Rs.3,00,000');
        } else if (sentence.contains('subsidy') || sentence.contains('equipment')) {
          sentences[i] = sentences[i].replaceAll('\$1', '40-50% subsidy');
        } else {
          sentences[i] = sentences[i].replaceAll('\$1', 'Rs.6,000-12,000');
        }
      }
    }
    fixedResponse = sentences.join('.');

    // Fix double words caused by replacements
    fixedResponse = fixedResponse.replaceAll(RegExp(r'\b(\w+)\s+\1\b'), r'$1');
    
    // Clean up formatting
    fixedResponse = fixedResponse.replaceAll(RegExp(r'\s+'), ' ');
    fixedResponse = fixedResponse.replaceAll(RegExp(r'\n\s*\n\s*\n'), '\n\n');
    
    return fixedResponse;
  }

  /// ENHANCED RAG-BASED QUERY METHOD WITH PERSONALIZATION
  /// Query agricultural documents using Retrieval-Augmented Generation with user profile
  Future<String> queryWithRAG(String userQuestion, String language, {Map<String, dynamic>? userProfile}) async {
    try {
      print('🔍 Querying enhanced RAG system: $userQuestion');
      if (userProfile != null) {
        print('👤 With user profile: $userProfile');
      }
      
      // Try personalized RAG first if profile is available
      if (userProfile != null) {
        try {
          final response = await http.post(
            Uri.parse('https://us-central1-terafarmsih.cloudfunctions.net/personalizedRAGQuery'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'query': userQuestion,
              'language': language,
              'userProfile': userProfile,
              'limit': 5,
            }),
          );
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            
            if (data['success'] == true && data['answer'] != null) {
              final answer = data['answer'] as String;
              final context = data['context'] as List?;
              final embeddingUsed = data['embeddingUsed'] as bool? ?? false;
              
              print('✅ Personalized RAG Response received: ${answer.length} characters');
              print('🧠 Embedding used: $embeddingUsed');
              print('📄 Context chunks: ${context?.length ?? 0}');
              
              // Apply existing formatting logic
              String formattedAnswer = _beautifyResponse(answer);
              
              // Add context information with relevance scores
              if (context != null && context.isNotEmpty) {
                final contextInfo = context.map((c) {
                  final similarity = c['similarity'] ?? 0.0;
                  final hasEmbedding = c['hasEmbedding'] ?? false;
                  return 'Document (${(similarity * 100).toStringAsFixed(0)}% ${hasEmbedding ? 'AI' : 'text'} match)';
                }).join(', ');
                formattedAnswer += '\n\n📊 Sources: $contextInfo';
              }
              
              return formattedAnswer;
            }
          }
        } catch (e) {
          print('⚠️ Personalized RAG failed, falling back to standard RAG: $e');
        }
      }
      
      // Fallback to standard RAG function
      final response = await http.post(
        Uri.parse('https://us-central1-terafarmsih.cloudfunctions.net/ragQuery'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': userQuestion,
          'language': language,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true && data['answer'] != null) {
          final answer = data['answer'] as String;
          final context = data['context'] as List?;
          
          print('✅ Standard RAG Response received: ${answer.length} characters');
          print('📄 Context chunks: ${context?.length ?? 0}');
          
          // Apply existing formatting logic
          String formattedAnswer = _beautifyResponse(answer);
          
          // Add context information if available
          if (context != null && context.isNotEmpty) {
            final contextInfo = context.map((c) => c['similarity']?.toString() ?? 'N/A').join('%, ');
            formattedAnswer += '\n\n📚 Relevance scores: ${contextInfo}%';
          }
          
          return formattedAnswer;
        } else {
          throw Exception('No answer received from RAG system: ${data['error'] ?? 'Unknown error'}');
        }
      } else {
        throw Exception('HTTP Error ${response.statusCode}: ${response.body}');
      }
      
    } catch (e) {
      print('❌ RAG Query Error: $e');
      
      // Fallback to traditional method
      print('🔄 Falling back to traditional chatbot...');
      final fallbackResponse = await generateResponse(userQuestion, locale: language);
      return fallbackResponse.content;
    }
  }

  /// Manage user profile for personalized recommendations
  Future<Map<String, dynamic>?> manageUserProfile({
    required String action, // 'create', 'update', 'get', 'delete'
    required String userId,
    Map<String, dynamic>? profile,
  }) async {
    try {
      print('👤 Managing user profile: $action for $userId');
      
      final response = await http.post(
        Uri.parse('https://us-central1-terafarmsih.cloudfunctions.net/manageFarmerProfile'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': action,
          'userId': userId,
          'profile': profile,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          print('✅ Profile $action successful');
          return data['profile'];
        } else {
          print('❌ Profile $action failed: ${data['error']}');
          return null;
        }
      } else {
        print('❌ HTTP Error ${response.statusCode}: ${response.body}');
        return null;
      }
      
    } catch (e) {
      print('❌ Profile management error: $e');
      return null;
    }
  }

  /// Get current user profile for personalized responses
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    return await manageUserProfile(action: 'get', userId: userId);
  }

  /// Create or update user profile for personalized RAG
  Future<bool> savePersonalizedProfile(String userId, Map<String, dynamic> profileData) async {
    final result = await manageUserProfile(
      action: 'update', 
      userId: userId, 
      profile: profileData
    );
    return result != null;
  }

  /// Process PDF documents for RAG system
  Future<String> processPdfForRAG(String pdfUrl, String documentId, String title) async {
    try {
      print('📄 Processing PDF for RAG: $title');
      
      final HttpsCallable callable = _functions.httpsCallable('processPdfForRAG');
      
      final result = await callable.call({
        'pdfUrl': pdfUrl,
        'documentId': documentId,
        'title': title,
      });
      
      if (result.data != null && result.data['success'] == true) {
        final chunksProcessed = result.data['chunksProcessed'] as int;
        final totalCharacters = result.data['totalCharacters'] as int;
        
        print('✅ PDF processed: $chunksProcessed chunks, $totalCharacters characters');
        
        return 'Successfully processed "$title" into $chunksProcessed searchable chunks ($totalCharacters characters).';
      } else {
        throw Exception('Failed to process PDF: ${result.data?['error'] ?? 'Unknown error'}');
      }
      
    } catch (e) {
      print('❌ PDF Processing Error: $e');
      return 'Failed to process PDF document: ${e.toString()}';
    }
  }

  /// Enhanced chat response method that uses personalized RAG by default
  Future<String> getChatbotResponse(String userMessage, String language, {String? userId}) async {
    try {
      print('🤖 Enhanced AI: Processing query - $userMessage');
      
      // Get user profile for personalization if userId is provided
      Map<String, dynamic>? userProfile;
      String? profileContext;
      
      if (userId != null) {
        userProfile = await getUserProfile(userId);
        print('👤 Retrieved profile for $userId: ${userProfile != null ? 'found' : 'not found'}');
        
        // Create profile context string for enhanced AI
        if (userProfile != null) {
          profileContext = '''
Location: ${userProfile['location'] ?? 'Not specified'}
Farm Size: ${userProfile['farm_size'] ?? 'Not specified'}
Crops: ${userProfile['crops'] ?? 'Not specified'}
Income Range: ${userProfile['income_range'] ?? 'Not specified'}
Language: ${userProfile['preferred_language'] ?? language}
''';
        }
      }
      
      // Map language to locale format
      String locale = _mapLanguageToLocale(language);
      
      // Use Enhanced AI Service for better, farmer-friendly responses
      final enhancedResponse = await _enhancedAI.generateFarmerFriendlyResponse(
        userMessage, 
        userProfile: profileContext,
        locale: locale
      );
      
      print('✅ Enhanced AI Response Generated');
      return enhancedResponse;
      
    } catch (e) {
      print('❌ Enhanced AI Error: $e');
      
      // Fallback to traditional method if enhanced AI fails
      try {
        final fallbackResponse = await generateResponse(userMessage, locale: language);
        return fallbackResponse.content;
      } catch (fallbackError) {
        print('❌ Fallback Error: $fallbackError');
        return _getEmergencyFallbackResponse(userMessage, language);
      }
    }
  }

  /// Backward compatibility method without userId
  Future<String> getChatbotResponseSimple(String userMessage, String language) async {
    return getChatbotResponse(userMessage, language);
  }

  /// Map language to locale format for enhanced AI
  String _mapLanguageToLocale(String language) {
    Map<String, String> languageMap = {
      'hindi': 'hindi',
      'english': 'english',
      'tamil': 'tamil',
      'telugu': 'telugu',
      'hi': 'hindi',
      'en': 'english',
      'ta': 'tamil',
      'te': 'telugu',
    };
    
    return languageMap[language.toLowerCase()] ?? 'hindi';
  }

  /// Emergency fallback response when all AI systems fail
  String _getEmergencyFallbackResponse(String userMessage, String language) {
    Map<String, String> emergencyResponses = {
      'hindi': '''
**🙏 माफ करें, तकनीकी समस्या है**

आपका सवाल: "$userMessage"

**तुरंत मदद के लिए:**
📞 किसान कॉल सेंटर: 1800-180-1551
🌐 PM-KISAN पोर्टल: https://pmkisan.gov.in
🏢 नजदीकी कृषि कार्यालय में जाएं

**मुख्य योजनाएं:**
• PM-KISAN: ₹6000 सालाना
• फसल बीमा: नुकसान की भरपाई
• KCC लोन: 4% ब्याज दर

कृपया दोबारा कोशिश करें या सीधे संपर्क करें।
''',
      'english': '''
**🙏 Sorry, Technical Issue**

Your question: "$userMessage"

**For immediate help:**
📞 Kisan Call Center: 1800-180-1551
🌐 PM-KISAN Portal: https://pmkisan.gov.in
🏢 Visit nearest agriculture office

**Main schemes:**
• PM-KISAN: ₹6000 annually
• Crop Insurance: Loss compensation
• KCC Loan: 4% interest rate

Please try again or contact directly.
''',
    };

    return emergencyResponses[language] ?? emergencyResponses['hindi']!;
  }

  /// Batch process multiple PDFs for RAG system
  Future<String> batchProcessPdfsForRAG(List<Map<String, String>> documents) async {
    try {
      print('📚 Batch processing ${documents.length} PDFs for RAG');
      
      final HttpsCallable callable = _functions.httpsCallable('batchProcessPdfs');
      
      final result = await callable.call({
        'documents': documents,
      });
      
      if (result.data != null && result.data['success'] == true) {
        final totalDocuments = result.data['totalDocuments'] as int;
        final successCount = result.data['successCount'] as int;
        final failureCount = result.data['failureCount'] as int;
        
        print('✅ Batch processing complete: $successCount/$totalDocuments succeeded');
        
        return 'Batch processing complete:\n• Total documents: $totalDocuments\n• Successfully processed: $successCount\n• Failed: $failureCount';
      } else {
        throw Exception('Batch processing failed: ${result.data?['error'] ?? 'Unknown error'}');
      }
      
    } catch (e) {
      print('❌ Batch Processing Error: $e');
      return 'Failed to batch process PDFs: ${e.toString()}';
    }
  }
}