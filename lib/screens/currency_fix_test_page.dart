import 'package:flutter/material.dart';
import '../services/scheme_chatbot_service.dart';

class CurrencyFixTestPage extends StatefulWidget {
  @override
  _CurrencyFixTestPageState createState() => _CurrencyFixTestPageState();
}

class _CurrencyFixTestPageState extends State<CurrencyFixTestPage> {
  final SchemeChatbotService _chatbotService = SchemeChatbotService();
  String testResult = '';

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  void _runTest() {
    final result = _chatbotService.testCurrencyFixes();
    setState(() {
      testResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Currency Fix Test'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Currency Placeholder Fix Test Results:',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                testResult.isEmpty ? 'Running test...' : testResult,
                style: TextStyle(fontSize: 14),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _runTest,
              child: Text('Run Test Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}