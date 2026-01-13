import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// Pre-Survival screen shown before starting or resuming a survival run.
///
/// Displays the user's current streak and provides a button to proceed.
class PreSurvivalScreen extends StatelessWidget {
  /// The user's current survival streak.
  final int streak;

  /// Callback when the user taps the action button.
  final VoidCallback onStart;

  /// Callback when the user wants to leave the screen.
  final VoidCallback onLeave;

  const PreSurvivalScreen({
    super.key,
    required this.streak,
    required this.onStart,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final bool isResume = streak > 0;

    return ResponsiveContainer(
      backgroundColor: appTheme.bg,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          onLeave();
        },
        child: Scaffold(
          backgroundColor: appTheme.bg,
          body: SafeArea(
            child: Column(
              children: [
                // Header with back button
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      icon: Icon(Icons.chevron_left,
                          color: appTheme.border, size: 32),
                      onPressed: onLeave,
                      tooltip: 'Back',
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
                            'Survival Mode',
                            textAlign: TextAlign.center,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: appTheme.text,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Subtitle / Streak Info
                          Text(
                            isResume
                                ? 'Current Streak: $streak\nReady to keep going?'
                                : 'How long can you survive?\nBuild your streak.',
                            textAlign: TextAlign.center,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: appTheme.textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Action Button
                          SizedBox(
                            width: 200,
                            child: MainButton(
                              onPressed: onStart,
                              label: isResume
                                  ? MainButtonLabel.resume
                                  : MainButtonLabel.start,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Descriptive Footer
                          Text(
                            'One mistake and it\'s over.',
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: appTheme.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Unlimited time • Precision counts',
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
