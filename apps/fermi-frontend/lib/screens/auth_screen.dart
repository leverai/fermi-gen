// ignore_for_file: deprecated_member_use

import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    // Get our custom AppTheme from the context or default
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

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
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(
            color: appTheme.primary,
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
        labelStyle: TextStyle(color: appTheme.text),
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
            // side: BorderSide(
            //   color: appTheme.border,
            //   width: appTheme.borderWidth,
            // ),
          ),
          shadowColor: appTheme.shadowColor,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: appTheme.text,
          side: BorderSide(
            color: appTheme.border,
            width: appTheme.borderWidth,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appTheme.borderRadius),
          ),
          backgroundColor: Colors.transparent,
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
              providers: providers,
              actions: actions ?? const [],
              styles: const {
                // Custom styles for specific views if needed
              },
              headerBuilder: (context, constraints, shrinkOffset) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Welcome',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: appTheme.text,
                      ),
                    ),
                  ),
                );
              },
            ),
            // Leave Button
            LeaveButtonOverlay(
              iconColor: appTheme.border,
              splashColor: appTheme.primary.withOpacity(0.2),
              onPressed: onLeave ?? () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
