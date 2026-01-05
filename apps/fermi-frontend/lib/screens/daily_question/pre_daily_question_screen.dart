// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/screens/daily_question/daily_question_screen.dart';

/// Pre-Daily Question screen shown before starting an active DQ.
///
/// Displays the date and duration information, and provides a "Start" button
/// to proceed to the actual DQ screen. This prepares users before they begin
/// the timed question.
class PreDailyQuestionScreen extends StatelessWidget {
  /// The DQ date in YYYY-MM-DD format.
  final String questionDate;

  /// Whether this screen was reached via an invite link.
  /// If true, back/leave button navigates to main screen.
  /// If false, back/leave button uses Navigator.pop().
  final bool fromInvite;

  const PreDailyQuestionScreen({
    super.key,
    required this.questionDate,
    this.fromInvite = false,
  });

  void _handleLeave(BuildContext context) {
    if (fromInvite) {
      // From invite link - go to main screen
      context.go('/main');
    } else {
      // From push navigation - pop back
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/main');
      }
    }
  }

  void _handleStart(BuildContext context) {
    // Use pushReplacement so PreDailyQuestionScreen is removed from the stack.
    // This ensures that when the user leaves DailyQuestionScreen, they go to
    // main screen instead of back to pre-DQ screen.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => const DailyQuestionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Parse the date
    final date = DateTime.parse(questionDate);
    final dateFormat = DateFormat('MMMM d, yyyy');
    final formattedDate = dateFormat.format(date);

    return ResponsiveContainer(
      backgroundColor: appTheme.bg,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          _handleLeave(context);
        },
        child: Scaffold(
          backgroundColor: appTheme.bg,
          body: SafeArea(
            child: Column(
              children: [
                // Minimal Header
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      icon: Icon(Icons.chevron_left,
                          color: appTheme.text, size: 32),
                      onPressed: () => _handleLeave(context),
                      tooltip: 'Leave',
                    ),
                  ),
                ),

                // Main Content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Logo / Icon
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: appTheme.bgLight,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: SvgPicture.asset(
                              'assets/icons/logo-fg.svg',
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Title
                          Text(
                            'The Daily Guess',
                            textAlign: TextAlign.center,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: appTheme.text,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Subtitle
                          Text(
                            'Estimate the unknown.\nReady?',
                            textAlign: TextAlign.center,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: appTheme.text,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Start button
                          SizedBox(
                            width: 200,
                            child: MainButton(
                              onPressed: () => _handleStart(context),
                              label: MainButtonLabel.start,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Date info
                          Text(
                            formattedDate,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: appTheme.text,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Credits
                          Text(
                            'By Guesstimate Team • 30 seconds',
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: appTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
