import 'package:flutter/material.dart';
import 'package:fermi_frontend/screens/demo/answer_walkthrough_demo.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// Standalone entry point for testing the AnswerWalkthroughDemo.
/// Run with: flutter run lib/screens/demo/demo_main.dart
void main() {
  runApp(const DemoApp());
}

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Answer Walkthrough Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        extensions: [AppTheme.defaultTheme()],
        useMaterial3: true,
      ),
      home: const AnswerWalkthroughDemo(),
    );
  }
}
