import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/scheme_chatbot_service.dart';
import '../services/enhanced_ai_service.dart';
import '../services/youtube_service.dart';
import '../widgets/youtube_video_widget.dart';
import '../models/scheme_model.dart';

class SchemeChatbotPage extends StatefulWidget {
  const SchemeChatbotPage({Key? key}) : super(key: key);

  @override
  State<SchemeChatbotPage> createState() => _SchemeChatbotPageState();
}

class _SchemeChatbotPageState extends State<SchemeChatbotPage>
    with TickerProviderStateMixin {
  final SchemeChatbotService _chatbotService = SchemeChatbotService();
  final EnhancedAIService _enhancedAIService = EnhancedAIService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  Map<String, String> _collectedFarmerInfo = {};
  
  // Form controllers for farmer details
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _customCropController = TextEditingController();
  String? _selectedFarmSize;
  String? _selectedIncomeRange;
  List<String> _selectedCrops = [];
  bool _showFarmerForm = false;

  // Enhanced authentication and profile management
  User? _currentUser;
  Map<String, dynamic>? _userProfile;
  bool _profileLoaded = false;

  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _initializeAuthAndChat();
  }

  Future<void> _initializeAuthAndChat() async {
    // Setup authentication state listener
    _setupAuthListener();
    
    // Get current user
    _currentUser = FirebaseAuth.instance.currentUser;
    
    // Load user profile if user is authenticated
    if (_currentUser != null) {
      await _loadUserProfile();
    }
    
    _initializeChat();
  }

  Future<void> _loadUserProfile() async {
    if (_currentUser == null) return;
    
    try {
      _userProfile = await _chatbotService.getUserProfile(_currentUser!.uid);
      _profileLoaded = true;
      
      if (_userProfile != null) {
        // Pre-populate form with existing profile data
        _locationController.text = _userProfile!['location'] ?? '';
        _selectedFarmSize = _userProfile!['farmSize'];
        _selectedIncomeRange = _userProfile!['incomeRange'];
        
        // Handle crops list
        if (_userProfile!['crops'] is List) {
          _selectedCrops = List<String>.from(_userProfile!['crops']);
        } else if (_userProfile!['crops'] is String) {
          _selectedCrops = _userProfile!['crops'].split(', ');
        }
        
        // Don't show farmer form if profile already exists
        _showFarmerForm = false;
        
        setState(() {});
        
        print('✅ Loaded existing profile for ${_currentUser!.uid}');
      } else {
        // Show farmer form if no profile exists
        _showFarmerForm = true;
        print('ℹ️ No existing profile found, showing farmer form');
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
      _showFarmerForm = true; // Show form on error
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _animationController.dispose();
    _locationController.dispose();
    _customCropController.dispose();
    super.dispose();
  }

  void _initializeChat() {
    // Use a post-frame callback to ensure the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Start with a greeting message that requests farmer info
      String? locale;
      try {
        locale = Localizations.localeOf(context).toString();
      } catch (e) {
        locale = 'hi_IN'; // Default to Hindi if locale access fails
      }
      
      final greeting = _chatbotService.getInitialGreeting(locale: locale);
      
      setState(() {
        _messages.add(greeting);
        // Show farmer form only if user doesn't have a profile
        if (_userProfile == null && !_profileLoaded) {
          _showFarmerForm = true;
        }
      });
      
      _animationController.forward();
      _scrollToBottom();
    });
  }

  /// Handle authentication state changes
  void _setupAuthListener() {
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (mounted) {
        setState(() {
          _currentUser = user;
        });
        
        if (user != null) {
          _loadUserProfile();
        } else {
          _userProfile = null;
          _profileLoaded = false;
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: message,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isLoading = true;
    });

    _messageController.clear();
    _scrollToBottom();

    try {
      // Extract farmer info from the message
      final extractedInfo = _chatbotService.extractFarmerInfo(message);
      _collectedFarmerInfo.addAll(extractedInfo);

      // Get AI response using enhanced RAG with user profile
      String? locale;
      try {
        locale = Localizations.localeOf(context).toString();
      } catch (e) {
        locale = 'hi_IN'; // Default to Hindi if locale access fails
      }

      String languageCode = _getLanguageFromLocale(locale);
      
      // Use enhanced AI service to get response with YouTube videos
      Map<String, dynamic> enhancedResponse = await _enhancedAIService.generateEnhancedResponseWithVideos(
        message,
        userProfile: _userProfile?.toString(),
        locale: languageCode,
      );

      String responseContent = enhancedResponse['text'] ?? 'Sorry, I could not generate a response.';
      List<YouTubeVideo> videos = enhancedResponse['videos'] ?? [];

      print('🎥 Generated response with ${videos.length} videos');
      for (var video in videos) {
        print('📺 Video: ${video.title} - ${video.youtubeUrl}');
      }

      // Create ChatMessage from the response content
      final response = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: responseContent,
        isUser: false,
        timestamp: DateTime.now(),
        videos: videos.cast<dynamic>(), // Cast to dynamic list for storage
      );

      setState(() {
        _messages.add(response);
        _isLoading = false;
      });

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: "Sorry, I encountered an error. Please try again.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF16A34A),
        title: const Row(
          children: [
            Icon(Icons.chat_bubble, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Scheme Assistant',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Profile status indicator
          if (_currentUser != null && _profileLoaded && _userProfile != null)
            IconButton(
              icon: const Icon(Icons.account_circle, color: Colors.white),
              onPressed: () => _showProfileDialog(),
              tooltip: 'View Profile',
            ),
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Personalized RAG Status Indicator
          if (_currentUser != null && _userProfile != null)
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF16A34A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF16A34A).withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.smart_toy, size: 16, color: Color(0xFF16A34A)),
                  SizedBox(width: 4),
                  Text(
                    'Personalized AI Active',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF16A34A),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

          // Chat Area
          Expanded(
            child: AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, 20 * (1 - _slideAnimation.value)),
                  child: Opacity(
                    opacity: _slideAnimation.value,
                    child: child,
                  ),
                );
              },
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return _buildTypingIndicator();
                  }
                  
                  final message = _messages[index];
                  return _buildMessageBubble(message);
                },
              ),
            ),
          ),
          
          // Farmer Form (if shown)
          if (_showFarmerForm) _buildFarmerForm(),
          
          // Input Area
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser)
            Container(
              margin: const EdgeInsets.only(right: 8),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF16A34A),
                child: Icon(Icons.support_agent, color: Colors.white, size: 16),
              ),
            ),
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isUser 
                    ? const Color(0xFF16A34A) 
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMessageContent(message.content, message.isUser),
                  
                  // Show YouTube videos if available
                  if (!message.isUser && message.videos != null && message.videos!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Builder(
                      builder: (context) {
                        print('🎬 Displaying ${message.videos!.length} videos in message');
                        // Debug: Check video types
                        for (int i = 0; i < message.videos!.length; i++) {
                          var video = message.videos![i];
                          print('🔍 Video $i type: ${video.runtimeType}');
                          if (video is YouTubeVideo) {
                            print('✅ Video $i is YouTubeVideo: ${video.title}');
                          } else {
                            print('❌ Video $i is not YouTubeVideo: $video');
                          }
                        }
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.video_library, 
                                    color: Colors.red, 
                                    size: 16
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Tutorial Videos (${message.videos!.length})',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Column(
                                children: message.videos!
                                    .where((video) => video is YouTubeVideo)
                                    .cast<YouTubeVideo>()
                                    .take(2) // Show max 2 videos
                                    .map((video) {
                                      print('🎯 Creating chip for video: ${video.title}');
                                      return Container(
                                        margin: const EdgeInsets.symmetric(vertical: 4),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.play_circle_filled, color: Colors.red, size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    video.title,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  if (video.channelTitle.isNotEmpty)
                                                    Text(
                                                      video.channelTitle,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        color: Colors.grey.shade600,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                ],
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => _launchURL(video.youtubeUrl),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Text(
                                                  'Watch',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                                    .toList(),
                              ),
                            ],
                          ),
                        );
                      }
                    ),
                  ],
                  
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 10,
                      color: message.isUser 
                          ? Colors.white.withOpacity(0.7)
                          : Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          if (message.isUser)
            Container(
              margin: const EdgeInsets.only(left: 8),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF6B7280),
                child: Icon(Icons.person, color: Colors.white, size: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(String content, bool isUser) {
    // Enhanced content with clickable elements
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (String line in lines) {
      // Check for URLs (including enhanced AI formatted URLs)
      final urlRegex = RegExp(r'https?://[^\s\]\*\)]+');
      final phoneRegex = RegExp(r'\b(?:1800-)?[\d-]{10,15}\b');
      
      if (urlRegex.hasMatch(line) || phoneRegex.hasMatch(line)) {
        widgets.add(_buildInteractiveText(line, isUser));
      } else {
        widgets.add(
          Text(
            line,
            style: TextStyle(
              color: isUser ? Colors.white : Colors.black87,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        );
      }
      
      if (line != lines.last) {
        widgets.add(const SizedBox(height: 4));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildInteractiveText(String text, bool isUser) {
    final urlRegex = RegExp(r'https?://[^\s\]\*\)]+');
    final phoneRegex = RegExp(r'\b\d{10,12}\b');
    
    return RichText(
      text: TextSpan(
        style: TextStyle(
          color: isUser ? Colors.white : Colors.black87,
          fontSize: 14,
          height: 1.4,
        ),
        children: _buildTextSpans(text, urlRegex, phoneRegex, isUser),
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String text, RegExp urlRegex, RegExp phoneRegex, bool isUser) {
    final spans = <TextSpan>[];
    final allMatches = <MapEntry<int, String>>[];
    
    // Find all URLs (including enhanced AI formatted ones)
    for (final match in urlRegex.allMatches(text)) {
      allMatches.add(MapEntry(match.start, match.group(0)!));
    }
    
    // Find all phone numbers (including toll-free numbers)
    for (final match in phoneRegex.allMatches(text)) {
      allMatches.add(MapEntry(match.start, match.group(0)!));
    }
    
    // Sort by position
    allMatches.sort((a, b) => a.key.compareTo(b.key));
    
    int lastEnd = 0;
    
    for (final match in allMatches) {
      // Add text before match
      if (match.key > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.key)));
      }
      
      // Add interactive element
      final matchText = match.value;
      spans.add(
        TextSpan(
          text: matchText,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF2563EB),
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w500,
          ),
          recognizer: _createTapRecognizer(matchText),
        ),
      );
      
      lastEnd = match.key + matchText.length;
    }
    
    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }
    
    return spans;
  }

  dynamic _createTapRecognizer(String text) {
    // Clean the text and extract URL
    String cleanText = text
        .replaceAll('🔗', '')
        .replaceAll('**', '')
        .trim();
    
    // Extract URL from the text
    final urlMatch = RegExp(r'https?://[^\s\]\*\)]+').firstMatch(cleanText);
    String? cleanUrl;
    
    if (urlMatch != null) {
      cleanUrl = urlMatch.group(0)!;
      // URL - launch in browser
      return TapGestureRecognizer()
        ..onTap = () async {
          await _launchURL(cleanUrl!);
        };
    } else if (RegExp(r'\b(?:1800-)?[\d-]{10,15}\b').hasMatch(text)) {
      // Phone number (including toll-free) - launch dialer
      return TapGestureRecognizer()
        ..onTap = () async {
          // Clean the phone number for tel: URL
          String cleanPhone = text.replaceAll(RegExp(r'[^\d]'), '');
          await _launchURL('tel:+91$cleanPhone');
        };
    }
    return null;
  }

  Future<void> _launchURL(String url) async {
    try {
      print('🔗 Attempting to launch: $url');
      final Uri uri = Uri.parse(url);
      
      bool launched = false;
      
      // Try multiple launch modes for better compatibility
      final List<LaunchMode> modes = [
        LaunchMode.externalApplication,
        LaunchMode.platformDefault,
        LaunchMode.inAppWebView,
      ];
      
      for (LaunchMode mode in modes) {
        try {
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: mode);
            launched = true;
            print('✅ Successfully launched with mode: $mode');
            
            // Show success feedback
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('🔗 Opening: ${url.length > 40 ? '${url.substring(0, 40)}...' : url}'),
                  duration: const Duration(seconds: 2),
                  backgroundColor: const Color(0xFF16A34A),
                ),
              );
            }
            break;
          }
        } catch (e) {
          print('❌ Failed with mode $mode: $e');
          continue;
        }
      }
      
      // If all launch modes failed, provide copy-to-clipboard option
      if (!launched) {
        print('❌ All launch methods failed for: $url');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to open link. Tap to copy: ${url.length > 30 ? '${url.substring(0, 30)}...' : url}'),
              duration: const Duration(seconds: 5),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Copy URL',
                textColor: Colors.white,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: url));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Link copied to clipboard'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Color(0xFF16A34A),
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
      
    } catch (e) {
      print('❌ Critical error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error opening link. Tap to copy URL.'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Copy',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Link copied to clipboard'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Color(0xFF16A34A),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }

  Widget _buildTypingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFF16A34A),
            child: Icon(Icons.support_agent, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (int i = 0; i < 3; i++)
                  Container(
                    margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 0.5 + 0.5 * 
                              ((_animationController.value + i * 0.3) % 1.0),
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6B7280),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white),
              onPressed: _isLoading ? null : _sendMessage,
            ),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enhanced Scheme Assistant'),
        content: const Text(
          'This intelligent assistant uses advanced AI to help you find government schemes for farmers. '
          'With personalized RAG (Retrieval-Augmented Generation), you get:\n\n'
          '• Personalized scheme recommendations\n'
          '• Location-based eligibility checking\n'
          '• Real-time agricultural document analysis\n'
          '• Multi-language support\n\n'
          'Your profile helps provide more accurate and relevant suggestions.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showProfileDialog() {
    if (_userProfile == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.account_circle, color: Color(0xFF16A34A)),
            SizedBox(width: 8),
            Text('Your Farming Profile'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileItem('📍 Location', _userProfile!['location'] ?? 'Not specified'),
              const SizedBox(height: 8),
              _buildProfileItem('🏞️ Farm Size', _userProfile!['farmSize'] ?? 'Not specified'),
              const SizedBox(height: 8),
              _buildProfileItem('🌾 Crops', _userProfile!['crops'] is List 
                  ? (_userProfile!['crops'] as List).join(', ') 
                  : _userProfile!['crops'] ?? 'Not specified'),
              const SizedBox(height: 8),
              _buildProfileItem('💰 Income Range', _userProfile!['incomeRange'] ?? 'Not specified'),
              const SizedBox(height: 8),
              _buildProfileItem('📏 Land Area', '${_userProfile!['landArea'] ?? 'Unknown'} acres'),
              const SizedBox(height: 16),
              const Text(
                '🚀 Your profile enables personalized scheme recommendations!',
                style: TextStyle(
                  color: Color(0xFF16A34A),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _showFarmerForm = true;
              });
            },
            child: const Text('Edit Profile'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
           '${timestamp.minute.toString().padLeft(2, '0')}';
  }

  /// Convert locale to language code for enhanced RAG
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
        return 'hindi'; // Default fallback
    }
  }

  Widget _buildFarmerForm() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            children: [
              Icon(Icons.agriculture, color: Color(0xFF16A34A), size: 24),
              SizedBox(width: 8),
              Text(
                'Farmer Profile Setup',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Please fill in your details for personalized scheme recommendations',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 20),
          
          // Location Field
          const Text(
            '📍 Location (State/District)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _locationController,
            decoration: InputDecoration(
              hintText: 'e.g., Maharashtra, Pune',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF16A34A)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          
          // Farm Size Dropdown
          const Text(
            '🏞️ Farm Size',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedFarmSize,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF16A34A)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: const Text('Select farm size'),
            items: const [
              DropdownMenuItem(value: 'small', child: Text('Small (1-2 acres)')),
              DropdownMenuItem(value: 'medium', child: Text('Medium (3-10 acres)')),
              DropdownMenuItem(value: 'large', child: Text('Large (10+ acres)')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedFarmSize = value;
              });
            },
          ),
          const SizedBox(height: 16),
          
          // Crops Selection
          const Text(
            '🌾 Crops You Grow',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCropChip('Rice'),
              _buildCropChip('Wheat'),
              _buildCropChip('Corn'),
              _buildCropChip('Vegetables'),
              _buildCropChip('Fruits'),
              _buildCropChip('Cotton'),
              _buildCropChip('Sugarcane'),
              _buildCropChip('Others'),
            ],
          ),
          if (_selectedCrops.contains('Others')) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customCropController,
              decoration: InputDecoration(
                hintText: 'Specify other crops...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF16A34A)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
          const SizedBox(height: 16),
          
          // Income Range Dropdown
          const Text(
            '💰 Annual Income Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedIncomeRange,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF16A34A)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            hint: const Text('Select income range'),
            items: const [
              DropdownMenuItem(value: 'below_2', child: Text('Below ₹2 lakhs')),
              DropdownMenuItem(value: '2_5', child: Text('₹2-5 lakhs')),
              DropdownMenuItem(value: '5_10', child: Text('₹5-10 lakhs')),
              DropdownMenuItem(value: 'above_10', child: Text('Above ₹10 lakhs')),
            ],
            onChanged: (value) {
              setState(() {
                _selectedIncomeRange = value;
              });
            },
          ),
          const SizedBox(height: 20),
          
          // Submit Button
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _submitFarmerProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Save Profile & Start Chat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showFarmerForm = false;
                  });
                },
                child: const Text(
                  'Skip',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCropChip(String crop) {
    final isSelected = _selectedCrops.contains(crop);
    return FilterChip(
      label: Text(
        crop,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF374151),
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          if (selected) {
            _selectedCrops.add(crop);
          } else {
            _selectedCrops.remove(crop);
          }
        });
      },
      backgroundColor: Colors.grey.shade100,
      selectedColor: const Color(0xFF16A34A),
      checkmarkColor: Colors.white,
    );
  }

  Future<void> _submitFarmerProfile() async {
    // Basic validation
    String validationMessage = '';
    
    if (_locationController.text.trim().isEmpty) {
      validationMessage += '• Please enter your location\n';
    }
    
    if (_selectedFarmSize == null) {
      validationMessage += '• Please select your farm size\n';
    }
    
    if (_selectedCrops.isEmpty) {
      validationMessage += '• Please select at least one crop\n';
    }
    
    if (_selectedIncomeRange == null) {
      validationMessage += '• Please select your income range\n';
    }
    
    if (validationMessage.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete the following:\n$validationMessage'),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Prepare profile data for enhanced system
    final profileData = {
      'location': _locationController.text.trim(),
      'farmSize': _selectedFarmSize ?? '',
      'crops': _selectedCrops + 
               (_selectedCrops.contains('Others') && _customCropController.text.isNotEmpty 
                ? [_customCropController.text.trim()] : []),
      'incomeRange': _selectedIncomeRange ?? '',
      'landArea': _getLandAreaFromSize(_selectedFarmSize),
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };

    // Save profile using enhanced methods
    bool profileSaved = false;
    if (_currentUser != null) {
      try {
        profileSaved = await _chatbotService.savePersonalizedProfile(
          _currentUser!.uid, 
          profileData
        );
        
        if (profileSaved) {
          _userProfile = profileData;
          _profileLoaded = true;
          print('✅ Enhanced profile saved for ${_currentUser!.uid}');
        }
      } catch (e) {
        print('❌ Error saving enhanced profile: $e');
      }
    }

    // Collect farmer information for backward compatibility
    _collectedFarmerInfo = {
      'location': _locationController.text.trim(),
      'farm_size': _selectedFarmSize ?? '',
      'crops': _selectedCrops.join(', ') + 
               (_selectedCrops.contains('Others') && _customCropController.text.isNotEmpty 
                ? ', ${_customCropController.text.trim()}' : ''),
      'income_range': _selectedIncomeRange ?? '',
    };

    // Hide the form and add a confirmation message
    setState(() {
      _showFarmerForm = false;
      _messages.add(ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: profileSaved 
            ? "✅ Excellent! I've saved your personalized farming profile to our enhanced system:\n\n📍 Location: ${_collectedFarmerInfo['location']}\n🏞️ Farm Size: ${_collectedFarmerInfo['farm_size']}\n🌾 Crops: ${_collectedFarmerInfo['crops']}\n💰 Income: ${_collectedFarmerInfo['income_range']}\n\n🚀 Now you'll get intelligent, personalized scheme recommendations based on your specific farming profile and location. Ask me about any government schemes!"
            : "✅ Great! I've saved your farming profile:\n\n📍 Location: ${_collectedFarmerInfo['location']}\n🏞️ Farm Size: ${_collectedFarmerInfo['farm_size']}\n🌾 Crops: ${_collectedFarmerInfo['crops']}\n💰 Income: ${_collectedFarmerInfo['income_range']}\n\nNow you can ask me about any government schemes, and I'll provide personalized recommendations based on your details!",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });

    _scrollToBottom();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(profileSaved 
            ? '✅ Enhanced profile saved successfully!' 
            : '✅ Profile saved successfully!'),
        backgroundColor: const Color(0xFF16A34A),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Convert farm size to approximate land area for enhanced profile
  double _getLandAreaFromSize(String? farmSize) {
    switch (farmSize) {
      case 'small':
        return 1.5; // Average of 1-2 acres
      case 'medium':
        return 6.5; // Average of 3-10 acres
      case 'large':
        return 15.0; // 15+ acres
      default:
        return 2.0; // Default small farm
    }
  }
}