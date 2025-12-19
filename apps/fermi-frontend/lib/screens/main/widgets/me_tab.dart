import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/avatar_widget.dart';

/// Displays the "Me" tab content with user profile information.
///
/// Shows the user's avatar, display name, and account actions.
class MeTab extends StatelessWidget {
  const MeTab({
    super.key,
    this.avatarUrl,
    this.displayName,
    required this.isAnonymous,
    this.onCreateAccount,
  });

  /// URL of the user's avatar image.
  final String? avatarUrl;

  /// User's display name (defaults to "Guest" if null).
  final String? displayName;

  /// Whether the user is anonymous.
  final bool isAnonymous;

  /// Callback when "Create Account" button is pressed.
  final VoidCallback? onCreateAccount;

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AvatarWidget(
            imageUrl: avatarUrl,
            size: 120,
            backgroundColor: appTheme.bgLight,
            borderColor: appTheme.border,
            borderWidth: 2,
            padding: const EdgeInsets.all(12.0),
            placeholder: Icon(
              Icons.person,
              size: 64,
              color: appTheme.borderMuted,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            displayName ?? 'Guest',
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: appTheme.text,
            ),
          ),
          const SizedBox(height: 8),
          if (isAnonymous)
            TextButton(
              onPressed: onCreateAccount,
              child: Text(
                'Create Account',
                style: TextStyle(color: appTheme.primary, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }
}
