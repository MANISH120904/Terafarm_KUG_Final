/**
 * MULTILINGUAL VOICE ASSISTANT FOR TERAFARM
 * 
 * HOW TO USE:
 * 1. Import this file: import 'voice_assistance.dart';
 * 2. Add to any page's Scaffold: floatingActionButton: const VoiceAssistantWidget(),
 * 
 * FEATURES:
 * - Supports 10 Indian languages (Hindi, Tamil, Telugu, Kannada, Malayalam, etc.)
 * - AI-powered command understanding with local fallback
 * - Natural voice responses in user's language
 * - Smart navigation to all major app pages
 * 
 * VOICE COMMANDS EXAMPLES:
 * English: "go to dashboard", "show marketplace", "crop suggestions"
 * Hindi: "डैशबोर्ड पर जाओ", "बाजार दिखाओ", "फसल सुझाव"
 * Tamil: "டாஷ்போர்டுக்கு செல்", "சந்தையைக் காட்டு", "பயிர் பரிந்துரைகள்"
 */

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';

// Import localization
import 'main.dart' show LocaleProvider;

// Import the necessary services and pages for navigation
import 'services/navigation_service.dart';
import 'main_navigation.dart';
import 'dashboard_page.dart';
import 'plant_growth_analysis_page.dart';
import 'crop_suggestion_page.dart';
import 'list_farm_page.dart';
import 'grow_plant_page.dart';
import 'Community_page.dart';
import 'ai_page.dart';
import 'marketplace.dart';
import 'cart_page.dart';

// Import Firestore for product search and ordering
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import weather and location services
import 'package:http/http.dart' as http;
import 'location.dart';
import 'config/api_keys.dart';

