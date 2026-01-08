// ignore_for_file: deprecated_member_use

import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, AuthProvider, OAuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({
    super.key,
    required this.providers,
    this.actions,
    this.onLeave,
  });

  final List<AuthProvider> providers;
  final List<FirebaseUIAction>? actions;
  final VoidCallback? onLeave;

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to sign in with Google: $e',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get our custom AppTheme from the context or default
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Separate GoogleProvider to handle it manually for custom styling
    final googleProvider = providers.whereType<GoogleProvider>().firstOrNull;
    final otherProviders =
        providers.where((p) => p is! GoogleProvider).toList();

    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(appTheme.borderRadius),
    );

    // Create a specific theme for the auth UI to force the look
    final authTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: appTheme.bg,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appTheme.bgDark,
        // Borders
        border: inputBorder,
        enabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: appTheme.borderMuted,
            width: appTheme.borderWidth,
          ),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: appTheme.border,
            width: appTheme.borderWidth,
          ),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: appTheme.danger,
            width: appTheme.borderWidth,
          ),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: appTheme.danger,
            width: appTheme.borderWidth,
          ),
        ),
        // Text styles
        labelStyle: TextStyle(color: appTheme.textMuted),
        hintStyle: TextStyle(color: appTheme.textMuted),
        contentPadding: const EdgeInsets.all(16),
      ),
      brightness: Brightness.dark,
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: appTheme.primary,
          foregroundColor: appTheme.bgLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appTheme.borderRadius),
          ),
          shadowColor: appTheme.shadowColor,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: appTheme.text,
          side: BorderSide(
            color: appTheme.borderMuted,
            width: appTheme.borderWidth,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appTheme.borderRadius),
          ),
          backgroundColor: appTheme.primary,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: appTheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      textTheme: Theme.of(context).textTheme.copyWith(
            headlineSmall: TextStyle(
              color: appTheme.text,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
            bodyLarge: TextStyle(color: appTheme.text),
            bodyMedium: TextStyle(color: appTheme.textMuted),
            bodySmall: TextStyle(color: appTheme.textMuted),
            titleMedium: TextStyle(color: appTheme.text),
            titleSmall: TextStyle(color: appTheme.textMuted),
            labelLarge: TextStyle(color: appTheme.textMuted),
          ),
      colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: appTheme.primary,
            error: appTheme.danger,
            surface: appTheme.text,
          ),
    );

    return Theme(
      data: authTheme,
      child: ResponsiveContainer(
        backgroundColor: appTheme.bg,
        child: Stack(
          children: [
            SignInScreen(
              providers: otherProviders,
              actions: actions ?? const [],
              styles: const {
                // Custom styles for specific views if needed
              },
              headerBuilder: (context, constraints, shrinkOffset) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: appTheme.bgLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: SvgPicture.asset(
                            'assets/icons/logo-fg.svg',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Welcome',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: appTheme.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              footerBuilder: (context, action) {
                if (googleProvider == null) return const SizedBox.shrink();

                return Column(
                  children: [
                    const SizedBox(height: 24),
                    // Or divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: appTheme.borderMuted,
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or',
                            style: TextStyle(
                              color: appTheme.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: appTheme.borderMuted,
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      // 1. Change OutlinedButton to OutlinedButton.icon
                      child: OutlinedButton.icon(
                        onPressed: () => _signInWithGoogle(context),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                        ),
                        // 2. Use the 'icon' property for the widget (Icon, Image, etc.)
                        icon: SvgPicture.asset(
                          'assets/icons/google.svg',
                          height: 16,
                          width: 16,
                        ),
                        // 3. Use the 'label' property for the text (instead of 'child')
                        label: const Text('Sign in with Google'),
                      ),
                    ),
                  ],
                );
              },
            ),
            // Leave Button
            LeaveButtonOverlay(
              iconColor: appTheme.border,
              splashColor: appTheme.borderMuted,
              onPressed: onLeave ?? () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
