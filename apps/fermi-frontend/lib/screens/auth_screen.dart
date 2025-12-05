import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';
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

    // Define the standardized border for neubrutalism
    final inputBorder = OutlineInputBorder(
      borderSide: BorderSide(
        color: appTheme.border,
        width: appTheme.borderWidth,
      ),
      borderRadius: BorderRadius.circular(appTheme.borderRadius),
    );

    // Create a specific theme for the auth UI to force the look
    final authTheme = Theme.of(context).copyWith(
      scaffoldBackgroundColor: appTheme.bg,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: appTheme.bgLight,
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
        labelStyle: TextStyle(color: appTheme.textMuted),
        hintStyle: TextStyle(color: appTheme.textMuted.withOpacity(0.5)),
        contentPadding: const EdgeInsets.all(16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: appTheme.primary,
          foregroundColor: appTheme.bgLight,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(appTheme.borderRadius),
            side: BorderSide(
              color: appTheme.border,
              width: appTheme.borderWidth,
            ),
          ),
          shadowColor: appTheme.shadowColor,
        ).copyWith(
            // Simulate hard shadow via translation if possible, but standard elevation is soft.
            // For true hard shadow in Flutter standard widgets without custom painting,
            // we rely on the flat look + border.
            // Firebase UI widgets might be limited in how much we can structure them.
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
            bodyMedium: TextStyle(
              color: appTheme.text,
            ),
          ),
      colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: appTheme.primary,
            error: appTheme.danger,
            surface: appTheme.bg,
          ),
    );

    return Theme(
      data: authTheme,
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
            iconColor: appTheme.text,
            splashColor: appTheme.primary.withOpacity(0.2),
            onPressed: onLeave ?? () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
