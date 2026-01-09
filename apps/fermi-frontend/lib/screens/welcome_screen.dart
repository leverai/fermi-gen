import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// Welcome screen shown to first-time users before the onboarding tutorial.
///
/// Provides a brief introduction to the app with a tutorial question tease,
/// then navigates to the onboarding tutorial when user taps "Get Started".
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  Future<void> _getStarted(BuildContext context) async {
    // Mark welcome as seen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcome_seen', true);

    if (context.mounted) {
      // Refresh router to pick up the preference change
      GoRouter.of(context).refresh();
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return ResponsiveContainer(
      backgroundColor: appTheme.bg,
      child: Scaffold(
        backgroundColor: appTheme.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // Logo / Icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: appTheme.bgLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: SvgPicture.asset(
                    'assets/icons/logo-fg.svg',
                  ),
                ),
                const SizedBox(height: 40),

                // Title
                Text(
                  'Welcome to Guesstimate!',
                  textAlign: TextAlign.center,
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: appTheme.text,
                  ),
                ),
                const SizedBox(height: 64),

                // Tutorial question tease
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: appTheme.bgLight,
                    borderRadius: BorderRadius.circular(appTheme.borderRadius),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Ever wondered:',
                        textAlign: TextAlign.center,
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: appTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'How tall would a stack of one billion \$1 bills be?',
                        textAlign: TextAlign.center,
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: appTheme.text,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(flex: 2),

                // Get Started button
                SizedBox(
                  width: 200,
                  child: MainButton(
                    onPressed: () => _getStarted(context),
                    label: MainButtonLabel.start,
                    customLabel: 'Get Started',
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
