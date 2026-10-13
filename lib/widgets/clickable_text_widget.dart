import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class ClickableTextWidget extends StatelessWidget {
  final String text;
  final TextStyle? textStyle;

  const ClickableTextWidget({
    Key? key,
    required this.text,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _buildTextSpans(context),
    );
  }

  List<Widget> _buildTextSpans(BuildContext context) {
    final List<Widget> widgets = [];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      // Check if line contains URLs
      final urlRegex = RegExp(r'https?://[^\s\]]+');
      final matches = urlRegex.allMatches(line);

      if (matches.isEmpty) {
        // No URLs, just add regular text
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Text(
              line,
              style: textStyle ?? const TextStyle(fontSize: 14),
            ),
          ),
        );
      } else {
        // Line contains URLs, create clickable text
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: _buildRichTextWithLinks(line, context),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildRichTextWithLinks(String line, BuildContext context) {
    final List<TextSpan> spans = [];
    final urlRegex = RegExp(r'https?://[^\s\]]+');
    int lastMatchEnd = 0;

    for (final match in urlRegex.allMatches(line)) {
      // Add text before the URL
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: line.substring(lastMatchEnd, match.start),
          style: textStyle ?? const TextStyle(fontSize: 14),
        ));
      }

      // Add the clickable URL
      final url = match.group(0)!;
      spans.add(TextSpan(
        text: '🔗 $url',
        style: const TextStyle(
          color: Colors.blue,
          decoration: TextDecoration.underline,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        recognizer: _createTapGestureRecognizer(url),
      ));

      lastMatchEnd = match.end;
    }

    // Add any remaining text after the last URL
    if (lastMatchEnd < line.length) {
      spans.add(TextSpan(
        text: line.substring(lastMatchEnd),
        style: textStyle ?? const TextStyle(fontSize: 14),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }

  _createTapGestureRecognizer(String url) {
    return TapGestureRecognizer()
      ..onTap = () async {
        await _launchURL(url);
      };
  }

  Future<void> _launchURL(String url) async {
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
}