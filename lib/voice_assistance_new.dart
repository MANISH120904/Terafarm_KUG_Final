import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:provider/provider.dart';

// Import the necessary pages for navigation
import 'dashboard_page.dart';
import 'plant_growth_analysis_page.dart';
import 'crop_suggestion_page.dart';
import 'list_farm_page.dart';
import 'grow_plant_page.dart';
import 'Community_page.dart';
import 'ai_page.dart';
import 'config/api_keys.dart';

// 1. Voice Assistant State Management
class VoiceAssistantState with ChangeNotifier {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  late final GenerativeModel _model;

  bool _isListening = false;
  String _lastWords = '';
  String _status = "Idle";
  BuildContext? _currentContext;

  bool get isListening => _isListening;
  String get lastWords => _lastWords;
  String get status => _status;

  VoiceAssistantState() {
    _init();
  }

  void _init() async {
    // Initialize Gemini with a proper API key
    _model = GenerativeModel(
      model: 'gemini-3-flash-preview',
      apiKey: ApiKeys.gemini,
    );
    
    await _speechToText.initialize(
      onError: (error) => _updateStatus("STT Error: $error"),
      onStatus: (status) => print('STT Status: $status'),
    );
    await _flutterTts.setLanguage("en-US");
    notifyListeners();
  }

  void _updateStatus(String newStatus) {
    _status = newStatus;
    notifyListeners();
  }

  void setContext(BuildContext context) {
    _currentContext = context;
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
    print("Processing command: $command");
    
    try {
      final prompt = '''You are an assistant for a farming app called TeraFarm. Your task is to understand the user's voice command and respond with a JSON object that the app can use to perform an action.

Available commands:
- Navigate to dashboard/farm: {"command": "navigate", "value": "dashboard"}
- Navigate to marketplace/market: {"command": "navigate", "value": "marketplace"}  
- Navigate to crop suggestions: {"command": "navigate", "value": "crop_suggestions"}
- Navigate to plant registration: {"command": "navigate", "value": "plant_registration"}
- Navigate to farm management: {"command": "navigate", "value": "farm_management"}
- Navigate to analysis/tasks: {"command": "navigate", "value": "analysis"}
- Navigate to AI tools: {"command": "navigate", "value": "ai_tools"}
- Navigate to community: {"command": "navigate", "value": "community"}
- Get farming advice: {"command": "advice", "value": "farming tips"}
- Ask about weather: {"command": "query", "value": "weather"}

User command: "$command"

Respond only with valid JSON, no other text.''';

      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);
      final actionText = response.text?.trim();
      
      if (actionText != null && actionText.isNotEmpty) {
        print("Gemini response: $actionText");
        _executeAction(actionText);
      } else {
        _fallbackToLocalProcessing(command);
      }
    } catch (e) {
      print("Gemini error: $e");
      _fallbackToLocalProcessing(command);
    }
  }

  void _fallbackToLocalProcessing(String command) {
    String lowerCommand = command.toLowerCase();
    print("Using fallback processing for: $command");
    
    if (lowerCommand.contains('dashboard') || lowerCommand.contains('farm')) {
      _executeAction('{"command": "navigate", "value": "dashboard"}');
    } else if (lowerCommand.contains('market')) {
      _executeAction('{"command": "navigate", "value": "marketplace"}');
    } else if (lowerCommand.contains('crop') || lowerCommand.contains('suggestion')) {
      _executeAction('{"command": "navigate", "value": "crop_suggestions"}');
    } else if (lowerCommand.contains('plant') || lowerCommand.contains('register')) {
      _executeAction('{"command": "navigate", "value": "plant_registration"}');
    } else if (lowerCommand.contains('analysis') || lowerCommand.contains('task')) {
      _executeAction('{"command": "navigate", "value": "analysis"}');
    } else if (lowerCommand.contains('ai') || lowerCommand.contains('tools')) {
      _executeAction('{"command": "navigate", "value": "ai_tools"}');
    } else if (lowerCommand.contains('community')) {
      _executeAction('{"command": "navigate", "value": "community"}');
    } else {
      _speak("I heard: $command. Try saying 'go to dashboard', 'open marketplace', or 'register plant'.");
    }
  }

  void _executeAction(String actionJson) {
    try {
      final action = jsonDecode(actionJson);
      final command = action['command'];
      final value = action['value'];

      print("Executing command: $command with value: $value");

      if (_currentContext == null) {
        _speak("I couldn't perform the action right now. Please try again.");
        _updateStatus("Idle");
        return;
      }

      switch (command) {
        case 'navigate':
          _handleNavigation(value, _currentContext!);
          break;
        case 'advice':
          _speak("Here are some farming tips: Water your plants regularly, check soil moisture, and monitor for pests.");
          break;
        case 'query':
          if (value == 'weather') {
            _speak("Please check the weather widget on your home page for current conditions.");
          } else {
            _speak("I can help with navigation and farming advice. What would you like to do?");
          }
          break;
        default:
          _speak("I understood your command, but I'm not sure how to help with that yet.");
      }
    } catch (e) {
      print("JSON Parse Error: $e");
      _speak("I had trouble understanding the response. Please try again.");
    } finally {
      _updateStatus("Idle");
    }
  }

  void _handleNavigation(String destination, BuildContext context) {
    try {
      switch (destination) {
        case 'dashboard':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const DashboardPage()));
          _speak("Opening your farm dashboard");
          break;
        case 'marketplace':
          // Navigate to marketplace - you might need to adjust this based on your app structure
          _speak("Opening marketplace");
          break;
        case 'crop_suggestions':
          Navigator.push(context, MaterialPageRoute(builder: (_) => CropSuggestionPage()));
          _speak("Opening crop suggestions");
          break;
        case 'plant_registration':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const GrowPlantPage()));
          _speak("Opening plant registration");
          break;
        case 'farm_management':
          Navigator.push(context, MaterialPageRoute(builder: (_) => ListFarmPage()));
          _speak("Opening farm management");
          break;
        case 'analysis':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PlantGrowthAnalysisPage()));
          _speak("Opening plant growth analysis");
          break;
        case 'ai_tools':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AIPage()));
          _speak("Opening AI tools");
          break;
        case 'community':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CommunityPage()));
          _speak("Opening community page");
          break;
        default:
          _speak("I'm not sure which page you want to visit.");
      }
    } catch (e) {
      print("Navigation error: $e");
      _speak("I had trouble navigating there. Please try again.");
    }
  }

  Future<void> _speak(String text) async {
    _updateStatus("Speaking...");
    await _flutterTts.speak(text);
    _updateStatus("Idle");
  }
}

// 2. Voice Assistant Widget
class VoiceAssistantWidget extends StatelessWidget {
  const VoiceAssistantWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceAssistantState(),
      child: Consumer<VoiceAssistantState>(
        builder: (context, state, child) {
          // Set the context so the voice assistant can navigate
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state.setContext(context);
          });
          
          return FloatingActionButton(
            onPressed: state.isListening ? state.stopListening : state.startListening,
            backgroundColor: state.isListening ? Colors.red : Theme.of(context).primaryColor,
            child: Icon(
              state.isListening ? Icons.mic : Icons.mic_none,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }
}
