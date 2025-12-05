import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, AuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class UpgradeAccountScreen extends StatelessWidget {
  final AuthService authService;

  const UpgradeAccountScreen({
    super.key,
    required this.authService,
  });

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final List<AuthProvider> providers = [
      EmailAuthProvider(),
      GoogleProvider(clientId: ''),
    ];

    return Scaffold(
      backgroundColor: appTheme.bgDark,
      appBar: AppBar(
        backgroundColor: appTheme.bgDark,
        foregroundColor: appTheme.text,
        elevation: 0,
        title: Text(
          'Create Account',
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: appTheme.text,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Create a permanent account',
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: appTheme.text,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Save your progress across devices and access your game history.',
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: appTheme.border,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SignInScreen(
                  providers: providers,
                  actions: [
                    // Handle credential linking when anonymous user signs in
                    AuthStateChangeAction<CredentialLinked>(
                      (context, state) async {
                        // Credential has been linked, exchange token to get updated user info
                        final ok = await authService.exchangeToken();
                        if (!context.mounted) return;
                        if (ok) {
                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Account created successfully!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          // Navigate back to main screen
                          Navigator.of(context).pop();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Account linking succeeded but token exchange failed.'),
                            ),
                          );
                        }
                      },
                    ),
                    // Also handle regular sign-in (in case user already has account)
                    AuthStateChangeAction<SignedIn>(
                      (context, state) async {
                        // If user signs in with existing account, try to link
                        // This handles the case where anonymous user signs in with email/Google
                        final user = FirebaseAuth.instance.currentUser;
                        if (user != null && user.isAnonymous) {
                          // This shouldn't happen if linking worked, but handle gracefully
                          debugPrint('User is still anonymous after sign-in');
                        } else {
                          // User signed in successfully, exchange token
                          final ok = await authService.exchangeToken();
                          if (!context.mounted) return;
                          if (ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account created successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            Navigator.of(context).pop();
                          }
                        }
                      },
                    ),
                    AuthStateChangeAction<AuthFailed>(
                      (context, state) {
                        final exception = state.exception;
                        String errorMessage = 'Failed to create account.';

                        if (exception is FirebaseAuthException) {
                          switch (exception.code) {
                            case 'email-already-in-use':
                              errorMessage =
                                  'This email is already associated with another account.';
                              break;
                            case 'account-exists-with-different-credential':
                              errorMessage =
                                  'An account already exists with this email but different sign-in method.';
                              break;
                            case 'invalid-credential':
                              errorMessage =
                                  'Invalid credentials. Please try again.';
                              break;
                            default:
                              errorMessage =
                                  'Error: ${exception.message ?? exception.code}';
                          }
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