// 1. Voice Assistant State Management
class VoiceAssistantState with ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  late final GenerativeModel _model;

  // Language support for Indian languages
  final Map<String, String> _supportedLanguages = {
    'en-IN': 'English (India)',
    'hi-IN': 'Hindi',
    'ta-IN': 'Tamil', 
    'te-IN': 'Telugu',
    'kn-IN': 'Kannada',
    'ml-IN': 'Malayalam',
    'mr-IN': 'Marathi',
    'gu-IN': 'Gujarati',
    'bn-IN': 'Bengali',
    'pa-IN': 'Punjabi',
  };
  
  String _currentLanguage = 'en-IN'; // Default to English (India)
  
  bool _isListening = false;
  String _lastWords = '';
  String _status = "Idle";
  BuildContext? _currentContext;

  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  String get status => _status;
  String get currentLanguage => _currentLanguage;
  Map<String, String> get supportedLanguages => _supportedLanguages;

  VoiceAssistantState() {
    _init();
  }

  void syncWithLocaleProvider(LocaleProvider localeProvider) {
    // Listen to locale changes and sync voice assistant language
    localeProvider.addListener(() {
      String currentLocale = localeProvider.locale.languageCode;
      String voiceLanguageCode = '$currentLocale-IN';
      
      if (_supportedLanguages.containsKey(voiceLanguageCode)) {
        if (_currentLanguage != voiceLanguageCode) {
          print('🔄 Voice Assistant: Auto-syncing language to $voiceLanguageCode');
          switchLanguage(voiceLanguageCode);
        }
      }
    });
  }

  void _init() async {
    // Initialize Gemini with a proper API key
    // Get your free API key from: https://aistudio.google.com/app/apikey
    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: ApiKeys.gemini,
    );
    
    await _speechToText.initialize(
      onError: (error) => _updateStatus("STT Error: $error"),
      onStatus: (status) => print('STT Status: $status'),
    );
    
    // Configure TTS for more natural voice with Indian language support
    await _flutterTts.setLanguage(_currentLanguage);
    await _flutterTts.setSpeechRate(0.5); // Slightly slower for clarity
    await _flutterTts.setVolume(0.8); // Comfortable volume
    await _flutterTts.setPitch(1.0); // Natural pitch
    
    notifyListeners();
  }

  void _updateStatus(String newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  void setContext(BuildContext context) {
    _currentContext = context;
  }

  void switchLanguage(String languageCode) {
    _currentLanguage = languageCode;
    _flutterTts.setLanguage(_currentLanguage);
    notifyListeners();
  }

  // Get localized message based on current language
  String _getLocalizedMessage(String messageKey) {
    // Use current language to provide localized responses
    switch (_currentLanguage) {
      case 'hi-IN':
        return _getHindiMessage(messageKey);
      case 'ta-IN':
        return _getTamilMessage(messageKey);
      case 'te-IN':
        return _getTeluguMessage(messageKey);
      case 'kn-IN':
        return _getKannadaMessage(messageKey);
      case 'ml-IN':
        return _getMalayalamMessage(messageKey);
      case 'mr-IN':
        return _getMarathiMessage(messageKey);
      case 'gu-IN':
        return _getGujaratiMessage(messageKey);
      case 'bn-IN':
        return _getBengaliMessage(messageKey);
      case 'pa-IN':
        return _getPunjabiMessage(messageKey);
      default:
        return _getEnglishMessage(messageKey);
    }
  }

  String _getEnglishMessage(String messageKey) {
    switch (messageKey) {
      case 'dashboard_opened':
        return "Perfect! I'm opening your farm dashboard for you right now.";
      case 'marketplace_opened':
        return "Great choice! Let me take you to the marketplace where you can explore all the latest farming products.";
      case 'crop_suggestions_opened':
        return "Excellent! I'm opening the crop suggestions page to help you make the best farming decisions.";
      case 'plant_registration_opened':
        return "Wonderful! Let me open the plant registration page so you can add your new plants.";
      case 'farm_management_opened':
        return "Sure thing! I'm taking you to farm management where you can organize all your farming activities.";
      case 'analysis_opened':
        return "Great idea! Let me open your plant growth analysis so you can track your crops' progress.";
      case 'ai_tools_opened':
        return "Awesome! I'm opening the AI tools section where you can access smart farming features.";
      case 'community_opened':
        return "Nice! Let me take you to the community page where you can connect with other farmers.";
      case 'page_not_found':
        return "I'm sorry, I'm not quite sure which page you'd like to visit. Could you try saying something like 'dashboard' or 'marketplace'?";
      case 'product_not_found':
        return "I couldn't identify the product you want to order. Please try saying something like 'order tomatoes' or 'buy onions'.";
      case 'product_not_available':
        return "Sorry, that product is not available in any of our registered farms. Please try a different product or contact our farmers directly.";
      case 'order_placed_successfully':
        return "Great! Your order has been placed successfully. I'm opening the cart for you to review and complete the payment.";
      case 'order_failed':
        return "I'm sorry, there was an issue placing your order. Please try again or place the order manually from the marketplace.";
      case 'authentication_required':
        return "Please log in to your account to place orders from your farms.";
      case 'no_user_farms':
        return "You haven't registered any farms yet. Please register your farm first to start selling products.";
      case 'product_not_in_user_farms':
        return "That product is not available in any of your registered farms. You can only order products from your own farms.";
      case 'search_no_results':
        return "I couldn't find that product in any of the registered farms. Try searching for a different product.";
      case 'search_failed':
        return "I'm sorry, there was an issue searching for products. Please try again or browse the marketplace manually.";
      case 'location_failed':
        return "I couldn't get your current location. Please make sure location services are enabled and try again.";
      case 'weather_failed':
        return "I'm sorry, I couldn't get the current weather information. Please try again later or check your internet connection.";
      default:
        return "I heard you, but I'm not sure how to help with that.";
    }
  }

  String _getHindiMessage(String messageKey) {
    switch (messageKey) {
      case 'dashboard_opened':
        return "बेहतरीन! मैं आपका खेत डैशबोर्ड खोल रहा हूं।";
      case 'marketplace_opened':
        return "शानदार चुनाव! मैं आपको बाजार ले चलता हूं जहां आप नवीनतम कृषि उत्पाद देख सकते हैं।";
      case 'crop_suggestions_opened':
        return "उत्कृष्ट! मैं फसल सुझाव पेज खोल रहा हूं।";
      case 'plant_registration_opened':
        return "अद्भुत! मैं पौधा पंजीकरण पेज खोल रहा हूं।";
      case 'farm_management_opened':
        return "ज़रूर! मैं आपको खेत प्रबंधन के लिए ले चल रहा हूं।";
      case 'analysis_opened':
        return "बेहतरीन विचार! मैं पौधे की वृद्धि विश्लेषण खोल रहा हूं।";
      case 'ai_tools_opened':
        return "शानदार! मैं AI टूल्स सेक्शन खोल रहा हूं।";
      case 'community_opened':
        return "बढ़िया! मैं आपको कम्युनिटी पेज पर ले चल रहा हूं।";
      case 'page_not_found':
        return "माफ करें, मुझे यकीन नहीं है कि आप कौन सा पेज देखना चाहते हैं।";
      case 'product_not_found':
        return "मुझे समझ नहीं आया कि आप कौन सा उत्पाद ऑर्डर करना चाहते हैं। कृपया 'टमाटर ऑर्डर करो' या 'प्याज खरीदो' जैसा कहें।";
      case 'product_not_available':
        return "माफ करें, मुझे बाजार में वह उत्पाद नहीं मिला। कृपया कोई दूसरा उत्पाद आज़माएं।";
      case 'order_placed_successfully':
        return "बहुत बढ़िया! आपका ऑर्डर सफलतापूर्वक दे दिया गया है। मैं आपके लिए कार्ट खोल रहा हूं।";
      case 'order_failed':
        return "माफ करें, आपका ऑर्डर देने में कोई समस्या हुई। कृपया दोबारा कोशिश करें।";
      case 'authentication_required':
        return "कृपया अपने खेत से उत्पाद ऑर्डर करने के लिए लॉग इन करें।";
      case 'no_user_farms':
        return "आपने अभी तक कोई खेत पंजीकृत नहीं किया है। उत्पाद बेचना शुरू करने के लिए पहले अपना खेत पंजीकृत करें।";
      case 'product_not_in_user_farms':
        return "यह उत्पाद आपके किसी भी पंजीकृत खेत में उपलब्ध नहीं है। आप केवल अपने खेत से ही उत्पाद ऑर्डर कर सकते हैं।";
      case 'search_no_results':
        return "मुझे किसी भी पंजीकृत खेत में वह उत्पाद नहीं मिला। कोई दूसरा उत्पाद खोजने की कोशिश करें।";
      case 'search_failed':
        return "माफ करें, उत्पाद खोजने में कोई समस्या हुई। कृपया दोबारा कोशिश करें या बाजार में मैन्युअल रूप से देखें।";
      case 'location_failed':
        return "मुझे आपकी वर्तमान स्थिति नहीं मिल पाई। कृपया लोकेशन सेवाएं चालू करके दोबारा कोशिश करें।";
      case 'weather_failed':
        return "माफ करें, मुझे मौसम की जानकारी नहीं मिल पाई। कृपया बाद में कोशिश करें या अपना इंटरनेट कनेक्शन जांचें।";
      default:
        return "मैंने सुना, लेकिन मुझे यकीन नहीं है कि इसमें कैसे मदद करूं।";
    }
  }

  String _getTamilMessage(String messageKey) {
    switch (messageKey) {
      case 'dashboard_opened':
        return "சிறப்பு! உங்கள் விவசாய டாஷ்போர்டை திறக்கிறேன்।";
      case 'marketplace_opened':
        return "அருமையான தேர்வு! சந்தைக்கு அழைத்துச் செல்கிறேன்।";
      case 'crop_suggestions_opened':
        return "சிறப்பு! பயிர் பரிந்துரைகள் பக்கத்தை திறக்கிறேன்।";
      case 'plant_registration_opened':
        return "அருமை! தாவர பதிவு பக்கத்தை திறக்கிறேன்।";
      case 'farm_management_opened':
        return "நிச்சயமாக! விவசாய மேலாண்மைக்கு அழைத்துச் செல்கிறேன்।";
      case 'analysis_opened':
        return "சிறந்த யோசனை! தாவர வளர்ச்சி பகுப்பாய்வை திறக்கிறேன்।";
      case 'ai_tools_opened':
        return "அருமை! AI கருவிகள் பிரிவை திறக்கிறேன்।";
      case 'community_opened':
        return "நல்லது! சமூக பக்கத்திற்கு அழைத்துச் செல்கிறேன்।";
      case 'page_not_found':
        return "மன்னிக்கவும், எந்த பக்கத்தைப் பார்க்க விரும்புகிறீர்கள் என்று எனக்குத் தெரியவில்லை।";
      case 'product_not_found':
        return "நீங்கள் எந்த பொருளை ஆர்டர் செய்ய விரும்புகிறீர்கள் என்று எனக்குப் புரியவில்லை। 'தக்காளி ஆர்டர் செய்' அல்லது 'வெங்காயம் வாங்கு' என்று சொல்லுங்கள்।";
      case 'product_not_available':
        return "மன்னிக்கவும், அந்த பொருள் எங்கள் சந்தையில் கிடைக்கவில்லை। வேறு பொருளை முயற்சிக்கவும்।";
      case 'order_placed_successfully':
        return "அருமை! உங்கள் ஆர்டர் வெற்றிகரமாக செய்யப்பட்டது. நான் உங்களுக்கு கார்ட்டைத் திறக்கிறேன்।";
      case 'order_failed':
        return "மன்னிக்கவும், உங்கள் ஆர்டரில் சிக்கல் ஏற்பட்டது. மீண்டும் முயற்சிக்கவும்।";
      case 'location_failed':
        return "உங்கள் தற்போதைய இருப்பிடத்தைப் பெற முடியவில்லை। தயவுசெய்து இருப்பிட சேவைகளை இயக்கி மீண்டும் முயற்சிக்கவும்।";
      case 'weather_failed':
        return "மன்னிக்கவும், வானிலை தகவலைப் பெற முடியவில்லை। தயவுசெய்து பின்னர் முயற்சிக்கவும் அல்லது உங்கள் இணைய இணைப்பைச் சரிபார்க்கவும்।";
      default:
        return "நான் கேட்டேன், ஆனால் எப்படி உதவுவது என்று தெரியவில்லை।";
    }
  }

  String _getTeluguMessage(String messageKey) {
    switch (messageKey) {
      case 'dashboard_opened':
        return "అద్భుతం! మీ వ్యవసాయ డాష్‌బోర్డ్‌ను తెరుస్తున్నాను।";
      case 'marketplace_opened':
        return "అద్భుతమైన ఎంపిక! మార్కెట్‌కి తీసుకెళుతున్నాను।";
      case 'crop_suggestions_opened':
        return "అద్భుతం! పంట సలహాల పేజీని తెరుస్తున్నాను।";
      case 'plant_registration_opened':
        return "అద్భుతం! మొక్క నమోదు పేజీని తెరుస్తున్నాను।";
      case 'farm_management_opened':
        return "ఖచ్చితంగా! వ్యవసాయ నిర్వహణకు తీసుకెళుతున్నాను।";
      case 'analysis_opened':
        return "గొప్ప ఆలోచన! మొక్క పెరుగుదల విశ్లేషణను తెరుస్తున్నాను।";
      case 'ai_tools_opened':
        return "అద్భుతం! AI టూల్స్ విభాగాన్ని తెరుస్తున్నాను।";
      case 'community_opened':
        return "బాగుంది! కమ్యూనిటీ పేజీకి తీసుకెళుతున్నాను।";
      case 'page_not_found':
        return "క్షమించండి, మీరు ఏ పేజీని చూడాలనుకుంటున్నారో నాకు తెలియదు।";
      case 'product_not_found':
        return "మీరు ఏ వస్తువును ఆర్డర్ చేయాలనుకుంటున్నారో నాకు అర్థం కాలేదు. 'టమాటా ఆర్డర్ చేయండి' లేదా 'ఉల్లిపాయలు కొనండి' అని చెప్పండి।";
      case 'product_not_available':
        return "క్షమించండి, ఆ వస్తువు మా మార్కెట్‌లో దొరకలేదు. వేరే వస్తువును ప్రయత్నించండి।";
      case 'order_placed_successfully':
        return "అద్భుతం! మీ ఆర్డర్ విజయవంతంగా ప్లేస్ చేయబడింది. నేను మీ కోసం కార్ట్ తెరుస్తున్నాను।";
      case 'order_failed':
        return "క్షమించండి, మీ ఆర్డర్‌లో సమస్య వచ్చింది. దయచేసి మళ్లీ ప్రయత్నించండి।";
      case 'location_failed':
        return "మీ ప్రస్తుత స్థానాన్ని పొందలేకపోయాను. దయచేసి లొకేషన్ సేవలను ప్రారంభించి మళ్లీ ప్రయత్నించండి।";
      case 'weather_failed':
        return "క్షమించండి, వాతావరణ సమాచారాన్ని పొందలేకపోయాను. దయచేసి తర్వాత ప్రయత్నించండి లేదా మీ ఇంటర్నెట్ కనెక్షన్‌ను తనిఖీ చేయండి।";
      default:
        return "నేను విన్నాను, కానీ ఎలా సహాయం చేయాలో తెలియదు।";
    }
  }

  String _getKannadaMessage(String messageKey) {
    switch (messageKey) {
      case 'dashboard_opened':
        return "ಅದ್ಭುತ! ನಿಮ್ಮ ಕೃಷಿ ಡ್ಯಾಶ್‌ಬೋರ್ಡ್ ತೆರೆಯುತ್ತಿದ್ದೇನೆ।";
      case 'marketplace_opened':
        return "ಅದ್ಭುತ ಆಯ್ಕೆ! ಮಾರುಕಟ್ಟೆಗೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ।";
      case 'crop_suggestions_opened':
        return "ಅತ್ಯುತ್ತಮ! ಬೆಳೆ ಸಲಹೆಗಳ ಪುಟವನ್ನು ತೆರೆಯುತ್ತಿದ್ದೇನೆ।";
      case 'plant_registration_opened':
        return "ಅದ್ಭುತ! ಸಸ್ಯ ನೋಂದಣಿ ಪುಟವನ್ನು ತೆರೆಯುತ್ತಿದ್ದೇನೆ।";
      case 'farm_management_opened':
        return "ಖಂಡಿತವಾಗಿಯೂ! ಕೃಷಿ ನಿರ್ವಹಣೆಗೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ।";
      case 'analysis_opened':
        return "ಅತ್ಯುತ್ತಮ ಆಲೋಚನೆ! ಸಸ್ಯ ಬೆಳವಣಿಗೆ ವಿಶ್ಲೇಷಣೆಯನ್ನು ತೆರೆಯುತ್ತಿದ್ದೇನೆ।";
      case 'ai_tools_opened':
        return "ಅದ್ಭುತ! AI ಉಪಕರಣಗಳ ವಿಭಾಗವನ್ನು ತೆರೆಯುತ್ತಿದ್ದೇನೆ।";
      case 'community_opened':
        return "ಚೆನ್ನಾಗಿದೆ! ಸಮುದಾಯ ಪುಟಕ್ಕೆ ಕರೆದೊಯ್ಯುತ್ತಿದ್ದೇನೆ।";
      case 'page_not_found':
        return "ಕ್ಷಮಿಸಿ, ನೀವು ಯಾವ ಪುಟವನ್ನು ನೋಡಲು ಬಯಸುತ್ತೀರಿ ಎಂದು ನನಗೆ ತಿಳಿದಿಲ್ಲ।";
      case 'product_not_found':
        return "ನೀವು ಯಾವ ಉತ್ಪಾದನೆಯನ್ನು ಆರ್ಡರ್ ಮಾಡಲು ಬಯಸುತ್ತೀರಿ ಎಂದು ನನಗೆ ಅರ್ಥವಾಗಲಿಲ್ಲ। 'ಟೊಮೇಟೊ ಆರ್ಡರ್ ಮಾಡಿ' ಅಥವಾ 'ಈರುಳ್ಳಿ ಕೊಳ್ಳಿ' ಎಂದು ಹೇಳಿ।";
      case 'product_not_available':
        return "ಕ್ಷಮಿಸಿ, ಆ ಉತ್ಪಾದನೆ ನಮ್ಮ ಮಾರುಕಟ್ಟೆಯಲ್ಲಿ ಸಿಗಲಿಲ್ಲ। ಬೇರೆ ಉತ್ಪಾದನೆಯನ್ನು ಪ್ರಯತ್ನಿಸಿ।";
      case 'order_placed_successfully':
        return "ಅದ್ಭುತ! ನಿಮ್ಮ ಆರ್ಡರ್ ಯಶಸ್ವಿಯಾಗಿ ಇರಿಸಲಾಗಿದೆ। ನಾನು ನಿಮಗೆ ಕಾರ್ಟ್ ತೆರೆಯುತ್ತಿದ್ದೇನೆ।";
      case 'order_failed':
        return "ಕ್ಷಮಿಸಿ, ನಿಮ್ಮ ಆರ್ಡರ್‌ನಲ್ಲಿ ಸಮಸ್ಯೆ ಇದೆ। ದಯವಿಟ್ಟು ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ।";
      case 'location_failed':
        return "ನಿಮ್ಮ ಪ್ರಸ್ತುತ ಸ್ಥಳವನ್ನು ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ। ದಯವಿಟ್ಟು ಸ್ಥಳ ಸೇವೆಗಳನ್ನು ಸಕ್ರಿಯಗೊಳಿಸಿ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ।";
      case 'weather_failed':
        return "ಕ್ಷಮಿಸಿ, ಹವಾಮಾನ ಮಾಹಿತಿಯನ್ನು ಪಡೆಯಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ। ದಯವಿಟ್ಟು ನಂತರ ಪ್ರಯತ್ನಿಸಿ ಅಥವಾ ನಿಮ್ಮ ಇಂಟರ್ನೆಟ್ ಸಂಪರ್ಕವನ್ನು ಪರಿಶೀಲಿಸಿ।";
      default:
        return "ನಾನು ಕೇಳಿದೆ, ಆದರೆ ಹೇಗೆ ಸಹಾಯ ಮಾಡಬೇಕೆಂದು ತಿಳಿದಿಲ್ಲ।";
    }
  }

  String _getMalayalamMessage(String messageKey) {
    switch (messageKey) {
      case 'dashboard_opened':
        return "മികച്ചത്! നിങ്ങളുടെ കൃഷി ഡാഷ്‌ബോർഡ് തുറക്കുന്നു।";
      case 'marketplace_opened':
        return "മികച്ച തെരഞ്ഞെടുപ്പ്! മാർക്കറ്റിലേക്ക് കൊണ്ടുപോകുന്നു।";
      case 'crop_suggestions_opened':
        return "മികച്ചത്! വിള നിർദ്ദേശങ്ങളുടെ പേജ് തുറക്കുന്നു।";
      case 'plant_registration_opened':
        return "അതിശയം! ചെടി രജിസ്ട്രേഷൻ പേജ് തുറക്കുന്നു।";
      case 'farm_management_opened':
        return "തീർച്ചയായും! കൃഷി മാനേജ്‌മെന്റിലേക്ക് കൊണ്ടുപോകുന്നു।";
      case 'analysis_opened':
        return "മികച്ച ആശയം! ചെടിയുടെ വളർച്ചാ വിശകലനം തുറക്കുന്നു।";
      case 'ai_tools_opened':
        return "അതിശയം! AI ടൂൾസ് വിഭാഗം തുറക്കുന്നു।";
      case 'community_opened':
        return "നല്ലത്! കമ്മ്യൂണിറ്റി പേജിലേക്ക് കൊണ്ടുപോകുന്നു।";
      case 'page_not_found':
        return "ക്ഷമിക്കണം, നിങ്ങൾ ഏത് പേജ് കാണാൻ ആഗ്രഹിക്കുന്നുവെന്ന് എനിക്കറിയില്ല।";
      case 'product_not_found':
        return "നിങ്ങൾ ഏത് ഉൽപ്പാദനം ഓർഡർ ചെയ്യാൻ ആഗ്രഹിക്കുന്നുവെന്ന് എനിക്ക് മനസ്സിലായില്ല। 'തക്കാളി ഓർഡർ ചെയ്യുക' അല്ലെങ്കിൽ 'ഉള്ളി വാങ്ങുക' എന്ന് പറയുക।";
      case 'product_not_available':
        return "ക്ഷമിക്കണം, ആ ഉൽപ്പാദനം ഞങ്ങളുടെ മാർക്കറ്റിൽ കണ്ടെത്താനായില്ല। മറ്റൊരു ഉൽപ്പാദനം പരീക്ഷിക്കുക।";
      case 'order_placed_successfully':
        return "അതിശയം! നിങ്ങളുടെ ഓർഡർ വിജയകരമായി നൽകി. ഞാൻ നിങ്ങൾക്കായി കാർട്ട് തുറക്കുന്നു।";
      case 'order_failed':
        return "ക്ഷമിക്കണം, നിങ്ങളുടെ ഓർഡറിൽ പ്രശ്നമുണ്ട്. ദയവായി വീണ്ടും ശ്രമിക്കുക।";
      case 'location_failed':
        return "നിങ്ങളുടെ നിലവിലെ സ്ഥാനം കണ്ടെത്താനായില്ല। ദയവായി ലൊക്കേഷൻ സേവനങ്ങൾ പ്രാപ്തമാക്കി വീണ്ടും ശ്രമിക്കുക।";
      case 'weather_failed':
        return "ക്ഷമിക്കണം, കാലാവസ്ഥാ വിവരങ്ങൾ ലഭിക്കാനായില്ല। ദയവായി പിന്നീട് ശ്രമിക്കുക അല്ലെങ്കിൽ നിങ്ങളുടെ ഇന്റർനെറ്റ് കണക്ഷൻ പരിശോധിക്കുക।";
      default:
        return "ഞാൻ കേട്ടു, പക്ഷേ എങ്ങനെ സഹായിക്കാമെന്ന് അറിയില്ല।";
    }
  }

  String _getMarathiMessage(String messageKey) {
    switch (messageKey) {
      case 'dashboard_opened':
        return "अप्रतिम! मी तुमचा शेती डॅशबोर्ड उघडत आहे।";
      case 'marketplace_opened':
        return "उत्कृष्ट निवड! मी तुम्हाला बाजारपेठेत घेऊन जात आहे।";
      case 'crop_suggestions_opened':
        return "उत्कृष्ट! मी पीक सुचवणारे पान उघडत आहे।";
      case 'plant_registration_opened':
        return "अप्रतिम! मी वनस्पती नोंदणी पान उघडत आहे।";
      case 'farm_management_opened':
        return "नक्कीच! मी तुम्हाला शेत व्यवस्थापनाकडे घेऊन जात आहे।";
      case 'analysis_opened':
        return "उत्कृष्ट कल्पना! मी वनस्पती वाढीचे विश्लेषण उघडत आहे।";
      case 'ai_tools_opened':
        return "अप्रतिम! मी AI साधने विभाग उघडत आहे।";
      case 'community_opened':
        return "चांगले! मी तुम्हाला समुदाय पानाकडे घेऊन जात आहे।";
      case 'page_not_found':
        return "माफ करा, तुम्हाला कोणते पान बघायचे आहे ते मला समजले नाही।";
      case 'product_not_found':
        return "तुम्हाला कोणते उत्पादन ऑर्डर करायचे आहे ते मला समजले नाही। 'टोमॅटो ऑर्डर करा' किंवा 'कांदे विकत घ्या' असे म्हणा।";
      case 'product_not_available':
        return "माफ करा, ते उत्पादन आमच्या बाजारपेठेत मिळत नाही। दुसरे उत्पादन वापरून पहा।";
      case 'order_placed_successfully':
        return "अप्रतिम! तुमची ऑर्डर यशस्वीरित्या दिली गेली. मी तुमच्यासाठी कार्ट उघडत आहे।";
      case 'order_failed':
        return "माफ करा, तुमच्या ऑर्डरमध्ये समस्या आली. कृपया पुन्हा प्रयत्न करा।";
      case 'location_failed':
        return "तुमचे सध्याचे स्थान मिळवता आले नाही। कृपया स्थान सेवा सुरू करून पुन्हा प्रयत्न करा।";
      case 'weather_failed':
        return "माफ करा, हवामान माहिती मिळवता आली नाही। कृपया नंतर प्रयत्न करा किंवा तुमचे इंटरनेट कनेक्शन तपासा।";
      default:
        return "मी ऐकले, पण कशी मदत करावी हे समजत नाही।";
    }
  }

  String _getGujaratiMessage(String messageKey) {
    switch (messageKey) {
      case 'dashboard_opened':
        return "ઉત્કૃષ્ટ! હું તમારું ખેતી ડેશબોર્ડ ખોલી રહ્યો છું।";
      case 'marketplace_opened':
        return "સરસ પસંદગી! હું તમને બજારમાં લઈ જઈ રહ્યો છું।";
      case 'crop_suggestions_opened':
        return "ઉત્કૃષ્ટ! હું પાક સૂચનાઓનું પૃષ્ઠ ખોલી રહ્યો છું।";
      case 'plant_registration_opened':
        return "અદ્ભુત! હું છોડ નોંધણી પૃષ્ઠ ખોલી રહ્યો છું।";
      case 'farm_management_opened':
        return "ચોક્કસ! હું તમને ખેત વ્યવસ્થાપન પર લઈ જઈ રહ્યો છું।";
      case 'analysis_opened':
        return "સરસ વિચાર! હું છોડના વિકાસનું વિશ્લેષણ ખોલી રહ્યો છું।";
      case 'ai_tools_opened':
        return "અદ્ભુત! હું AI ટૂલ્સ વિભાગ ખોલી રહ્યો છું।";
      case 'community_opened':
        return "સરસ! હું તમને સમુદાય પૃષ્ઠ પર લઈ જઈ રહ્યો છું।";
      case 'page_not_found':
        return "માફ કરશો, તમે કયું પૃષ્ઠ જોવા માંગો છો તે મને ખબર નથી।";
      case 'product_not_found':
        return "તમે કયું ઉત્પાદન ઓર્ડર કરવા માંગો છો તે મને સમજાયું નથી। 'ટમેટાં ઓર્ડર કરો' અથવા 'ડુંગળી ખરીદો' એમ કહો।";
      case 'product_not_available':
        return "માફ કરશો, તે ઉત્પાદન અમારા બજારમાં મળતું નથી। બીજું ઉત્પાદન અજમાવો।";
      case 'order_placed_successfully':
        return "અદ્ભુત! તમારો ઓર્ડર સફળતાપૂર્વક આપવામાં આવ્યો. હું તમારા માટે કાર્ટ ખોલી રહ્યો છું।";
      case 'order_failed':
        return "માફ કરશો, તમારા ઓર્ડરમાં સમસ્યા આવી. કૃપા કરીને ફરીથી પ્રયાસ કરો।";
      case 'location_failed':
        return "તમારું વર્તમાન સ્થાન મેળવી શક્યું નથી. કૃપા કરીને લોકેશન સેવાઓ સક્રિય કરીને ફરીથી પ્રયાસ કરો।";
      case 'weather_failed':
        return "માફ કરશો, હવામાન માહિતી મેળવી શક્યું નથી. કૃપા કરીને પછીથી પ્રયાસ કરો અથવા તમારું ઇન્ટરનેટ કનેક્શન તપાસો।";
      default:
        return "મેં સાંભળ્યું, પણ કેવી રીતે મદદ કરવી તે ખબર નથી।";
    }
  }

  String _getBengaliMessage(String messageKey) {
    switch (messageKey) {
      case 'dashboard_opened':
        return "দুর্দান্ত! আমি আপনার কৃষি ড্যাশবোর্ড খুলছি।";
      case 'marketplace_opened':
        return "দুর্দান্ত পছন্দ! আমি আপনাকে বাজারে নিয়ে যাচ্ছি।";
      case 'crop_suggestions_opened':
        return "দুর্দান্ত! আমি ফসলের পরামর্শ পৃষ্ঠা খুলছি।";
      case 'plant_registration_opened':
        return "আশ্চর্যজনক! আমি উদ্ভিদ নিবন্ধন পৃষ্ঠা খুলছি।";
      case 'farm_management_opened':
        return "অবশ্যই! আমি আপনাকে খামার ব্যবস্থাপনায় নিয়ে যাচ্ছি।";
      case 'analysis_opened':
        return "দুর্দান্ত ভাবনা! আমি উদ্ভিদ বৃদ্ধির বিশ্লেষণ খুলছি।";
      case 'ai_tools_opened':
        return "আশ্চর্যজনক! আমি AI টুলস বিভাগ খুলছি।";
      case 'community_opened':
        return "ভালো! আমি আপনাকে কমিউনিটি পৃষ্ঠায় নিয়ে যাচ্ছি।";
      case 'page_not_found':
        return "দুঃখিত, আপনি কোন পৃষ্ঠা দেখতে চান তা আমি জানি না।";
      case 'product_not_found':
        return "আপনি কোন পণ্য অর্ডার করতে চান তা আমি বুঝতে পারলাম না। 'টমেটো অর্ডার করুন' বা 'পেঁয়াজ কিনুন' বলুন।";
      case 'product_not_available':
        return "দুঃখিত, সেই পণ্যটি আমাদের বাজারে পাওয়া যায়নি। অন্য পণ্য চেষ্টা করুন।";
      case 'order_placed_successfully':
        return "দুর্দান্ত! আপনার অর্ডার সফলভাবে দেওয়া হয়েছে। আমি আপনার জন্য কার্ট খুলছি।";
      case 'order_failed':
        return "দুঃখিত, আপনার অর্ডারে সমস্যা হয়েছে। দয়া করে আবার চেষ্টা করুন।";
      case 'location_failed':
        return "আপনার বর্তমান অবস্থান পেতে পারলাম না। দয়া করে অবস্থান সেবা চালু করে আবার চেষ্টা করুন।";
      case 'weather_failed':
        return "দুঃখিত, আবহাওয়ার তথ্য পেতে পারলাম না। দয়া করে পরে চেষ্টা করুন বা আপনার ইন্টারনেট সংযোগ পরীক্ষা করুন।";
      default:
        return "আমি শুনেছি, কিন্তু কীভাবে সাহায্য করব জানি না।";
    }
  }

  String _getPunjabiMessage(String messageKey) {
    switch (messageKey) {
      case 'dashboard_opened':
        return "ਸ਼ਾਨਦਾਰ! ਮੈਂ ਤੁਹਾਡਾ ਖੇਤੀ ਡੈਸ਼ਬੋਰਡ ਖੋਲ੍ਹ ਰਿਹਾ ਹਾਂ।";
      case 'marketplace_opened':
        return "ਸ਼ਾਨਦਾਰ ਚੋਣ! ਮੈਂ ਤੁਹਾਨੂੰ ਬਾਜ਼ਾਰ ਵਿੱਚ ਲੈ ਜਾ ਰਿਹਾ ਹਾਂ।";
      case 'crop_suggestions_opened':
        return "ਸ਼ਾਨਦਾਰ! ਮੈਂ ਫਸਲ ਸੁਝਾਅ ਪੰਨਾ ਖੋਲ੍ਹ ਰਿਹਾ ਹਾਂ।";
      case 'plant_registration_opened':
        return "ਬਹੁਤ ਵਧੀਆ! ਮੈਂ ਪੌਧਾ ਰਜਿਸਟਰੇਸ਼ਨ ਪੰਨਾ ਖੋਲ੍ਹ ਰਿਹਾ ਹਾਂ।";
      case 'farm_management_opened':
        return "ਜ਼ਰੂਰ! ਮੈਂ ਤੁਹਾਨੂੰ ਖੇਤ ਪ੍ਰਬੰਧਨ ਵਿੱਚ ਲੈ ਜਾ ਰਿਹਾ ਹਾਂ।";
      case 'analysis_opened':
        return "ਸ਼ਾਨਦਾਰ ਵਿਚਾਰ! ਮੈਂ ਪੌਧੇ ਦੇ ਵਿਕਾਸ ਦਾ ਵਿਸ਼ਲੇਸ਼ਣ ਖੋਲ੍ਹ ਰਿਹਾ ਹਾਂ।";
      case 'ai_tools_opened':
        return "ਸ਼ਾਨਦਾਰ! ਮੈਂ AI ਟੂਲ ਸੈਕਸ਼ਨ ਖੋਲ੍ਹ ਰਿਹਾ ਹਾਂ।";
      case 'community_opened':
        return "ਚੰਗਾ! ਮੈਂ ਤੁਹਾਨੂੰ ਕਮਿਊਨਿਟੀ ਪੰਨੇ ਤੇ ਲੈ ਜਾ ਰਿਹਾ ਹਾਂ।";
      case 'page_not_found':
        return "ਮਾਫ ਕਰੋ, ਮੈਨੂੰ ਨਹੀਂ ਪਤਾ ਕਿ ਤੁਸੀਂ ਕਿਹੜਾ ਪੰਨਾ ਦੇਖਣਾ ਚਾਹੁੰਦੇ ਹੋ।";
      case 'product_not_found':
        return "ਮੈਨੂੰ ਸਮਝ ਨਹੀਂ ਆਈ ਕਿ ਤੁਸੀਂ ਕਿਹੜਾ ਉਤਪਾਦ ਆਰਡਰ ਕਰਨਾ ਚਾਹੁੰਦੇ ਹੋ। 'ਟਮਾਟਰ ਆਰਡਰ ਕਰੋ' ਜਾਂ 'ਪਿਆਜ਼ ਖਰੀਦੋ' ਕਹੋ।";
      case 'product_not_available':
        return "ਮਾਫ ਕਰੋ, ਉਹ ਉਤਪਾਦ ਸਾਡੇ ਬਾਜ਼ਾਰ ਵਿੱਚ ਉਪਲਬਧ ਨਹੀਂ ਹੈ। ਕੋਈ ਹੋਰ ਉਤਪਾਦ ਅਜ਼ਮਾਓ।";
      case 'order_placed_successfully':
        return "ਸ਼ਾਨਦਾਰ! ਤੁਹਾਡਾ ਆਰਡਰ ਸਫਲਤਾਪੂਰਵਕ ਦਿੱਤਾ ਗਿਆ ਹੈ। ਮੈਂ ਤੁਹਾਡੇ ਲਈ ਕਾਰਟ ਖੋਲ੍ਹ ਰਿਹਾ ਹਾਂ।";
      case 'order_failed':
        return "ਮਾਫ ਕਰੋ, ਤੁਹਾਡੇ ਆਰਡਰ ਵਿੱਚ ਸਮੱਸਿਆ ਆਈ ਹੈ। ਕਿਰਪਾ ਕਰਕੇ ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ।";
      case 'location_failed':
        return "ਮੈਂ ਤੁਹਾਡੀ ਮੌਜੂਦਾ ਸਥਿਤੀ ਨਹੀਂ ਲੱਭ ਸਕਿਆ। ਕਿਰਪਾ ਕਰਕੇ ਸਥਾਨ ਸੇਵਾਵਾਂ ਸਕਿਰਿਆ ਕਰਕੇ ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰੋ।";
      case 'weather_failed':
        return "ਮਾਫ ਕਰੋ, ਮੈਂ ਮੌਸਮ ਦੀ ਜਾਣਕਾਰੀ ਨਹੀਂ ਲੱਭ ਸਕਿਆ। ਕਿਰਪਾ ਕਰਕੇ ਬਾਅਦ ਵਿੱਚ ਕੋਸ਼ਿਸ਼ ਕਰੋ ਜਾਂ ਆਪਣੇ ਇੰਟਰਨੈਟ ਕਨੈਕਸ਼ਨ ਦੀ ਜਾਂਚ ਕਰੋ।";
      default:
        return "ਮੈਂ ਸੁਣਿਆ, ਪਰ ਨਹੀਂ ਪਤਾ ਕਿਵੇਂ ਮਦਦ ਕਰਨੀ।";
    }
  }

  void startListening() {
    if (!_speechToText.isAvailable || _isListening) return;
    _lastWords = '';
    _isListening = true;
    _updateStatus("Listening...");
    notifyListeners();
    _speechToText.listen(
      onResult: (result) {
        _lastWords = result.recognizedWords;
        notifyListeners();
        if (result.finalResult) {
          stopListening();
        }
      },
      listenFor: const Duration(seconds: 10),
      localeId: _currentLanguage, // Use current language for speech recognition
    );
  }

  void stopListening() {
    _isListening = false;
    notifyListeners();
    _speechToText.stop();
    _updateStatus("Processing...");
    if (_lastWords.isNotEmpty) {
      _processCommand(_lastWords);
    } else {
      _updateStatus("Idle");
    }
  }

  Future<void> _processCommand(String command) async {
    print("Processing command: $command in language: $_currentLanguage");
    
    try {
      // Get current language for prompt generation
      String languageForPrompt = _getLanguageNameForPrompt(_currentLanguage);
      
      final prompt = '''You are an advanced multilingual assistant for TeraFarm, a comprehensive farming application that supports all Indian languages. Your role is to understand voice commands in any language and provide precise JSON responses for app actions.

🌾 APP CONTEXT:
- Users can only order products from their own registered farms (where they are the seller)
- Users can search for products across all listed farms for viewing/browsing
- Multi-language support for all major Indian languages
- Smart voice command interpretation with context awareness

📋 AVAILABLE COMMANDS:

1. NAVIGATION COMMANDS:
{"command": "navigate", "value": "page_name"}
Pages: dashboard, marketplace, crop_suggestions, plant_registration, farm_management, analysis, ai_tools, community

2. PRODUCT ORDERING (ONLY FROM USER'S OWN FARMS):
{"command": "order", "value": {"product": "product_name", "farmName": "", "quantity": "number", "unit": "kg|pieces|litres"}}

3. PRODUCT SEARCH (ALL FARMS FOR BROWSING):
{"command": "search", "value": {"product": "product_name", "searchType": "all_farms"}}

4. WEATHER & ENVIRONMENT:
{"command": "query", "value": "weather"}

5. FARMING ADVICE:
{"command": "advice", "value": "farming tips"}

🗣️ MULTILINGUAL EXAMPLES:

NAVIGATION:
- English: "go to dashboard", "open marketplace", "show crop suggestions"
- Hindi: "डैशबोर्ड पर जाओ", "बाजार खोलो", "फसल सुझाव दिखाओ"
- Tamil: "டாஷ்போர்டுக்கு செல்", "சந்தையை திற", "பயிர் ஆலோசனை காட்டு"
- Telugu: "డాష్‌బోర్డ్‌కి వెళ్లండి", "మార్కెట్‌ప్లేస్ తెరవండి", "పంట సలహాలు చూపించండి"

ORDERING (FROM USER FARMS):
- English: "order 2 kg tomatoes", "buy onions from my farm"
- Hindi: "2 किलो टमाटर ऑर्डर करो", "मेरे खेत से प्याज खरीदो"
- Tamil: "2 கிலோ தக்காளி ஆர்டர் செய்", "என் பண்ணையிலிருந்து வெங்காயம் வாங்கு"
- Telugu: "2 కిలో టమాటాలు ఆర్డర్ చేయండి", "నా పొలం నుండి ఉల్లిపాయలు కొనండి"

WEATHER:
- English: "check weather", "tell me today's weather"
- Hindi: "मौसम बताओ", "आज का मौसम कैसा है"
- Tamil: "வானிலை சொல்லு", "இன்றைய வானிலை எப்படி"
- Telugu: "వాతావరణం చెప్పండి", "ఈరోజు వాతావరణం ఎలా ఉంది"

🎯 USER COMMAND: "$command"
CURRENT USER LANGUAGE: $languageForPrompt

INSTRUCTIONS:
- Detect language automatically from the input
- Understand intent even with pronunciation variations and colloquialisms
- For ordering: Extract product, quantity, unit - remember this is only from user's own farms
- For searching: Use "searchType": "all_farms" for browsing products across all farms
- For navigation: Map to exact page names provided
- Provide ONLY valid JSON response, no additional text
- Handle typos, slang, and regional variations intelligently
- If command is unclear, default to the most likely interpretation based on context''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final actionText = response.text?.trim();
      
      if (actionText != null && actionText.isNotEmpty) {
        print("Gemini response: $actionText");
        
        // Try to extract JSON from the response
        String cleanedResponse = _extractJsonFromResponse(actionText);
        if (cleanedResponse.isNotEmpty) {
          _executeAction(cleanedResponse);
        } else {
          print("No valid JSON found in response, using fallback");
          _fallbackToLocalProcessing(command);
        }
      } else {
        _fallbackToLocalProcessing(command);
      }
    } catch (e) {
      print("Gemini error: $e");
      _fallbackToLocalProcessing(command);
    }
  }

  String _extractJsonFromResponse(String response) {
    // Try to find JSON object in the response
    int startIndex = response.indexOf('{');
    int endIndex = response.lastIndexOf('}');
    
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      String jsonString = response.substring(startIndex, endIndex + 1);
      
      // Validate that it's proper JSON
      try {
        jsonDecode(jsonString);
        return jsonString;
      } catch (e) {
        print("Invalid JSON extracted: $jsonString");
        return '';
      }
    }
    
    return '';
  }

  void _fallbackToLocalProcessing(String command) {
    String lowerCommand = command.toLowerCase();
    print("Using fallback processing for: $command");
    
    // Enhanced multilingual keyword detection
    if (_containsAnyKeyword(lowerCommand, ['dashboard', 'डैशबोर्ड', 'டாஷ்போர்ட்', 'డాష్‌బోర్డ్', 'ಡ್ಯಾಶ್‌ಬೋರ್ಡ್', 'ഡാഷ്‌ബോർഡ്', 'farm', 'खेत', 'வேலைப்பாடு', 'వ్యవసాయం', 'ಕೃಷಿ', 'കൃഷി'])) {
      _executeAction('{"command": "navigate", "value": "dashboard"}');
    } else if (_containsAnyKeyword(lowerCommand, ['market', 'marketplace', 'बाजार', 'சந்தை', 'మార్కెట్', 'ಮಾರುಕಟ್ಟೆ', 'വിപണി'])) {
      _executeAction('{"command": "navigate", "value": "marketplace"}');
    } else if (_containsAnyKeyword(lowerCommand, ['crop', 'suggestion', 'फसल', 'सुझाव', 'பயிர்', 'సలహా', 'ಬೆಳೆ', 'വിള', 'सल्ला'])) {
      _executeAction('{"command": "navigate", "value": "crop_suggestions"}');
    } else if (_containsAnyKeyword(lowerCommand, ['plant', 'register', 'पौधा', 'रजिस्टर', 'தாவரம', 'నమోదు', 'ಸಸ್ಯ', 'ചെടി', 'रोपण'])) {
      _executeAction('{"command": "navigate", "value": "plant_registration"}');
    } else if (_containsAnyKeyword(lowerCommand, ['analysis', 'task', 'विश्लेषण', 'कार्य', 'பகுப்பாய்வு', 'విశ్లేషణ', 'ವಿಶ್ಲೇಷಣೆ', 'വിശകലനം'])) {
      _executeAction('{"command": "navigate", "value": "analysis"}');
    } else if (_containsAnyKeyword(lowerCommand, ['ai', 'tools', 'एआई', 'उपकरण', 'செயற்கை', 'కృత్రిమ', 'ಕೃತ್ರಿಮ', 'കൃത്രിമ'])) {
      _executeAction('{"command": "navigate", "value": "ai_tools"}');
    } else if (_containsAnyKeyword(lowerCommand, ['community', 'समुदाय', 'சமூகம்', 'సమాజం', 'ಸಮುದಾಯ', 'സമൂഹം'])) {
      _executeAction('{"command": "navigate", "value": "community"}');
    } else if (_containsAnyKeyword(lowerCommand, ['order', 'buy', 'purchase', 'मंगवाओ', 'खरीदो', 'ऑर्डर', 'ஆர்டர்', 'வாங்கு', 'కొనండి', 'ఆర్డర్', 'ಕೊಳ್ಳಿ', 'ಆರ್ಡರ್', 'വാങ്ങുക', 'ഓർഡർ'])) {
      // Try to extract product name from the command for simple ordering
      _handleSimpleOrderCommand(command);
    } else if (_containsAnyKeyword(lowerCommand, ['weather', 'मौसम', 'வானிலை', 'వాతావరణం', 'ಹವಾಮಾನ', 'കാലാവസ്ഥ', 'हवामान', 'હવામાન', 'আবহাওয়া', 'ਮੌਸਮ', 'temperature', 'तापमान', 'வெப்பநிலை', 'ఉష్ణోగ్రత', 'ತಾಪಮಾನ', 'താപനില', 'rain', 'बारिश', 'மழை', 'వర్షం', 'ಮಳೆ', 'മഴ'])) {
      _executeAction('{"command": "query", "value": "weather"}');
    } else {
      // Respond in user's language if possible
      String responseText = _getMultilingualResponse(command);
      _speak(responseText);
    }
  }

  bool _containsAnyKeyword(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  String _getMultilingualResponse(String command) {
    // Detect language and respond appropriately
    if (_containsHindi(command)) {
      return "मैंने सुना: '$command'। आप कह सकते हैं 'डैशबोर्ड पर जाओ', 'बाजार दिखाओ', 'टमाटर ऑर्डर करो', या 'पौधा रजिस्टर करो'।";
    } else if (_containsTamil(command)) {
      return "நான் கேட்டேன்: '$command'। நீங்கள் 'டாஷ்போர்டுக்கு செல்', 'சந்தையைக் காட்டு', 'தக்காளி ஆர்டர் செய்', அல்லது 'தாவரத்தை பதிவு செய்' என்று சொல்லலாம்।";
    } else if (_containsTelugu(command)) {
      return "నేను విన్నాను: '$command'। మీరు 'డాష్‌బోర్డ్‌కి వెళ్లండి', 'మార్కెట్ చూపించండి', 'టమాటా ఆర్డర్ చేయండి', లేదా 'మొక్కను నమోదు చేయండి' అని చెప్పవచ్చు।";
    } else if (_containsKannada(command)) {
      return "ನಾನು ಕೇಳಿದೆ: '$command'। ನೀವು 'ಡ್ಯಾಶ್‌ಬೋರ್ಡ್‌ಗೆ ಹೋಗಿ', 'ಮಾರುಕಟ್ಟೆ ತೋರಿಸಿ', 'ಟೊಮೇಟೊ ಆರ್ಡರ್ ಮಾಡಿ', ಅಥವಾ 'ಸಸ್ಯವನ್ನು ನೋಂದಾಯಿಸಿ' ಎಂದು ಹೇಳಬಹುದು।";
    } else if (_containsMalayalam(command)) {
      return "ഞാൻ കേട്ടു: '$command'। നിങ്ങൾക്ക് 'ഡാഷ്‌ബോർഡിലേക്ക് പോകുക', 'മാർക്കറ്റ് കാണിക്കുക', 'തക്കാളി ഓർഡർ ചെയ്യുക', അല്ലെങ്കിൽ 'ചെടി രജിസ്റ്റർ ചെയ്യുക' എന്ന് പറയാം।";
    } else {
      return "I heard you say '$command'. You can try commands like 'take me to the dashboard', 'show me the marketplace', 'order tomatoes', or 'I want to register a new plant'.";
    }
  }

  bool _containsHindi(String text) {
    return RegExp(r'[\u0900-\u097F]').hasMatch(text);
  }

  bool _containsTamil(String text) {
    return RegExp(r'[\u0B80-\u0BFF]').hasMatch(text);
  }

  bool _containsTelugu(String text) {
    return RegExp(r'[\u0C00-\u0C7F]').hasMatch(text);
  }

  bool _containsKannada(String text) {
    return RegExp(r'[\u0C80-\u0CFF]').hasMatch(text);
  }

  bool _containsMalayalam(String text) {
    return RegExp(r'[\u0D00-\u0D7F]').hasMatch(text);
  }

  String _getLanguageNameForPrompt(String languageCode) {
    switch (languageCode) {
      case 'hi-IN':
        return 'Hindi (हिन्दी)';
      case 'ta-IN':
        return 'Tamil (தமிழ்)';
      case 'te-IN':
        return 'Telugu (తెలుగు)';
      case 'kn-IN':
        return 'Kannada (ಕನ್ನಡ)';
      case 'ml-IN':
        return 'Malayalam (മലയാളം)';
      case 'mr-IN':
        return 'Marathi (मराठी)';
      case 'gu-IN':
        return 'Gujarati (ગુજરાતી)';
      case 'bn-IN':
        return 'Bengali (বাংলা)';
      case 'pa-IN':
        return 'Punjabi (ਪੰਜਾਬੀ)';
      default:
        return 'English';
    }
  }

  // Handle simple order commands from voice
  void _handleSimpleOrderCommand(String command) {
    String lowerCommand = command.toLowerCase();
    print("🎤 Processing simple order command: '$command'");
    
    // Common product keywords in multiple languages
    Map<String, List<String>> productKeywords = {
      'tomato': ['tomato', 'टमाटर', 'தக்காளி', 'టమాటా', 'ಟೊಮೇಟೊ', 'തക്കാളി'],
      'onion': ['onion', 'प्याज', 'வெங்காயம்', 'ఉల్లిపాయ', 'ಈರುಳ್ಳಿ', 'ഉള്ളി'],
      'potato': ['potato', 'आलू', 'உருளைக்கிழங்கு', 'బంగాళదుంప', 'ಆಲೂಗೆಡ್ಡೆ', 'ഉരുളക്കിഴങ്ങ്'],
      'rice': ['rice', 'चावल', 'அரிசி', 'అన్నం', 'ಅಕ್ಕಿ', 'അരി'],
      'wheat': ['wheat', 'गेहूं', 'கோதுமை', 'గోధుమ', 'ಗೋಧಿ', 'ഗോതമ്പ്'],
    };
    
    String? detectedProduct;
    for (var entry in productKeywords.entries) {
      if (_containsAnyKeyword(lowerCommand, entry.value)) {
        detectedProduct = entry.key;
        print("✅ Detected product: $detectedProduct");
        break;
      }
    }
    
    if (detectedProduct != null) {
      // Create a simple order JSON
      String orderJson = '{"command": "order", "value": {"product": "$detectedProduct", "farmName": "", "quantity": "1", "unit": "kg"}}';
      print("📦 Creating order JSON: $orderJson");
      _executeAction(orderJson);
    } else {
      print("❌ No product detected in command: '$command'");
      _speak(_getLocalizedMessage('product_not_found'));
    }
  }

  // Handle order commands from AI or voice - ONLY FROM USER'S OWN FARMS
  Future<void> _handleOrderCommand(Map<String, dynamic> orderData) async {
    try {
      String productName = orderData['product'] ?? '';
      String farmName = orderData['farmName'] ?? '';
      String quantity = orderData['quantity'] ?? '1';
      String unit = orderData['unit'] ?? 'kg';
      
      print("🛒 Processing order: $productName, $quantity $unit from user's farm");
      _updateStatus("Searching in your registered farms...");
      
      // Get current user ID
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        print("❌ User not authenticated");
        _speak(_getLocalizedMessage('authentication_required'));
        _updateStatus("Idle");
        return;
      }
      
      // Search for products ONLY in user's own farms (where sellerId = currentUserId)
      QuerySnapshot userFarmsQuery = await FirebaseFirestore.instance
          .collection('farms')
          .where('sellerId', isEqualTo: currentUserId)
          .get();
      
      Map<String, dynamic>? foundProduct;
      String? farmId;
      String? sellerId;
      String? actualFarmName;
      
      print("🏪 Searching through ${userFarmsQuery.docs.length} of your registered farms...");
      
      if (userFarmsQuery.docs.isEmpty) {
        print("❌ No farms registered for current user");
        _speak(_getLocalizedMessage('no_user_farms'));
        _updateStatus("Idle");
        return;
      }
      
      // Search through user's farms for the product
      for (var farmDoc in userFarmsQuery.docs) {
        var farmData = farmDoc.data() as Map<String, dynamic>;
        actualFarmName = farmData['farmName'] ?? 'Unnamed Farm';
        sellerId = farmData['sellerId'] ?? currentUserId;
        
        // If specific farm name is mentioned, only search in that farm
        if (farmName.isNotEmpty && 
            !(actualFarmName?.toLowerCase().contains(farmName.toLowerCase()) ?? false)) {
          continue;
        }
        
        List products = farmData['products'] as List? ?? [];
        print("🔍 Checking your farm: $actualFarmName with ${products.length} products");
        
        // Search through products in this farm
        for (var product in products) {
          if (product is Map<String, dynamic>) {
            String cropName = (product['cropName'] ?? '').toString().toLowerCase();
            
            // Check if the product name matches (exact or contains)
            if (cropName == productName.toLowerCase() || 
                cropName.contains(productName.toLowerCase()) ||
                productName.toLowerCase().contains(cropName)) {
              
              foundProduct = {
                'name': product['cropName'] ?? productName,
                'price': int.tryParse(product['pricePerKg']?.toString() ?? '50') ?? 50,
                'image': 'assets/${cropName.replaceAll(' ', '_')}.png',
                'sellerId': sellerId,
                'farmName': actualFarmName,
                'stock': int.tryParse(product['stock in kgs']?.toString() ?? '100') ?? 100,
                'unit': unit,
                'farmId': farmDoc.id,
              };
              farmId = farmDoc.id;
              print("✅ Found product '$cropName' in your farm '$actualFarmName'");
              break;
            }
          }
        }
        
        if (foundProduct != null) break;
      }
      
      // If no product found in user's farms, inform user
      if (foundProduct == null) {
        print("⚠️ Product '$productName' not found in any of your registered farms");
        _speak(_getLocalizedMessage('product_not_in_user_farms'));
        _updateStatus("Idle");
        return;
      }
      
      await _addToCartAndOrder(foundProduct, farmId!, quantity, unit, actualFarmName ?? farmName);
      
    } catch (e) {
      print("Order error: $e");
      _speak(_getLocalizedMessage('order_failed'));
      _updateStatus("Idle");
    }
  }

  // Handle search commands for browsing products across all farms
  Future<void> _handleSearchCommand(Map<String, dynamic> searchData) async {
    try {
      String productName = searchData['product'] ?? '';
      String searchType = searchData['searchType'] ?? 'all_farms';
      
      print("🔍 Processing search: $productName across $searchType");
      _updateStatus("Searching across all farms...");
      
      // Search for products across all listed farms for browsing
      QuerySnapshot allFarmsQuery = await FirebaseFirestore.instance
          .collection('farms')
          .get();
      
      List<Map<String, dynamic>> foundProducts = [];
      
      print("🏪 Searching through ${allFarmsQuery.docs.length} farms...");
      
      // Search through all farms for the product
      for (var farmDoc in allFarmsQuery.docs) {
        var farmData = farmDoc.data() as Map<String, dynamic>;
        String farmName = farmData['farmName'] ?? 'Unnamed Farm';
        String sellerId = farmData['sellerId'] ?? 'unknown';
        
        List products = farmData['products'] as List? ?? [];
        
        // Search through products in this farm
        for (var product in products) {
          if (product is Map<String, dynamic>) {
            String cropName = (product['cropName'] ?? '').toString().toLowerCase();
            
            // Check if the product name matches (exact or contains)
            if (cropName == productName.toLowerCase() || 
                cropName.contains(productName.toLowerCase()) ||
                productName.toLowerCase().contains(cropName)) {
              
              foundProducts.add({
                'name': product['cropName'] ?? productName,
                'price': int.tryParse(product['pricePerKg']?.toString() ?? '50') ?? 50,
                'farmName': farmName,
                'sellerId': sellerId,
                'stock': int.tryParse(product['stock in kgs']?.toString() ?? '100') ?? 100,
                'farmId': farmDoc.id,
              });
            }
          }
        }
      }
      
      // Provide search results to user
      if (foundProducts.isNotEmpty) {
        String resultMessage = "I found ${foundProducts.length} results for $productName: ";
        for (int i = 0; i < foundProducts.length && i < 3; i++) {
          var product = foundProducts[i];
          resultMessage += "${product['name']} at ${product['farmName']} for ₹${product['price']} per kg";
          if (i < foundProducts.length - 1 && i < 2) resultMessage += ", ";
        }
        if (foundProducts.length > 3) {
          resultMessage += " and ${foundProducts.length - 3} more. Please check the marketplace for details.";
        }
        
        print("✅ Found ${foundProducts.length} products matching '$productName'");
        _speak(resultMessage);
        
        // Navigate to marketplace to show results
        if (_currentContext != null) {
          Navigator.pushNamed(_currentContext!, '/marketplace');
        }
      } else {
        print("❌ No products found matching '$productName'");
        _speak(_getLocalizedMessage('search_no_results'));
      }
      
    } catch (e) {
      print("Search error: $e");
      _speak(_getLocalizedMessage('search_failed'));
    } finally {
      _updateStatus("Idle");
    }
  }

  // Add product to cart and process order
  Future<void> _addToCartAndOrder(Map<String, dynamic> productData, String farmId, String quantity, String unit, String? farmName) async {
    try {
      int qty = int.tryParse(quantity) ?? 1;
      int price = productData['price'] ?? 50;
      String sellerId = productData['sellerId'] ?? 'unknown_seller';
      int stock = productData['stock'] ?? 100;
      
      print("🛍️ Creating cart item: ${productData['name']} x$qty at ₹$price each");
      
      // Check if product is actually available
      if (stock == 0) {
        print("❌ Product not available in any listed farm");
        _speak(_getLocalizedMessage('product_not_available'));
        _updateStatus("Idle");
        return;
      }
      
      // Create cart item
      Map<String, dynamic> cartItem = {
        'id': farmId + '_' + (productData['name'] ?? 'unknown').toString().replaceAll(' ', '_'),
        'name': productData['name'] ?? 'Unknown Product',
        'price': price,
        'quantity': qty,
        'unit': unit,
        'image': productData['image'] ?? 'assets/tomato.png',
        'sellerId': sellerId,
        'farmName': farmName ?? (productData['farmName'] ?? 'Local Farm'),
        'farmId': farmId,
        'stock': stock,
      };
      
      List<Map<String, dynamic>> cartItems = [cartItem];
      
      // Calculate total
      int total = price * qty;
      int deliveryFee = 30;
      int totalPayable = total + deliveryFee;
      
      print("💰 Order total: ₹$total + ₹$deliveryFee delivery = ₹$totalPayable");
      print("🏪 Farm: ${farmName ?? 'Unknown'} (ID: $farmId)");
      
      // Save order to Firestore with farm information
      print("💾 Saving order to Firestore...");
      _updateStatus("Processing order...");
      
      DocumentReference orderRef = await FirebaseFirestore.instance
          .collection('orders')
          .add({
        'cartItems': cartItems,
        'deliveryMethod': 'delivery',
        'itemTotal': total,
        'deliveryFee': deliveryFee,
        'totalPayable': totalPayable,
        'status': 'pending',
        'orderDate': DateTime.now().toIso8601String(),
        'buyerId': FirebaseAuth.instance.currentUser?.uid ?? 'unknown',
        'sellerId': sellerId,
        'farmId': farmId,
        'farmName': farmName ?? 'Unknown Farm',
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      print("✅ Order saved with ID: ${orderRef.id}");
      
      // Navigate to cart page with the items
      if (_currentContext != null) {
        print("🛒 Opening cart page...");
        Navigator.push(
          _currentContext!,
          MaterialPageRoute(
            builder: (context) => CartPage(cartItems: cartItems),
          ),
        );
      }
      
      // Speak confirmation
      _speak(_getLocalizedMessage('order_placed_successfully'));
      _updateStatus("Order placed successfully!");
      
    } catch (e) {
      print("❌ Error in cart processing: $e");
      _speak(_getLocalizedMessage('order_failed'));
      _updateStatus("Order failed: $e");
    }
  }

  // Handle weather queries with current location
  Future<void> _handleWeatherQuery() async {
    try {
      _updateStatus("Getting your weather...");
      
      // Get current location
      final pos = LocationService().currentPosition;
      String query;
      if (pos != null) {
        query = '${pos.latitude},${pos.longitude}';
      } else {
        _updateStatus("Getting your location...");
        await LocationService().determinePosition();
        final newPos = LocationService().currentPosition;
        if (newPos == null) {
          _speak(_getLocalizedMessage('location_failed'));
          _updateStatus("Idle");
          return;
        }
        query = '${newPos.latitude},${newPos.longitude}';
      }
      
      // Fetch weather data
      final key = '994SBTQFYTXZJPS5YLZP5FWGW';
      final uri = Uri.https(
        'weather.visualcrossing.com',
        '/VisualCrossingWebServices/rest/services/timeline/$query',
        {
          'unitGroup': 'metric',
          'include': 'current',
          'key': key,
          'contentType': 'json',
        },
      );
      
      print("🌤️ Fetching weather for location: $query");
      final res = await http.get(uri);
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body) as Map<String, dynamic>;
        final curr = data['currentConditions'] as Map<String, dynamic>;
        
        double temperature = (curr['temp'] as num).toDouble();
        int humidity = (curr['humidity'] as num).toInt();
        String condition = curr['conditions'] as String;
        String? location = data['resolvedAddress'] as String?;
        
        print("✅ Weather data: ${temperature}°C, $humidity% humidity, $condition");
        
        // Create weather response in user's language
        String weatherResponse = _createWeatherResponse(temperature, humidity, condition, location);
        _speak(weatherResponse);
        
      } else {
        print("❌ Weather API error: ${res.statusCode}");
        _speak(_getLocalizedMessage('weather_failed'));
      }
      
    } catch (e) {
      print("❌ Weather error: $e");
      _speak(_getLocalizedMessage('weather_failed'));
    } finally {
      _updateStatus("Idle");
    }
  }

  // Create weather response in user's language
  String _createWeatherResponse(double temperature, int humidity, String condition, String? location) {
    String tempString = temperature.toStringAsFixed(1);
    
    // Translate common weather conditions to local languages
    String localCondition = _translateWeatherCondition(condition);
    
    switch (_currentLanguage) {
      case 'hi-IN':
        String locationPart = location != null ? "आपके क्षेत्र में" : "";
        return "$locationPart वर्तमान मौसम: तापमान $tempString डिग्री सेल्सियस है, आर्द्रता $humidity प्रतिशत है, और मौसम की स्थिति $localCondition है।";
      case 'ta-IN':
        String locationPart = location != null ? "உங்கள் பகுதியில்" : "";
        return "$locationPart தற்போதைய வானிலை: வெப்பநிலை $tempString டிகிரி செல்சியஸ், ஈரப்பதம் $humidity சதவீதம், மற்றும் வானிலை நிலை $localCondition ஆகும்।";
      case 'te-IN':
        String locationPart = location != null ? "మీ ప్రాంతంలో" : "";
        return "$locationPart ప్రస్తుత వాతావరణం: ఉష్ణోగ్రత $tempString డిగ్రీ సెల్సియస్, తేమ $humidity శాతం, మరియు వాతావరణ పరిస్థితి $localCondition।";
      case 'kn-IN':
        String locationPart = location != null ? "ನಿಮ್ಮ ಪ್ರದೇಶದಲ್ಲಿ" : "";
        return "$locationPart ಪ್ರಸ್ತುತ ಹವಾಮಾನ: ತಾಪಮಾನ $tempString ಡಿಗ್ರಿ ಸೆಲ್ಸಿಯಸ್, ಆರ್ದ್ರತೆ $humidity ಶೇಕಡಾ, ಮತ್ತು ಹವಾಮಾನ ಸ್ಥಿತಿ $localCondition।";
      case 'ml-IN':
        String locationPart = location != null ? "നിങ്ങളുടെ പ്രദേശത്ത്" : "";
        return "$locationPart നിലവിലെ കാലാവസ്ഥ: താപനില $tempString ഡിഗ്രി സെൽഷ്യസ്, ഈർപ്പം $humidity ശതമാനം, കാലാവസ്ഥാ സ്ഥിതി $localCondition ആണ്।";
      case 'mr-IN':
        String locationPart = location != null ? "तुमच्या भागात" : "";
        return "$locationPart सध्याचे हवामान: तापमान $tempString अंश सेल्सिअस, आर्द्रता $humidity टक्के, आणि हवामान स्थिती $localCondition आहे।";
      case 'gu-IN':
        String locationPart = location != null ? "તમારા વિસ્તારમાં" : "";
        return "$locationPart વર્તમાન હવામાન: તાપમાન $tempString ડિગ્રી સેલ્સિયસ, ભેજ $humidity ટકા, અને હવામાન સ્થિતિ $localCondition છે।";
      case 'bn-IN':
        String locationPart = location != null ? "আপনার এলাকায়" : "";
        return "$locationPart বর্তমান আবহাওয়া: তাপমাত্রা $tempString ডিগ্রি সেলসিয়াস, আর্দ্রতা $humidity শতাংশ, এবং আবহাওয়ার অবস্থা $localCondition।";
      case 'pa-IN':
        String locationPart = location != null ? "ਤੁਹਾਡੇ ਖੇਤਰ ਵਿੱਚ" : "";
        return "$locationPart ਮੌਜੂਦਾ ਮੌਸਮ: ਤਾਪਮਾਨ $tempString ਡਿਗਰੀ ਸੈਲਸੀਅਸ, ਨਮੀ $humidity ਪ੍ਰਤੀਸ਼ਤ, ਅਤੇ ਮੌਸਮੀ ਸਥਿਤੀ $localCondition ਹੈ।";
      default:
        String locationPart = location != null ? "Here's the current weather in your area: " : "Here's the current weather: ";
        return "${locationPart}Temperature is $tempString degrees Celsius, humidity is $humidity percent, and conditions are $localCondition.";
    }
  }

  // Translate weather conditions to local languages
  String _translateWeatherCondition(String condition) {
    String lowerCondition = condition.toLowerCase();
    
    switch (_currentLanguage) {
      case 'hi-IN':
        if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) return "साफ और धूप वाला";
        if (lowerCondition.contains('cloud')) return "बादलों वाला";
        if (lowerCondition.contains('rain')) return "बारिश वाला";
        if (lowerCondition.contains('storm')) return "तूफानी";
        if (lowerCondition.contains('snow')) return "बर्फीला";
        if (lowerCondition.contains('fog')) return "धुंधला";
        return condition;
      case 'ta-IN':
        if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) return "தெளிவான மற்றும் வெயில்";
        if (lowerCondition.contains('cloud')) return "மேகமூட்டமான";
        if (lowerCondition.contains('rain')) return "மழையுள்ள";
        if (lowerCondition.contains('storm')) return "புயல்";
        if (lowerCondition.contains('snow')) return "பனி";
        if (lowerCondition.contains('fog')) return "மூடுபனி";
        return condition;
      case 'te-IN':
        if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) return "స్పష్టమైన మరియు ఎండ";
        if (lowerCondition.contains('cloud')) return "మేఘావృతమైన";
        if (lowerCondition.contains('rain')) return "వర్షం";
        if (lowerCondition.contains('storm')) return "తుఫాను";
        if (lowerCondition.contains('snow')) return "మంచు";
        if (lowerCondition.contains('fog')) return "పొగమంచు";
        return condition;
      case 'kn-IN':
        if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) return "ಸ್ಪಷ್ಟ ಮತ್ತು ಬಿಸಿಲು";
        if (lowerCondition.contains('cloud')) return "ಮೇಘಮಯ";
        if (lowerCondition.contains('rain')) return "ಮಳೆ";
        if (lowerCondition.contains('storm')) return "ಚಂಡಮಾರುತ";
        if (lowerCondition.contains('snow')) return "ಹಿಮ";
        if (lowerCondition.contains('fog')) return "ಮಂಜು";
        return condition;
      case 'ml-IN':
        if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) return "വ്യക്തവും വെയിലും";
        if (lowerCondition.contains('cloud')) return "മേഘാവൃതം";
        if (lowerCondition.contains('rain')) return "മഴ";
        if (lowerCondition.contains('storm')) return "കൊടുങ്കാറ്റ്";
        if (lowerCondition.contains('snow')) return "മഞ്ഞ്";
        if (lowerCondition.contains('fog')) return "മൂടൽമഞ്ഞ്";
        return condition;
      case 'mr-IN':
        if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) return "स्पष्ट आणि सनी";
        if (lowerCondition.contains('cloud')) return "ढगाळ";
        if (lowerCondition.contains('rain')) return "पावसाळी";
        if (lowerCondition.contains('storm')) return "वादळी";
        if (lowerCondition.contains('snow')) return "बर्फाळ";
        if (lowerCondition.contains('fog')) return "धुक्याळ";
        return condition;
      case 'gu-IN':
        if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) return "સ્પષ્ટ અને સૂર્યપ્રકાશ";
        if (lowerCondition.contains('cloud')) return "વાદળછાયું";
        if (lowerCondition.contains('rain')) return "વરસાદી";
        if (lowerCondition.contains('storm')) return "તોફાની";
        if (lowerCondition.contains('snow')) return "બરફીલું";
        if (lowerCondition.contains('fog')) return "ધુમ્મસભર્યું";
        return condition;
      case 'bn-IN':
        if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) return "পরিষ্কার এবং রৌদ্রোজ্জ্বল";
        if (lowerCondition.contains('cloud')) return "মেঘলা";
        if (lowerCondition.contains('rain')) return "বৃষ্টি";
        if (lowerCondition.contains('storm')) return "ঝড়";
        if (lowerCondition.contains('snow')) return "তুষার";
        if (lowerCondition.contains('fog')) return "কুয়াশাচ্ছন্ন";
        return condition;
      case 'pa-IN':
        if (lowerCondition.contains('clear') || lowerCondition.contains('sunny')) return "ਸਾਫ਼ ਅਤੇ ਧੁੱਪ ਵਾਲਾ";
        if (lowerCondition.contains('cloud')) return "ਬੱਦਲਵਾਈ";
        if (lowerCondition.contains('rain')) return "ਬਰਸਾਤੀ";
        if (lowerCondition.contains('storm')) return "ਤੂਫਾਨੀ";
        if (lowerCondition.contains('snow')) return "ਬਰਫੀਲਾ";
        if (lowerCondition.contains('fog')) return "ਧੁੰਦਲਾ";
        return condition;
      default:
        return condition;
    }
  }

  void _executeAction(String actionJson) async {
    try {
      // Clean the JSON string first
      String cleanJson = actionJson.trim();
      
      // Remove any markdown formatting if present
      if (cleanJson.startsWith('```json')) {
        cleanJson = cleanJson.substring(7);
      }
      if (cleanJson.endsWith('```')) {
        cleanJson = cleanJson.substring(0, cleanJson.length - 3);
      }
      cleanJson = cleanJson.trim();
      
      final action = jsonDecode(cleanJson);
      final command = action['command'];
      final value = action['value'];

      print("Executing command: $command with value: $value");

      if (_currentContext == null) {
        _speak("I'm sorry, I can't perform that action right now. Could you please try again?");
        _updateStatus("Idle");
        return;
      }

      switch (command) {
        case 'navigate':
          _handleNavigation(value, _currentContext!);
          break;
        case 'order':
          await _handleOrderCommand(value);
          break;
        case 'search':
          await _handleSearchCommand(value);
          break;
        case 'advice':
          _speak("Here are some helpful farming tips for you: Make sure to water your plants regularly, always check the soil moisture before watering, and keep an eye out for any pests or diseases on your crops.");
          break;
        case 'query':
          if (value == 'weather') {
            await _handleWeatherQuery();
          } else {
            _speak("I'm here to help you with navigation and farming advice. What would you like me to assist you with today?");
          }
          break;
        default:
          _speak("I understood what you said, but I'm not quite sure how to help with that yet. Could you try asking me something else?");
      }
    } catch (e) {
      print("JSON Parse Error: $e");
      print("Problematic JSON: $actionJson");
      // Instead of showing an error, just fall back to local processing
      _speak("Let me try to understand that in a different way.");
      // Extract the original command from the context and process locally
      if (_lastWords.isNotEmpty) {
        _fallbackToLocalProcessing(_lastWords);
      } else {
        _speak("Could you please try saying that command again?");
      }
    } finally {
      _updateStatus("Idle");
    }
  }

  void _handleNavigation(String destination, BuildContext context) {
    try {
      // First try to use the static navigation wrapper for main navigation pages
      final wrapper = StaticNavigationWrapper.of(context);
      
      switch (destination) {
        case 'dashboard':
          if (wrapper != null) {
            // Use static navigation for home/dashboard (preserves bottom nav)
            wrapper.onPageChanged(NavigationService.homeIndex);
            _speak(_getLocalizedMessage('dashboard_opened'));
          } else {
            // Fallback to direct navigation
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
            _speak(_getLocalizedMessage('dashboard_opened'));
          }
          break;
        case 'marketplace':
          if (wrapper != null) {
            // Use static navigation for marketplace (preserves bottom nav)
            wrapper.onPageChanged(NavigationService.marketIndex);
            _speak(_getLocalizedMessage('marketplace_opened'));
          } else {
            // Fallback to direct navigation
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MarketplacePage()));
            _speak(_getLocalizedMessage('marketplace_opened'));
          }
          break;
        case 'ai_tools':
          if (wrapper != null) {
            // Use static navigation for AI tools (preserves bottom nav)
            wrapper.onPageChanged(NavigationService.aiIndex);
            _speak(_getLocalizedMessage('ai_tools_opened'));
          } else {
            // Fallback to direct navigation
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AIPage()));
            _speak(_getLocalizedMessage('ai_tools_opened'));
          }
          break;
        case 'community':
          if (wrapper != null) {
            // Use static navigation for community (preserves bottom nav)
            wrapper.onPageChanged(NavigationService.communityIndex);
            _speak(_getLocalizedMessage('community_opened'));
          } else {
            // Fallback to direct navigation
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CommunityPage()));
            _speak(_getLocalizedMessage('community_opened'));
          }
          break;
        // For sub-pages that aren't part of main navigation, use regular navigation
        case 'crop_suggestions':
          Navigator.push(context, MaterialPageRoute(builder: (_) => CropSuggestionPage()));
          _speak(_getLocalizedMessage('crop_suggestions_opened'));
          break;
        case 'plant_registration':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const GrowPlantPage()));
          _speak(_getLocalizedMessage('plant_registration_opened'));
          break;
        case 'farm_management':
          Navigator.push(context, MaterialPageRoute(builder: (_) => ListFarmPage()));
          _speak(_getLocalizedMessage('farm_management_opened'));
          break;
        case 'analysis':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlantGrowthAnalysisPage()));
          _speak(_getLocalizedMessage('analysis_opened'));
          break;
        default:
          _speak(_getLocalizedMessage('page_not_found'));
      }
    } catch (e) {
      print("Navigation error: $e");
      _speak("Oops! I encountered a small issue while trying to navigate there. Could you please try that again?");
    }
  }

  Future<void> _speak(String text) async {
    _updateStatus("Speaking...");
    
    // Add natural pauses and emphasis for better speech
    String enhancedText = text
        .replaceAll('!', '. ') // Convert exclamation to pause
        .replaceAll(',', ', ') // Add slight pause after commas
        .replaceAll('TeraFarm', 'Tera Farm'); // Better pronunciation
    
    await _flutterTts.speak(enhancedText);
    _updateStatus("Idle");
  }
}

// Global instance for reuse across all pages
VoiceAssistantState? _globalVoiceAssistant;

// 2. Simple Voice Assistant Widget - Single Instance
class VoiceAssistantWidget extends StatefulWidget {
  const VoiceAssistantWidget({Key? key}) : super(key: key);

  @override
  State<VoiceAssistantWidget> createState() => _VoiceAssistantWidgetState();
}

class _VoiceAssistantWidgetState extends State<VoiceAssistantWidget> {
  late VoiceAssistantState _voiceAssistant;

  @override
  void initState() {
    super.initState();
    // Use global instance or create new one
    _globalVoiceAssistant ??= VoiceAssistantState();
    _voiceAssistant = _globalVoiceAssistant!;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _voiceAssistant,
      child: Consumer2<VoiceAssistantState, LocaleProvider>(
        builder: (context, state, localeProvider, child) {
          // Set the current context for navigation and sync language
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state.setContext(context);
            
            // Set up sync with locale provider (only once)
            state.syncWithLocaleProvider(localeProvider);
            
            // ALWAYS sync voice assistant language with app locale
            String currentLocale = localeProvider.locale.languageCode;
            String voiceLanguageCode = '$currentLocale-IN';
            
            // Force update voice assistant language to match app locale
            if (state.supportedLanguages.containsKey(voiceLanguageCode)) {
              if (state.currentLanguage != voiceLanguageCode) {
                print('🔄 Auto-syncing voice language from ${state.currentLanguage} to $voiceLanguageCode');
                state.switchLanguage(voiceLanguageCode);
              }
            }
          });
          
          return Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Compact language selector with beautiful design
                GestureDetector(
                  onTap: () => _showLanguageSelector(context, state),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.shade600, Colors.green.shade700],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.language,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _getLanguageShortName(state.currentLanguage),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.expand_more,
                          color: Colors.white,
                          size: 12,
                        ),
                      ],
                    ),
                  ),
                ),
                // Beautiful voice assistant button
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: state.isListening 
                            ? Colors.red.withOpacity(0.4)
                            : Colors.green.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: FloatingActionButton(
                    onPressed: state.isListening ? state.stopListening : state.startListening,
                    backgroundColor: state.isListening 
                        ? Colors.red.shade600 
                        : Colors.green.shade700,
                    elevation: 0,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Main microphone icon
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            state.isListening ? Icons.mic : Icons.mic_none_rounded,
                            key: ValueKey(state.isListening),
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                        // Animated pulse ring when listening
                        if (state.isListening)
                          TweenAnimationBuilder(
                            tween: Tween<double>(begin: 0.8, end: 1.2),
                            duration: const Duration(milliseconds: 1000),
                            builder: (context, double value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                            onEnd: () {
                              // Restart animation if still listening
                              if (state.isListening) {
                                setState(() {});
                              }
                            },
                          ),
                        // Compact status indicator
                        if (state.status != "Idle")
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: _getStatusColor(state.status),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: _getStatusColor(state.status).withOpacity(0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Compact status text with fade animation
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: state.status != "Idle" ? 20 : 0,
                  child: AnimatedOpacity(
                    opacity: state.status != "Idle" ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        state.status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper method to show language selector modal
  void _showLanguageSelector(BuildContext context, VoiceAssistantState state) {
    final localeProvider = Provider.of<LocaleProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Select Language',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
            ),
            // Language options
            ...state.supportedLanguages.entries.map((entry) {
              final isSelected = entry.key == state.currentLanguage;
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected 
                          ? [Colors.green.shade600, Colors.green.shade700]
                          : [Colors.grey.shade300, Colors.grey.shade400],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.language,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                title: Text(
                  entry.value,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.green.shade700 : Colors.grey.shade700,
                  ),
                ),
                trailing: isSelected 
                    ? Icon(Icons.check_circle, color: Colors.green.shade700)
                    : null,
                onTap: () {
                  // Update voice assistant language
                  state.switchLanguage(entry.key);
                  
                  // Also update app locale to match
                  String languageCode = entry.key.split('-')[0]; // Extract 'en' from 'en-IN'
                  localeProvider.setLocale(Locale(languageCode));
                  
                  Navigator.pop(context);
                },
              );
            }).toList(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // Helper method to get short language name
  String _getLanguageShortName(String languageCode) {
    final shortNames = {
      'en-IN': 'EN',
      'hi-IN': 'हिं',
      'ta-IN': 'த',
      'te-IN': 'తె',
      'kn-IN': 'ಕ',
      'ml-IN': 'മ',
      'mr-IN': 'मर',
      'gu-IN': 'ગુ',
      'bn-IN': 'বা',
      'pa-IN': 'ਪੰ',
    };
    return shortNames[languageCode] ?? 'EN';
  }

  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case "Listening...":
        return Colors.red;
      case "Processing...":
        return Colors.orange;
      case "Speaking...":
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
