import 'package:dio/dio.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_keys.dart';
import 'youtube_service.dart';

class EnhancedAIService {
  static const String _geminiApiKey = ApiKeys.gemini;
  
  late final GenerativeModel _model;
  final Dio _dio = Dio();
  final YouTubeService _youtubeService = YouTubeService();
  EnhancedAIService() {
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

  /// Launch URL in browser
  Future<void> launchURL(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        print('Could not launch $url');
      }
    } catch (e) {
      print('Error launching URL: $e');
    }
  }

  /// Get YouTube tutorial videos for a scheme
  Future<List<YouTubeVideo>> getSchemeVideos(String schemeName, String locale) async {
    try {
      String language = _getLanguageCode(locale);
      return await _youtubeService.searchSchemeVideos(
        schemeName: schemeName,
        language: language,
        maxResults: 3,
      );
    } catch (e) {
      print('Error getting YouTube videos: $e');
      return [];
    }
  }

  /// Get language code for YouTube API
  String _getLanguageCode(String locale) {
    switch (locale.toLowerCase()) {
      case 'hindi':
        return 'hi';
      case 'tamil':
        return 'ta';
      case 'telugu':
        return 'te';
      case 'english':
      default:
        return 'en';
    }
  }

  /// Enhanced farmer-friendly response generation with locale support
  Future<String> generateFarmerFriendlyResponse(String query, {String? userProfile, String locale = 'hindi'}) async {
    try {
      // First, search for current information
      String webSearchResults = await _searchWeb(query, locale);
      
      // Create farmer-friendly prompt based on locale
      String enhancedPrompt = _createFarmerFriendlyPrompt(query, webSearchResults, userProfile, locale);
      
      // Generate response using Gemini
      final content = [Content.text(enhancedPrompt)];
      final response = await _model.generateContent(content);
      
      String generatedText = response.text ?? _getDefaultResponse(locale);
      
      // Post-process to ensure farmer-friendly language
      return _postProcessResponse(generatedText, locale);
      
    } catch (e) {
      print('Enhanced AI Error: $e');
      return _getFallbackResponse(query, locale);
    }
  }

  /// Enhanced response with YouTube videos
  Future<Map<String, dynamic>> generateEnhancedResponseWithVideos(String query, {String? userProfile, String locale = 'hindi'}) async {
    try {
      // Generate the text response
      String textResponse = await generateFarmerFriendlyResponse(query, userProfile: userProfile, locale: locale);
      
      // Extract scheme name from query for video search
      String schemeName = _extractSchemeName(query);
      List<YouTubeVideo> videos = [];
      
      if (schemeName.isNotEmpty) {
        videos = await getSchemeVideos(schemeName, locale);
      }
      
      return {
        'text': textResponse,
        'videos': videos,
        'hasVideos': videos.isNotEmpty,
      };
    } catch (e) {
      print('Enhanced response with videos error: $e');
      return {
        'text': await generateFarmerFriendlyResponse(query, userProfile: userProfile, locale: locale),
        'videos': <YouTubeVideo>[],
        'hasVideos': false,
      };
    }
  }

  /// Extract scheme name from query for video search
  String _extractSchemeName(String query) {
    String queryLower = query.toLowerCase();
    
    // Common scheme patterns
    Map<String, String> schemePatterns = {
      'pm kisan': 'PM-KISAN',
      'pmkisan': 'PM-KISAN',
      'किसान': 'PM-KISAN',
      'kisan': 'PM-KISAN',
      'pmfby': 'PMFBY', 
      'fasal bima': 'PMFBY',
      'crop insurance': 'PMFBY',
      'फसल बीमा': 'PMFBY',
      'kcc': 'KCC',
      'credit card': 'KCC',
      'क्रेडिट कार्ड': 'KCC',
      'soil health': 'Soil Health Card',
      'मिट्टी स्वास्थ्य': 'Soil Health Card',
    };
    
    for (String pattern in schemePatterns.keys) {
      if (queryLower.contains(pattern)) {
        return schemePatterns[pattern]!;
      }
    }
    
    return '';
  }

  /// Search web for current information with locale support
  Future<String> _searchWeb(String query, String locale) async {
    try {
      // For now, return curated scheme information
      // TODO: Implement proper web search when Custom Search Engine is set up
      print('🔍 Searching for: $query in $locale');
      return _getFallbackSchemeInfo(query, locale);
    } catch (e) {
      print('Web search error: $e');
      return _getFallbackSchemeInfo(query, locale);
    }
  }

  /// Create farmer-friendly prompt with multilingual support
  String _createFarmerFriendlyPrompt(String query, String webSearchResults, String? userProfile, String locale) {
    Map<String, String> prompts = {
      'hindi': '''
आप एक अनुभवी कृषि सलाहकार हैं जो भारतीय किसानों की मदद करते हैं। आपको बहुत सरल और व्यावहारिक जवाब देना है।

किसान का सवाल: $query

${userProfile != null ? 'किसान की जानकारी: $userProfile' : ''}

वेब सर्च से मिली जानकारी:
$webSearchResults

निर्देश:
1. बहुत सरल हिंदी में जवाब दें (अंग्रेजी शब्द कम से कम उपयोग करें)
2. व्यावहारिक कदम बताएं (1, 2, 3 में)
3. आवेदन कैसे करें - स्पष्ट रूप से बताएं
4. जरूरी वेबसाइट के लिंक दें
5. फोन नंबर या पता दें जहां संपर्क कर सकें
6. कृषि योजनाओं की जानकारी दें
7. बहुत विस्तार में न जाएं - मुख्य बातें ही बताएं
8. कोई भी ** (stars) का इस्तेमाल न करें - सिर्फ emojis का इस्तेमाल करें
9. हर सेक्शन के लिए अलग emoji का इस्तेमाल करें

उदाहरण फॉर्मेट:
🌾 मुख्य जानकारी:
- सरल व्याख्या

📝 आवेदन कैसे करें:
1. पहला कदम
2. दूसरा कदम  
3. तीसरा कदम

🔗 जरूरी लिंक:
- वेबसाइट का नाम: URL

📞 संपर्क:
- फोन नंबर या पता

💡 अतिरिक्त सुझाव:
- व्यावहारिक सलाह

कृपया 200-300 शब्दों में जवाब दें।
''',
      'english': '''
You are an experienced agricultural consultant helping Indian farmers. You must provide very simple and practical answers.

Farmer's question: $query

${userProfile != null ? 'Farmer profile: $userProfile' : ''}

Information from web search:
$webSearchResults

Instructions:
1. Answer in simple English (use common terms, avoid technical jargon)
2. Provide practical steps (numbered 1, 2, 3)
3. Clearly explain how to apply
4. Give important website links
5. Provide phone numbers or addresses for contact
6. Include information about agricultural schemes
7. Don't go into too much detail - focus on key points
8. Never use ** (stars) - only use emojis for formatting
9. Use different emojis for each section

Example format:
🌾 Key Information:
- Simple explanation

📝 How to Apply:
1. First step
2. Second step
3. Third step

🔗 Important Links:
- Website name: URL

📞 Contact:
- Phone number or address

💡 Additional Tips:
- Practical advice

Please respond in 200-300 words.
''',
      'tamil': '''
நீங்கள் இந்திய விவசாயிகளுக்கு உதவும் அனுபவமிக்க வேளாண் ஆலோசகர். மிகவும் எளிய மற்றும் நடைமுறை பதில்களை வழங்க வேண்டும்.

விவசாயியின் கேள்வி: $query

${userProfile != null ? 'விவசாயி விவரம்: $userProfile' : ''}

வலை தேடலில் இருந்து தகவல்:
$webSearchResults

வழிமுறைகள்:
1. எளிய தமிழில் பதில் சொல்லுங்கள் (கடினமான வார்த்தைகளைத் தவிருங்கள்)
2. நடைமுறை படிகளை சொல்லுங்கள் (1, 2, 3 என்று)
3. எப்படி விண்ணப்பிப்பது என்று தெளிவாக சொல்லுங்கள்
4. முக்கியமான வலைதள இணைப்புகள் கொடுங்கள்
5. தொடர்பு கொள்ள பேசி எண் அல்லது முகவரி கொடுங்கள்
6. வேளாண் திட்டங்களின் தகவல்கள் கொடுங்கள்
7. அதிக விவரங்களுக்கு போகாமல் - முக்கிய விஷயங்களை மட்டும் சொல்லுங்கள்
8. ** (நட்சத்திரங்களை) பயன்படுத்த வேண்டாம் - emojis மட்டும் பயன்படுத்தவும்
9. ஒவ்வொரு பகுதிக்கும் வெவ்வேறு emoji பயன்படுத்தவும்

உதாரண வடிவம்:
🌾 முக்கிய தகவல்:
- எளிய விளக்கம்

📝 எப்படி விண்ணப்பிப்பது:
1. முதல் படி
2. இரண்டாம் படி
3. மூன்றாம் படி

🔗 முக்கிய இணைப்புகள்:
- வலைதள பெயர்: URL

📞 தொடர்பு:
- பேசி எண் அல்லது முகவரி

💡 கூடுதல் ஆலோசனைகள்:
- நடைமுறை அறிவுரைகள்

தயவுசெய்து 200-300 வார்த்தைகளில் பதில் சொல்லுங்கள்.
''',
      'telugu': '''
మీరు భారతీయ రైతులకు సహాయం చేసే అనుభవం గల వ్యవసాయ సలహాదారు. మీరు చాలా సరళమైన మరియు ఆచరణాత్మక సమాధానాలు అందించాలి.

రైతు ప్రశ్న: $query

${userProfile != null ? 'రైతు వివరాలు: $userProfile' : ''}

వెబ్ సెర్చ్ నుండి సమాచారం:
$webSearchResults

సూచనలు:
1. సరళమైన తెలుగులో సమాధానం చెప్పండి (కష్టమైన పదాలను వాడకండి)
2. ఆచరణాత్మక దశలను చెప్పండి (1, 2, 3 గా)
3. ఎలా దరఖాస్తు చేసుకోవాలో స్పష్టంగా చెప్పండి
4. ముఖ్యమైన వెబ్‌సైట్ లింకులు ఇవ్వండి
5. సంప్రదించడానికి ఫోన్ నంబర్ లేదా చిరునామా ఇవ్వండి
6. వ్యవసాయ పథకాల సమాచారం ఇవ్వండి
7. ఎక్కువ వివరాలలోకి పోకుండా - ముఖ్య విషయాలను మాత్రమే చెప్పండి
8. ** (నక్షత్రాలను) వాడకండి - emojis మాత్రమే వాడండి
9. ప్రతి భాగానికి వేరే emoji వాడండి

ఉదాహరణ ఫార్మాట్:
🌾 ప్రధాన సమాచారం:
- సరళమైన వివరణ

📝 ఎలా దరఖాస్తు చేసుకోవాలి:
1. మొదటి దశ
2. రెండవ దశ
3. మూడవ దశ

🔗 ముఖ్యమైన లింకులు:
- వెబ్‌సైట్ పేరు: URL

📞 సంప్రదింపు:
- ఫోన్ నంబర్ లేదా చిరునామా

💡 అదనపు సలహాలు:
- ఆచరణాత్మక సలహా

దయచేసి 200-300 పదాలలో సమాధానం ఇవ్వండి.
'''
    };

    return prompts[locale] ?? prompts['hindi']!;
  }

  /// Post-process response to ensure farmer-friendly language based on locale
  String _postProcessResponse(String response, String locale) {
    Map<String, Map<String, String>> translations = {
      'hindi': {
        'implementation': 'लागू करना',
        'agriculture': 'खेती',
        'subsidy': 'सब्सिडी',
        'government': 'सरकार',
        'scheme': 'योजना',
        'application': 'आवेदन',
        'registration': 'पंजीकरण',
        'farmer': 'किसान',
        'crop': 'फसल',
        'loan': 'ऋण',
        'insurance': 'बीमा'
      },
      'english': {
        'implementation': 'implementation',
        'agriculture': 'farming',
        'subsidy': 'subsidy',
        'government': 'government',
        'scheme': 'scheme',
        'application': 'application',
        'registration': 'registration',
        'farmer': 'farmer',
        'crop': 'crop',
        'loan': 'loan',
        'insurance': 'insurance'
      },
      'tamil': {
        'implementation': 'செயல்படுத்துதல்',
        'agriculture': 'விவசாயம்',
        'subsidy': 'மானியம்',
        'government': 'அரசாங்கம்',
        'scheme': 'திட்டம்',
        'application': 'விண்ணப்பம்',
        'registration': 'பதிவு',
        'farmer': 'விவசாயி',
        'crop': 'பயிர்',
        'loan': 'கடன்',
        'insurance': 'காப்பீடு'
      },
      'telugu': {
        'implementation': 'అమలు',
        'agriculture': 'వ్యవసాయం',
        'subsidy': 'రాయితీ',
        'government': 'ప్రభుత్వం',
        'scheme': 'పథకం',
        'application': 'దరఖాస్తు',
        'registration': 'నమోదు',
        'farmer': 'రైతు',
        'crop': 'పంట',
        'loan': 'రుణం',
        'insurance': 'బీమా'
      }
    };

    Map<String, String> localeTranslations = translations[locale] ?? translations['hindi']!;
    
    // Replace technical terms with simple terms
    for (String key in localeTranslations.keys) {
      response = response.replaceAll(key, localeTranslations[key]!);
    }
    
    // Remove markdown stars and replace with emojis
    response = _removeStarsAndAddEmojis(response, locale);
    
    // Format URLs to be clickable
    response = _formatClickableUrls(response);
    
    // Ensure proper formatting
    if (!response.contains('🌾') && !response.contains('📝')) {
      response = _formatResponse(response, locale);
    }
    
    return response;
  }

  /// Format URLs to be clickable
  String _formatClickableUrls(String response) {
    // Keep URLs clean and simple for better parsing
    // Just ensure URLs are on their own lines with emoji for visibility
    final urlRegex = RegExp(r'Link:\s*(https?://[^\s\]]+)');
    response = response.replaceAllMapped(urlRegex, (match) {
      String url = match.group(1)!;
      return '🔗 $url';
    });
    
    // Clean up any existing formatting that might interfere
    response = response.replaceAll(RegExp(r'\*\*(https?://[^\s\*]+)\*\*'), r'$1');
    response = response.replaceAll(RegExp(r'\[(https?://[^\]]+)\]\([^)]+\)'), r'$1');
    
    return response;
  }

  /// Format response with proper structure based on locale
  String _formatResponse(String response, String locale) {
    Map<String, String> formats = {
      'hindi': '''
**मुख्य जानकारी:**
$response

**संपर्क के लिए:**
- अपने जिले के कृषि कार्यालय में जाएं
- किसान कॉल सेंटर: 1800-180-1551

**सुझाव:**
- सभी जरूरी कागजात साथ रखें
- समय पर आवेदन करें
''',
      'english': '''
**Key Information:**
$response

**For Contact:**
- Visit your district agriculture office
- Farmer Call Center: 1800-180-1551

**Tips:**
- Keep all necessary documents ready
- Apply on time
''',
      'tamil': '''
**முக்கிய தகவல்:**
$response

**தொடர்புக்கு:**
- உங்கள் மாவட்ட விவசாய அலுவலகத்திற்கு செல்லுங்கள்
- விவசாயி அழைப்பு மையம்: 1800-180-1551

**ஆலோசனைகள்:**
- அனைத்து தேவையான ஆவணங்களையும் தயாராக வைத்திருங்கள்
- சரியான நேரத்தில் விண்ணப்பிக்கவும்
''',
      'telugu': '''
**ప్రధాన సమాచారం:**
$response

**సంప్రదింపుకు:**
- మీ జిల్లా వ్యవసాయ కార్యాలయానికి వెళ్లండి
- రైతు కాల్ సెంటర్: 1800-180-1551

**సలహాలు:**
- అవసరమైన అన్ని పత్రాలను సిద్ధంగా ఉంచండి
- సమయానికి దరఖాస్తు చేసుకోండి
'''
    };

    return formats[locale] ?? formats['hindi']!;
  }

  /// Get fallback scheme information with current 2024-2025 data based on locale
  String _getFallbackSchemeInfo(String query, String locale) {
    // Get scheme info for the specific locale
    Map<String, String> schemes = _getSchemesByLocale(locale);
    
    String lowerQuery = query.toLowerCase();
    
    // Check for specific scheme keywords in multiple languages
    if (lowerQuery.contains('tomato') || lowerQuery.contains('टमाटर') || lowerQuery.contains('தக்காளி') || lowerQuery.contains('టమాటా') || 
        lowerQuery.contains('vegetable') || lowerQuery.contains('सब्जी') || lowerQuery.contains('காய்கறி') || lowerQuery.contains('కూరగాయలు')) {
      return schemes['tomato']!;
    } else if (lowerQuery.contains('loan') || lowerQuery.contains('ऋण') || lowerQuery.contains('கடன்') || lowerQuery.contains('రుణం') || 
               lowerQuery.contains('credit') || lowerQuery.contains('कर्ज')) {
      return schemes['loan']!;
    } else if (lowerQuery.contains('subsidy') || lowerQuery.contains('सब्सिडी') || lowerQuery.contains('மானியம்') || lowerQuery.contains('రాయితీ') || 
               lowerQuery.contains('anudaan') || lowerQuery.contains('अनुदान')) {
      return schemes['subsidy']!;
    } else if (lowerQuery.contains('insurance') || lowerQuery.contains('बीमा') || lowerQuery.contains('காப்பீடு') || lowerQuery.contains('బీమా') || 
               lowerQuery.contains('bima')) {
      return schemes['insurance']!;
    } else {
      return schemes['schemes']!;
    }
  }

  /// Get schemes information by locale
  Map<String, String> _getSchemesByLocale(String locale) {
    Map<String, Map<String, String>> allSchemes = {
      'hindi': {
        'tomato': '''
Title: टमाटर और सब्जी उत्पादन के लिए हॉर्टिकल्चर मिशन 2024-25
Link: https://midh.gov.in
Snippet: टमाटर की खेती के लिए 50% सब्सिडी - ड्रिप सिस्टम, ग्रीनहाउस, और प्रसंस्करण यूनिट के लिए वित्तीय सहायता। आवेदन ऑनलाइन करें।
''',
        'loan': '''
Title: किसान क्रेडिट कार्ड (KCC) 2024-25
Link: https://pmkisan.gov.in/KCCApplication.aspx
Snippet: केवल 4% ब्याज दर पर ₹3 लाख तक का फसल ऋण। आधार कार्ड और जमीन के कागज से आसान आवेदन।
''',
        'subsidy': '''
Title: कृषि यंत्र अनुदान योजना 2024-25
Link: https://agrimachinery.nic.in
Snippet: ट्रैक्टर, हार्वेस्टर पर 50-80% तक सब्सिडी। SC/ST को 90% तक सब्सिडी।
''',
        'insurance': '''
Title: प्रधानमंत्री फसल बीमा योजना (PMFBY) 2024-25
Link: https://pmfby.gov.in
Snippet: सभी फसलों का बीमा - खरीफ में 2%, रबी में 1.5% प्रीमियम।
''',
        'schemes': '''
Title: PM-KISAN योजना 2024-25
Link: https://pmkisan.gov.in
Snippet: सभी किसानों को सालाना ₹6000 - तीन किस्तों में ₹2000-2000।
'''
      },
      'english': {
        'tomato': '''
Title: Horticulture Mission for Tomato & Vegetable Production 2024-25
Link: https://midh.gov.in
Snippet: 50% subsidy for tomato farming - drip system, greenhouse, and processing unit financial assistance. Apply online.
''',
        'loan': '''
Title: Kisan Credit Card (KCC) 2024-25
Link: https://pmkisan.gov.in/KCCApplication.aspx
Snippet: Crop loan up to ₹3 lakh at only 4% interest rate. Easy application with Aadhaar card and land documents.
''',
        'subsidy': '''
Title: Agricultural Machinery Subsidy Scheme 2024-25
Link: https://agrimachinery.nic.in
Snippet: 50-80% subsidy on tractors, harvesters. Up to 90% subsidy for SC/ST.
''',
        'insurance': '''
Title: Pradhan Mantri Fasal Bima Yojana (PMFBY) 2024-25
Link: https://pmfby.gov.in
Snippet: Insurance for all crops - 2% premium for Kharif, 1.5% for Rabi.
''',
        'schemes': '''
Title: PM-KISAN Scheme 2024-25
Link: https://pmkisan.gov.in
Snippet: ₹6000 annually to all farmers - in three installments of ₹2000 each.
'''
      },
      'tamil': {
        'tomato': '''
Title: தக்காளி மற்றும் காய்கறி உற்பத்திக்கான தோட்டக்கலை திட்டம் 2024-25
Link: https://midh.gov.in
Snippet: தக்காளி விவசாயத்திற்கு 50% மானியம் - சொட்டு நீர், பசுமை இல்லம், செயலாக்க அலகுக்கு நிதி உதவி। ஆன்லைனில் விண்ணப்பிக்கவும்.
''',
        'loan': '''
Title: கிசான் கிரெடிட் கார்டு (KCC) 2024-25
Link: https://pmkisan.gov.in/KCCApplication.aspx
Snippet: வெறும் 4% வட்டி விகிதத்தில் ₹3 லட்சம் வரை பயிர் கடன். ஆதார் அட்டை மற்றும் நில ஆவணங்களுடன் எளிய விண்ணப்பம்.
''',
        'subsidy': '''
Title: விவசாய இயந்திர மானிய திட்டம் 2024-25
Link: https://agrimachinery.nic.in
Snippet: டிராக்டர், அறுவடை இயந்திரங்களுக்கு 50-80% வரை மானியம். SC/ST-க்கு 90% வரை மானியம்.
''',
        'insurance': '''
Title: பிரதான மந்திரி பசல் பீமா யோஜனா (PMFBY) 2024-25
Link: https://pmfby.gov.in
Snippet: அனைத்து பயிர்களுக்கும் காப்பீடு - கரீப் பயிருக்கு 2%, ரபி பயிருக்கு 1.5% பிரீமியம்.
''',
        'schemes': '''
Title: PM-KISAN திட்டம் 2024-25
Link: https://pmkisan.gov.in
Snippet: அனைத்து விவசாயிகளுக்கும் ஆண்டுக்கு ₹6000 - மூன்று தவணைகளில் ₹2000 வீதம்.
'''
      },
      'telugu': {
        'tomato': '''
Title: టమాటా మరియు కూరగాయల ఉత్పాదనకు హార్టికల్చర్ మిషన్ 2024-25
Link: https://midh.gov.in
Snippet: టమాటా వ్యవసాయానికి 50% రాయితీ - డ్రిప్ సిస్టమ్, గ్రీన్‌హౌస్, ప్రాసెసింగ్ యూనిట్ కోసం ఆర్థిక సహాయం. ఆన్‌లైన్‌లో దరఖాస్తు చేసుకోండి.
''',
        'loan': '''
Title: కిసాన్ క్రెడిట్ కార్డ్ (KCC) 2024-25
Link: https://pmkisan.gov.in/KCCApplication.aspx
Snippet: కేవలం 4% వడ్డీ రేటుతో ₹3 లక్షల వరకు పంట రుణం. ఆధార్ కార్డ్ మరియు భూమి పత్రాలతో సులభ దరఖాస్తు.
''',
        'subsidy': '''
Title: వ్యవసాయ యంత్రాల రాయితీ పథకం 2024-25
Link: https://agrimachinery.nic.in
Snippet: ట్రాక్టర్లు, హార్వెస్టర్లపై 50-80% వరకు రాయితీ. SC/ST లకు 90% వరకు రాయితీ.
''',
        'insurance': '''
Title: ప్రధాన మంత్రి ఫసల్ బీమా యోజన (PMFBY) 2024-25
Link: https://pmfby.gov.in
Snippet: అన్ని పంటలకు బీమా - ఖరీఫ్‌కు 2%, రబీకు 1.5% ప్రీమియం.
''',
        'schemes': '''
Title: PM-KISAN పథకం 2024-25
Link: https://pmkisan.gov.in
Snippet: అన్ని రైతులకు సంవత్సరానికి ₹6000 - మూడు వాయిదాలుగా ₹2000 చొప్పున.
'''
      }
    };

    return allSchemes[locale] ?? allSchemes['hindi']!;
  }

  /// Get fallback response when AI fails based on locale
  String _getFallbackResponse(String query, String locale) {
    Map<String, String> fallbackResponses = {
      'hindi': '''
**माफ करें, तकनीकी समस्या के कारण विस्तृत जानकारी नहीं मिल सकी।**

**सामान्य सुझाव:**
1. अपने जिले के कृषि कार्यालय में जाएं
2. किसान कॉल सेंटर पर कॉल करें: 1800-180-1551
3. PM-KISAN पोर्टल देखें: https://pmkisan.gov.in

**मुख्य वेबसाइटें:**
- कृषि मंत्रालय: https://farmer.gov.in
- मिट्टी परीक्षण: https://soilhealth.dac.gov.in
- कृषि यंत्र: https://agrimachinery.nic.in

**संपर्क:**
- किसान कॉल सेंटर: 1800-180-1551
- कृषि सलाहकार हेल्पलाइन: 1800-3000-3468

कृपया फिर से पूछें या सीधे संपर्क करें।
''',
      'english': '''
**Sorry, detailed information could not be retrieved due to technical issues.**

**General Suggestions:**
1. Visit your district agriculture office
2. Call Farmer Call Center: 1800-180-1551
3. Check PM-KISAN portal: https://pmkisan.gov.in

**Main Websites:**
- Agriculture Ministry: https://farmer.gov.in
- Soil Testing: https://soilhealth.dac.gov.in
- Agriculture Machinery: https://agrimachinery.nic.in

**Contact:**
- Farmer Call Center: 1800-180-1551
- Agricultural Advisor Helpline: 1800-3000-3468

Please try again or contact directly.
''',
      'tamil': '''
**மன்னிக்கவும், தொழில்நுட்ப சிக்களால் விரிவான தகவல் பெற முடியவில்லை.**

**பொதுவான பரிந்துரைகள்:**
1. உங்கள் மாவட்ட விவசாய அலுவலகத்திற்கு செல்லுங்கள்
2. விவசாயி அழைப்பு மையத்தை அழைக்கவும்: 1800-180-1551
3. PM-KISAN போர்ட்டலைப் பார்க்கவும்: https://pmkisan.gov.in

**முக்கிய வலைதளங்கள்:**
- விவசாய அமைச்சகம்: https://farmer.gov.in
- மண் பரிசோதனை: https://soilhealth.dac.gov.in
- விவசாய இயந்திரங்கள்: https://agrimachinery.nic.in

**தொடர்பு:**
- விவசாயி அழைப்பு மையம்: 1800-180-1551
- விவசாய ஆலோசகர் ஹெல்ப்லைன்: 1800-3000-3468

தயவுசெய்து மீண்டும் முயற்சிக்கவும் அல்லது நேரடியாக தொடர்பு கொள்ளவும்.
''',
      'telugu': '''
**క్షమించండి, సాంకేతిక సమస్యల కారణంగా వివరణాత్మక సమాచారం పొందలేకపోయాము.**

**సాధారణ సూచనలు:**
1. మీ జిల్లా వ్యవసాయ కార్యాలయాన్ని సందర్శించండి
2. రైతు కాల్ సెంటర్‌కు కాల్ చేయండి: 1800-180-1551
3. PM-KISAN పోర్టల్ చూడండి: https://pmkisan.gov.in

**ప్రధాన వెబ్‌సైట్లు:**
- వ్యవసాయ మంత్రిత్వ శాఖ: https://farmer.gov.in
- నేల పరీక్ష: https://soilhealth.dac.gov.in
- వ్యవసాయ యంత్రాలు: https://agrimachinery.nic.in

**సంప్రదించండి:**
- రైతు కాల్ సెంటర్: 1800-180-1551
- వ్యవసాయ సలహాదారు హెల్ప్‌లైన్: 1800-3000-3468

దయచేసి మళ్లీ ప్రయత్నించండి లేదా నేరుగా సంప్రదించండి.
'''
    };

    return fallbackResponses[locale] ?? fallbackResponses['hindi']!;
  }

  /// Get default response when AI response is empty
  String _getDefaultResponse(String locale) {
    Map<String, String> defaultResponses = {
      'hindi': 'मुझे खुशी होगी आपकी मदद करने में। कृपया अपना सवाल फिर से पूछें।',
      'english': 'I would be happy to help you. Please ask your question again.',
      'tamil': 'உங்களுக்கு உதவ மகிழ்ச்சி அடைவேன். தயவுசெய்து உங்கள் கேள்வியை மீண்டும் கேளுங்கள்.',
      'telugu': 'మీకు సహాయం చేయడంలో నేను సంతోషిస్తాను. దయచేసి మీ ప్రశ్నను మళ్లీ అడగండి.'
    };

    return defaultResponses[locale] ?? defaultResponses['hindi']!;
  }

  /// Analyze text sentiment (for farmer satisfaction)
  Future<Map<String, dynamic>> analyzeSentiment(String text) async {
    try {
      final response = await _dio.post(
        'https://language.googleapis.com/v1/documents:analyzeSentiment?key=$_geminiApiKey',
        data: {
          'document': {
            'content': text,
            'type': 'PLAIN_TEXT',
            'language': 'hi', // Hindi
          },
          'encodingType': 'UTF8',
        },
      );

      if (response.statusCode == 200) {
        return response.data;
      }
    } catch (e) {
      print('Sentiment analysis error: $e');
    }

    return {
      'documentSentiment': {
        'score': 0.0,
        'magnitude': 0.0,
      }
    };
  }

  /// Generate follow-up questions for farmers based on locale
  List<String> generateFollowUpQuestions(String query, {String locale = 'hindi'}) {
    Map<String, List<String>> generalQuestions = {
      'hindi': [
        'इस योजना के लिए क्या दस्तावेज चाहिए?',
        'आवेदन की अंतिम तारीख क्या है?',
        'कितनी सब्सिडी मिल सकती है?',
        'आवेदन कहां करना होगा?',
        'और कौन सी योजनाएं हैं?',
      ],
      'english': [
        'What documents are needed for this scheme?',
        'What is the application deadline?',
        'How much subsidy can I get?',
        'Where should I apply?',
        'What other schemes are available?',
      ],
      'tamil': [
        'இந்த திட்டத்திற்கு என்ன ஆவணங்கள் தேவை?',
        'விண்ணப்பத்தின் கடைசி தேதி என்ன?',
        'எவ்வளவு மானியம் கிடைக்கும்?',
        'எங்கே விண்ணப்பிக்க வேண்டும்?',
        'வேறு என்ன திட்டங்கள் உள்ளன?',
      ],
      'telugu': [
        'ఈ పథకానికి ఏ పత్రాలు అవసరం?',
        'దరఖాస్తు చివరి తేదీ ఎప్పుడు?',
        'ఎంత రాయితీ పొందవచ్చు?',
        'ఎక్కడ దరఖాస్తు చేసుకోవాలి?',
        'ఇంకా ఏ పథకాలు ఉన్నాయి?',
      ]
    };

    Map<String, List<String>> loanQuestions = {
      'hindi': [
        'ब्याज दर क्या है?',
        'कितना लोन मिल सकता है?',
        'गारंटी की जरूरत है क्या?',
        'EMI कैसे भरना होगा?',
        'और भी लोन योजनाएं हैं क्या?',
      ],
      'english': [
        'What is the interest rate?',
        'How much loan can I get?',
        'Is guarantee required?',
        'How to pay EMI?',
        'Are there other loan schemes?',
      ],
      'tamil': [
        'வட்டி விகிதம் என்ன?',
        'எவ்வளவு கடன் கிடைக்கும்?',
        'உத்தரவாதம் தேவையா?',
        'EMI எப்படி செலுத்துவது?',
        'வேறு கடன் திட்டங்கள் உள்ளனவா?',
      ],
      'telugu': [
        'వడ్డీ రేటు ఎంత?',
        'ఎంత రుణం పొందవచ్చు?',
        'గ్యారెంటీ అవసరమా?',
        'EMI ఎలా చెల్లించాలి?',
        'ఇతర రుణ పథకాలు ఉన్నాయా?',
      ]
    };

    String lowerQuery = query.toLowerCase();
    List<String> questions;

    if (lowerQuery.contains('loan') || lowerQuery.contains('ऋण') || lowerQuery.contains('கடன்') || lowerQuery.contains('రుణం')) {
      questions = loanQuestions[locale] ?? loanQuestions['hindi']!;
    } else {
      questions = generalQuestions[locale] ?? generalQuestions['hindi']!;
    }

    return questions..shuffle();
  }

  /// Remove markdown stars and replace with appropriate emojis
  String _removeStarsAndAddEmojis(String response, String locale) {
    Map<String, Map<String, String>> emojiReplacements = {
      'hindi': {
        '**मुख्य जानकारी:**': '🌾 मुख्य जानकारी:',
        '**आवेदन कैसे करें:**': '📝 आवेदन कैसे करें:',
        '**जरूरी लिंक:**': '🔗 जरूरी लिंक:',
        '**संपर्क:**': '📞 संपर्क:',
        '**अतिरिक्त सुझाव:**': '💡 अतिरिक्त सुझाव:',
        '**सामान्य सुझाव:**': '💡 सामान्य सुझाव:',
        '**लाभ:**': '💰 लाभ:',
        '**पात्रता:**': '✅ पात्रता:',
        '**दस्तावेज:**': '📄 दस्तावेज:',
      },
      'english': {
        '**Key Information:**': '🌾 Key Information:',
        '**How to Apply:**': '📝 How to Apply:',
        '**Important Links:**': '🔗 Important Links:',
        '**Contact:**': '📞 Contact:',
        '**Additional Tips:**': '💡 Additional Tips:',
        '**Benefits:**': '💰 Benefits:',
        '**Eligibility:**': '✅ Eligibility:',
        '**Documents:**': '📄 Documents:',
      },
      'tamil': {
        '**முக்கிய தகவல்:**': '🌾 முக்கிய தகவல்:',
        '**எப்படி விண்ணப்பிப்பது:**': '📝 எப்படி விண்ணப்பிப்பது:',
        '**முக்கிய இணைப்புகள்:**': '🔗 முக்கிய இணைப்புகள்:',
        '**தொடர்பு:**': '📞 தொடர்பு:',
        '**கூடுதல் ஆலோசனைகள்:**': '💡 கூடுதல் ஆலோசனைகள்:',
        '**பலன்கள்:**': '💰 பலன்கள்:',
        '**தகுதி:**': '✅ தகுதி:',
        '**ஆவணங்கள்:**': '📄 ஆவணங்கள்:',
      },
      'telugu': {
        '**ప్రధాన సమాచారం:**': '🌾 ప్రధాన సమాచారం:',
        '**ఎలా దరఖాస్తు చేసుకోవాలి:**': '📝 ఎలా దరఖాస్తు చేసుకోవాలి:',
        '**ముఖ్యమైన లింకులు:**': '🔗 ముఖ్యమైన లింకులు:',
        '**సంప్రదింపు:**': '📞 సంప్రదింపు:',
        '**అదనపు సలహాలు:**': '💡 అదనపు సలహాలు:',
        '**ప్రయోజనాలు:**': '💰 ప్రయోజనాలు:',
        '**అర్హత:**': '✅ అర్హత:',
        '**పత్రాలు:**': '📄 పత్రాలు:',
      }
    };

    Map<String, String> localeReplacements = emojiReplacements[locale] ?? emojiReplacements['hindi']!;
    
    // Replace markdown headers with emoji versions
    for (String key in localeReplacements.keys) {
      response = response.replaceAll(key, localeReplacements[key]!);
    }
    
    // Remove ALL remaining stars (both ** and *)
    response = response.replaceAll('**', '');
    response = response.replaceAll('*', '');
    
    // Replace numbered lists with bullet emojis
    response = response.replaceAll(RegExp(r'^(\d+)\.\s'), '🔸 ');
    response = response.replaceAll(RegExp(r'\n(\d+)\.\s'), '\n🔸 ');
    
    // Replace bullet points with emojis
    response = response.replaceAll('• ', '🔸 ');
    response = response.replaceAll('- ', '🔸 ');
    
    // Clean up URLs
    response = _cleanupUrls(response);
    
    return response;
  }

  String _cleanupUrls(String text) {
    // Remove markdown link formatting [text](url) and keep just the URL
    text = text.replaceAllMapped(RegExp(r'\[([^\]]+)\]\(([^)]+)\)'), (match) {
      return match.group(2) ?? match.group(0)!; // Return the URL part (second group)
    });
    
    // Clean up URLs that have extra characters or formatting
    text = text.replaceAllMapped(RegExp(r'https?://[^\s)}\]]+(?:\([^)]*\))*[^\s)}\]]*'), (match) {
      String url = match.group(0)!;
      // Remove trailing punctuation that's not part of the URL
      url = url.replaceAll(RegExp(r'[,;:!?.]*$'), '');
      return url;
    });
    
    // Remove any ** or * that might be around URLs using replaceAllMapped
    text = text.replaceAllMapped(RegExp(r'\*+([^\*]+)\*+'), (match) {
      return match.group(1) ?? match.group(0)!; // Return the content without stars
    });
    
    return text;
  }
}