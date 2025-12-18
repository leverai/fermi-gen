import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/question_widget.dart';
import 'package:fermi_frontend/widgets/answer_accuracy_scale.dart';
import 'package:fermi_frontend/widgets/slider_text_mirror.dart';
import 'package:fermi_frontend/widgets/main_button.dart';

class DailyQuestionScreen extends StatefulWidget {
  const DailyQuestionScreen({super.key});

  @override
  State<DailyQuestionScreen> createState() => _DailyQuestionScreenState();
}

class _DailyQuestionScreenState extends State<DailyQuestionScreen> {
  DQQuestionResponse? _question;
  bool _isLoading = true;
  AnswerValue _currentAnswer = const AnswerValue(
      number: 1, orderOfMagnitude: '', unit: ''); // Default valid answer

  // UnitTapeController _unitTapeController = UnitTapeController(); // Removed unused

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
    try {
      final question = await controller.startQuestion();
      setState(() {
        _question = question;
        _isLoading = false;

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
        // Show error and pop
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        Navigator.of(context).pop();
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft.inSeconds > 0) {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        } else {
          _timer?.cancel();
          // Time up logic? Auto submit?
        }
      });
    });
  }

  Future<void> _submit() async {
    final controller = context.read<DailyQuestionController>();
    try {
      await controller.submitAnswer(_currentAnswer);
      if (mounted) {
        // Show confirmation dialog before returning to main screen
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
                      height: 200, // Fixed height or auto?
                    ),
                    const SizedBox(height: 32),

                    // Answer Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SliderTextMirror(value: _currentAnswer),
                        // Unit Tape if needed. Need data from question?
                        // DQ Response usually doesn't have units unless implied or strict.
                        // But we can enable it if we had units.
                        // The `DQQuestionResponse` I defined didn't capture units.
                        // Assuming simplified version without units for now or add if needed.
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
                      // We check minimal constructor params
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
