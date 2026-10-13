# Voice Assistant Integration

## Overview
The voice assistant has been successfully integrated into the SellerPage using a floating action button. This allows farmers to interact with the app using voice commands.

## Integration Details

### SellerPage Integration
**File**: `lib/seller_page.dart`

#### Changes Made:
1. **Import Added**:
   ```dart
   import 'voice_assistance.dart';
   ```

2. **Floating Action Button Added**:
   ```dart
   Scaffold(
     // ... existing scaffold properties
     floatingActionButton: const VoiceAssistantWidget(),
   );
   ```

### Dependencies Required
The following packages are already included in `pubspec.yaml`:
- `speech_to_text: ^6.3.0` - For voice recognition
- `flutter_tts: ^3.8.3` - For text-to-speech output
- `http: ^1.1.0` - For API communication with Grok
- `provider: ^6.1.5` - For state management

### Voice Assistant Features

#### 1. Voice Commands Supported:
- **Navigation**: "Go to the weather page", "Show me my crops"
- **Queries**: "What is the price of tomatoes today?"
- **Actions**: "Add a new expense"

#### 2. User Interface:
- **Microphone Icon**: Tap to start listening
- **Red Color**: When actively listening
- **Green Color**: When idle/ready

#### 3. AI Processing:
- Uses Grok API for natural language understanding
- Converts voice to structured JSON commands
- Provides voice feedback to user

### Usage Flow

1. **User taps the floating microphone button**
2. **App starts listening** (icon turns red)
3. **User speaks a command** (e.g., "Show me my farm dashboard")
4. **App processes the command** with Grok AI
5. **App provides voice feedback** and executes the action

### Example Voice Commands

```text
User: "Go to the weather page"
System: "Understood. Performing action: navigate with value: weather"

User: "What is the price of tomatoes today?"
System: "Understood. Performing action: query with value: price of tomatoes"

User: "Add a new expense"
System: "Understood. Performing action: action with value: add_expense"
```

### Technical Implementation

#### VoiceAssistantWidget Structure:
```dart
class VoiceAssistantWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceAssistantState(),
      child: Consumer<VoiceAssistantState>(
        builder: (context, state, child) {
          return FloatingActionButton(
            onPressed: state.isListening 
              ? state.stopListeningAndProcess 
              : state.startListening,
            backgroundColor: state.isListening 
              ? Colors.red 
              : Theme.of(context).primaryColor,
            child: Icon(state.isListening 
              ? Icons.mic 
              : Icons.mic_none),
          );
        },
      ),
    );
  }
}
```

#### State Management:
- Uses Provider pattern for state management
- Manages listening state, TTS state, and API processing
- Provides real-time UI updates

### Next Steps for Full Integration

To make the voice assistant fully functional, you would need to:

1. **Connect to Navigation System**:
   ```dart
   if (command == 'navigate') {
     NavigationService.navigateToPage(context, getPageIndex(value), currentIndex);
   }
   ```

2. **Connect to App Features**:
   ```dart
   if (command == 'query' && value.contains('price')) {
     // Navigate to market price page
     // Fetch and speak current prices
   }
   ```

3. **Add More Command Types**:
   - Farm management commands
   - Weather queries
   - Crop suggestions
   - Market information

### Permissions Required

Make sure these permissions are added to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.INTERNET" />
```

The voice assistant is now ready to use in the SellerPage and can be easily extended with more farming-specific voice commands!
