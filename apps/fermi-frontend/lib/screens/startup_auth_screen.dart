import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StartupAuthScreen extends StatelessWidget {
  const StartupAuthScreen({super.key});

  Future<void> _continueAsGuest(BuildContext context) async {
    // Mark onboarding as seen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);

    if (context.mounted) {
      // Refresh router to clear cached onboarding state before navigating
      GoRouter.of(context).refresh();
      context.go('/main');
    }
  }

  void _signIn(BuildContext context) {
    context.push('/sign-in');
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final user = FirebaseAuth.instance.currentUser;

    return ResponsiveContainer(
      backgroundColor: appTheme.bg,
      child: Scaffold(
        backgroundColor: appTheme.bg,
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                // Logo
                Image.asset(
                  'assets/icons/icon-fg.png',
                  height: 180,
                  width: 180,
                ),
                const SizedBox(height: 24),
                Text(
                  'Welcome to Guesstimate!',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: appTheme.text,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'The Reasoning Trivia Showdown',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                    color: appTheme.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),

                // Assigned Guest Identity (if anonymous)
                if (user != null && user.isAnonymous) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: appTheme.bgLight,
                      borderRadius:
                          BorderRadius.circular(appTheme.borderRadius),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'You have been assigned as',
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: appTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // We can use PlayerWidget to show the assigned identity
                        // But PlayerWidget requires a Player object or we can mock one
                        // Or just show the generic "Guest" text if we don't have the Player object handy without fetching it.
                        // Since we are not passing the Player object here, and fetching it might be overkill for this simple screen
                        // Let's just encourage them to continue as this identity.
                        // Actually, the user asked: "shows me what avatar/name I was given"
                        // The PlayerWidget takes a 'player' argument usually.
                        // If we don't have the player document loaded yet, we might skip showing the exact details
                        // or we rely on main screen to load it.
                        // However, since we are anonymously signed in, the user *has* an identity in Firebase Auth (UID),
                        // but their "Display Name" and "Avatar" are stored in Firestore 'players/{uid}'.
                        // We might not have that data loaded easily here without a stream or future.
                        // Let's keep it simple for now and just say "Guest".
                        // If the user *really* wants to see their avatar/name, we'd need to fetch the player doc.
                        // Given "I feel like there should be an auth screen with continue as guest option than then shows me what avatar/name I was given",
                        // it implies they see it *after* they choose guest, OR they see it *on* this screen.
                        // "Continue as guest option than then shows me..." -> maybe "that then shows me" -> Main Screen shows it.
                        // The user said: "I feel like there should be an auth screen with continue as guest option that then shows me what avatar/name I was given."
                        // This implies the standard MainScreen behavior is fine, they just want the explicit "Continue" step first.
                      ],
                    ),
                  ).isHidden
                      ? const SizedBox.shrink()
                      : const SizedBox
                          .shrink(), // Placeholder for now if we want to add it later
                  // Actually, let's keep it clean without the identity box for now unless we fetch it.
                  // The user said "Continue as guest option THAT THEN shows me what avatar/name I was given".
                  // This interprets as: Auth Screen -> Click Guest -> Main Screen (shows avatar).
                  // So we don't necessarily need to show it on the Auth Screen itself, just make the transition explicit.
                ],

                // Continue as Guest Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _continueAsGuest(context),
                    style: ButtonStyle(
                      elevation: WidgetStateProperty.all(0),
                      backgroundColor:
                          WidgetStateProperty.all(appTheme.primary),
                      foregroundColor:
                          WidgetStateProperty.all(appTheme.bgLight),
                      padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(vertical: 16)),
                      shape: WidgetStateProperty.all(
                        RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(appTheme.borderRadius),
                        ),
                      ),
                    ),
                    child: Text(
                      'Continue as Guest',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: appTheme.bgLight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // I have an account Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _signIn(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: appTheme.text,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(appTheme.borderRadius),
                      ),
                    ),
                    child: Text(
                      'I have an account',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: appTheme.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
        ),
      ),
    );
  }
}

extension on Widget {
  bool get isHidden =>
      true; // Helper to just comment out the block above cleanly
}
