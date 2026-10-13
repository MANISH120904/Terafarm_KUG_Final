import 'package:flutter/material.dart';
import '../pages/scheme_chatbot_page.dart' as chatbot;

class SchemeChatbotWidget extends StatefulWidget {
  const SchemeChatbotWidget({Key? key}) : super(key: key);

  @override
  State<SchemeChatbotWidget> createState() => _SchemeChatbotWidgetState();
}

class _SchemeChatbotWidgetState extends State<SchemeChatbotWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _startPulseAnimation();
  }

  void _startPulseAnimation() {
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openSchemeChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const chatbot.SchemeChatbotPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: FloatingActionButton.extended(
              heroTag: "scheme_chatbot",
              onPressed: _openSchemeChatbot,
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.support_agent),
              label: const Text(
                'Scheme\nAssistant',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  height: 1.1,
                ),
                textAlign: TextAlign.center,
              ),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        },
      ),
    );
  }
}