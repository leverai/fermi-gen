import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/question_widget.dart';
import 'package:fermi_frontend/widgets/answer_accuracy_scale.dart';
import 'package:fermi_frontend/widgets/slider_text_mirror.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';

class DailyQuestionScreen extends StatefulWidget {
  const DailyQuestionScreen({super.key});

  @override
  State<DailyQuestionScreen> createState() => _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends State<DailyQuestionScreen> {
  DQQuestionResponse? _question;
  bool _isLoading = true;
  AnswerValue _currentAnswer =
      const AnswerValue(number: 1, orderOfMagnitude: '', unit: '');

  // Unit selection state
  String _currentLocale = 'US';
  List<String> _unitAbbreviations = [];
  Map<String, String> _unitOptions = {}; // name -> abbreviation

  // Timer
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startQuestion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _startQuestion() async {
    final controller = context.read<DailyQuestionController>();
    final authService = context.read<AuthService>();

    try {
      final question = await controller.startQuestion();

      // Get user's locale preference, default to 'US'
      final userLocale = authService.locale ?? 'US';

      setState(() {
        _question = question;
        _isLoading = false;
        _currentLocale = userLocale;

        // Initialize unit options from question
        _initializeUnits(question.units, userLocale);

        // Start Timer
        final now = DateTime.now();
        final deadline = question.answerDeadline;
        if (deadline.isAfter(now)) {
          _timeLeft = deadline.difference(now);
          _startTimer();
        } else {
          _timeLeft = Duration.zero;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        Navigator.of(context).pop();
      }
    }
  }

  void _initializeUnits(
    Map<String, List<Map<String, String>>>? units,
    String locale,
  ) {
    if (units == null || units.isEmpty) {
      _unitAbbreviations = [];
      _unitOptions = {};
      return;
    }

    // Get units for the current locale
    final localeUnits = units[locale.toUpperCase()] ?? units['US'] ?? [];

    if (localeUnits.isEmpty) {
      _unitAbbreviations = [];
      _unitOptions = {};
      return;
    }

    // Build abbreviations list and options map
    _unitAbbreviations = localeUnits
        .map((u) => u['abbreviation'] ?? '')
        .where((a) => a.isNotEmpty)
        .toList();

    _unitOptions = {
      for (final u in localeUnits)
        if (u['name'] != null && u['abbreviation'] != null)
          u['name']!: u['abbreviation']!
    };

    // Default to largest unit (last in ladder)
    if (_unitAbbreviations.isNotEmpty) {
      final defaultUnit = _unitAbbreviations.last;
      _currentAnswer = _currentAnswer.copyWith(unit: defaultUnit);
    }
  }

  void _onLocaleChanged(String newLocale) {
    if (_question?.units == null) return;

    setState(() {
      _currentLocale = newLocale;
      _initializeUnits(_question!.units, newLocale);
    });

    // Persist locale change to backend
    final apiService = context.read<ApiService>();
    apiService.setUserLocale(locale: newLocale);
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_timeLeft.inSeconds > 0) {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        } else {
          _timer?.cancel();
          _autoSubmit();
        }
      });
    });
  }

  Future<void> _autoSubmit() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Time\'s up! Submitting your answer...'),
        duration: Duration(seconds: 1),
      ),
    );
    await _submit();
  }

  Future<void> _submit() async {
    final controller = context.read<DailyQuestionController>();
    try {
      await controller.submitAnswer(_currentAnswer);
      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Answer Submitted!'),
            content: const Text(
              'Your answer has been recorded. Results will be available at 8 PM CT.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error submitting: $e')));
      }
    }
  }

  String get _formattedTime {
    final minutes =
        _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    if (_isLoading || _question == null) {
      return Scaffold(
        backgroundColor: appTheme.bg,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final bool hasUnits = _unitAbbreviations.isNotEmpty;

    return Scaffold(
      backgroundColor: appTheme.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: appTheme.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _formattedTime,
          style: AppFont.secondaryTextStyle(
            context,
            color: _timeLeft.inSeconds < 10 ? appTheme.danger : appTheme.text,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    QuestionWidget(
                      text: _question!.text,
                      tags: [_question!.category, _question!.difficulty],
                      height: 200,
                    ),
                    const SizedBox(height: 32),

                    // Answer Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SliderTextMirror(value: _currentAnswer),
                        if (hasUnits)
                          UnitTape(
                            units: _unitAbbreviations,
                            unitOptions: _unitOptions,
                            initialValue: _currentAnswer.unit,
                            currentLocale: _currentLocale,
                            onUnitChanged: (unit) {
                              setState(() {
                                _currentAnswer =
                                    _currentAnswer.copyWith(unit: unit);
                              });
                            },
                            onLocaleChanged: _onLocaleChanged,
                            editable: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    AnswerAccuracyScale(
                      currentAnswer: _currentAnswer,
                      onAnswerChanged: (val) {
                        setState(() {
                          _currentAnswer = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: MainButton(
                onPressed: _submit,
                label: MainButtonLabel.submit,
                showSpacebarGlyph: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
