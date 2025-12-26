import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/player_stats.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/avatar_widget.dart';
import 'package:fermi_frontend/widgets/stats_card.dart';

/// Displays the "Me" tab content with user profile information.
///
/// Shows the user's avatar, display name, stats card, and account actions.
class MeTab extends StatelessWidget {
  const MeTab({
    super.key,
    this.avatarUrl,
    this.displayName,
    required this.isAnonymous,
    this.onCreateAccount,
    this.onEditProfile,
    this.playerStats,
    this.onStatsTapped,
  });

  /// URL of the user's avatar image.
  final String? avatarUrl;

  /// User's display name (defaults to "Guest" if null).
  final String? displayName;

  /// Whether the user is anonymous.
  final bool isAnonymous;

  /// Callback when "Create Account" button is pressed.
  final VoidCallback? onCreateAccount;

  /// Callback when "Edit Profile" (pencil) is pressed.
  final VoidCallback? onEditProfile;

  /// Player statistics to display in the stats card.
  final PlayerStats? playerStats;

  /// Callback when the stats card is tapped.
  final VoidCallback? onStatsTapped;

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
            padding: const EdgeInsets.all(12.0),
            boxShadow: [
              BoxShadow(
                color: appTheme.primary,
                offset: appTheme.shadowOffset,
              ),
            ],
            placeholder: Icon(
              Icons.person,
              size: 64,
              color: appTheme.borderMuted,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Balance the Row so the name remains perfectly centered
              if (onEditProfile != null) ...[
                const Opacity(
                  opacity: 0,
                  child: IgnorePointer(
                    child: IconButton(
                      onPressed: null,
                      icon: Icon(Icons.edit),
                      // Maintain exact same size constraints
                      padding: EdgeInsets.all(8.0),
                      constraints: BoxConstraints(
                        minWidth: kMinInteractiveDimension,
                        minHeight: kMinInteractiveDimension,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  displayName ?? 'Guest',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: appTheme.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onEditProfile != null) ...[
                IconButton(
                  onPressed: onEditProfile,
                  icon: Icon(Icons.edit, color: appTheme.textMuted),
                  tooltip: 'Edit Profile',
                  // ignore: deprecated_member_use
                  splashColor: appTheme.primary.withOpacity(0.3),
                  // ignore: deprecated_member_use
                  highlightColor: appTheme.primary.withOpacity(0.1),
                  padding: const EdgeInsets.all(8.0),
                  constraints: const BoxConstraints(
                    minWidth: kMinInteractiveDimension,
                    minHeight: kMinInteractiveDimension,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          if (isAnonymous)
            TextButton(
              onPressed: onCreateAccount,
              child: Text(
                'Create Account',
                style: TextStyle(color: appTheme.secondary, fontSize: 16),
              ),
            ),
          // Stats card with 48px space above
          if (playerStats != null) ...[
            const SizedBox(height: 48),
            StatsCard(
              stats: playerStats!,
              onTap: onStatsTapped,
            ),
          ],
        ],
      ),
    );
  }
}
