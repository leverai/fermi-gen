import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/pa_card.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Define the light theme specifically for testing since we might not have the full provider setup
    final lightTheme = ThemeData(
      useMaterial3: true,
      extensions: [
        AppTheme.lightTheme(),
        const AppFont(),
      ],
    );

    return MaterialApp(
      title: 'Achievement Cards Preview',
      theme: lightTheme,
      home: const AchievementPreviewScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AchievementPreviewScreen extends StatelessWidget {
  const AchievementPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.lightTheme();

    return Scaffold(
      backgroundColor: appTheme.bgDark,
      appBar: AppBar(
        title: Text(
          'Percentile Achievements',
          style: AppFont.primaryTextStyle(context,
              color: appTheme.text, fontWeight: FontWeight.bold),
        ),
        backgroundColor: appTheme.bg,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: const [
          SizedBox(height: 20),
          _SectionHeader(title: 'Top 1% (99+)'),
          PACard(
            percentile: 99.5,
            questionText: 'How many piano tuners are there in Chicago?',
            userAnswer: '200',
            correctAnswer: '290',
          ),
          SizedBox(height: 20),
          _SectionHeader(title: 'Top 5% (95-99)'),
          PACard(
            percentile: 96.0,
            questionText: 'What is the mass of the sun in kg?',
            userAnswer: '2e30',
            correctAnswer: '1.989e30',
          ),
          SizedBox(height: 20),
          _SectionHeader(title: 'Top 10% (90-95)'),
          PACard(
            percentile: 92.5,
            questionText: 'Number of atoms in a grain of sand?',
            userAnswer: '1e19',
            correctAnswer: '4e19',
          ),
          SizedBox(height: 20),
          _SectionHeader(title: 'Bottom 10% (5-10)'),
          PACard(
            percentile: 8.0,
            questionText: 'How many cups of coffee are drunk daily in NYC?',
            userAnswer: '500',
            correctAnswer: '3,000,000',
          ),
          SizedBox(height: 20),
          _SectionHeader(title: 'Bottom 5% (1-5)'),
          PACard(
            percentile: 4.5,
            questionText: 'Population of Mars?',
            userAnswer: '1,000,000',
            correctAnswer: '0',
          ),
          SizedBox(height: 20),
          _SectionHeader(title: 'Bottom 1% (0-1)'),
          PACard(
            percentile: 0.2,
            questionText: 'How many ants are on Earth?',
            userAnswer: '100',
            correctAnswer: '20e15',
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }
}
