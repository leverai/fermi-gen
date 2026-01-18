// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/main.dart' show useEmulators;
import 'package:fermi_frontend/providers/subscription_provider.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/unit_system_switch.dart';
import 'package:fermi_frontend/widgets/sound_toggle_chip.dart';
import 'package:fermi_frontend/services/local_settings_service.dart';

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.onSignOut,
    required this.onDeleteAccount,
    required this.isAnonymous,
    this.onCreateAccount,
    this.email,
    this.currentLocale,
    this.onLocaleChanged,
    this.subscriptionTier = 'FREE',
    this.onUpgradeSubscription,
  });

  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;
  final bool isAnonymous;
  final VoidCallback? onCreateAccount;
  final String? email;
  final String? currentLocale;
  final ValueChanged<String>? onLocaleChanged;
  final String subscriptionTier;
  final VoidCallback? onUpgradeSubscription;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late String _currentLocale;

  @override
  void initState() {
    super.initState();
    _currentLocale = widget.currentLocale?.toUpperCase() ?? 'US';
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Container(
      decoration: BoxDecoration(
        color: appTheme.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: appTheme.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: appTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48), // Spacer to balance the close button
                Text(
                  'Settings',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: appTheme.text,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_down,
                      color: appTheme.border, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Gameplay Settings Section
                _buildSectionHeader(context, "Gameplay", appTheme),
                const SizedBox(height: 8),
                _buildSectionCard(
                  context,
                  appTheme,
                  children: [
                    _buildSettingsRow(
                      context,
                      appTheme,
                      label: 'Sound',
                      icon: Icons.volume_up,
                      showSplash: false,
                      onTap: () {
                        final bool current =
                            LocalSettingsService.instance.feedbackEnabled.value;
                        LocalSettingsService.instance
                            .setFeedbackEnabled(!current);
                      },
                      trailing: ValueListenableBuilder<bool>(
                        valueListenable:
                            LocalSettingsService.instance.feedbackEnabled,
                        builder: (context, enabled, _) {
                          return SoundToggleChip(
                            isOn: enabled,
                          );
                        },
                      ),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 24,
                      color: appTheme.bg,
                    ),
                    _buildSettingsRow(
                      context,
                      appTheme,
                      label: 'Unit system',
                      icon: Icons.straighten,
                      showSplash: false,
                      onTap: () {
                        final newLocale = _currentLocale == 'US' ? 'EU' : 'US';
                        setState(() {
                          _currentLocale = newLocale;
                        });
                        widget.onLocaleChanged?.call(newLocale);
                      },
                      trailing: _buildUnitSystemToggle(context, appTheme),
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 24,
                      color: appTheme.bg,
                    ),
                    _buildSettingsRow(
                      context,
                      appTheme,
                      label: 'Theme',
                      icon: Icons.brightness_6,
                      showSplash: false,
                      onTap: () {
                        // Cycle through modes: System -> Light -> Dark -> System
                        final current =
                            LocalSettingsService.instance.themeMode.value;
                        final next = current == ThemeMode.system
                            ? ThemeMode.light
                            : current == ThemeMode.light
                                ? ThemeMode.dark
                                : ThemeMode.system;
                        LocalSettingsService.instance.setThemeMode(next);
                      },
                      trailing: ValueListenableBuilder<ThemeMode>(
                        valueListenable:
                            LocalSettingsService.instance.themeMode,
                        builder: (context, mode, _) {
                          return _buildThemeToggle(context, appTheme, mode);
                        },
                      ),
                    ),
                    // Dev-only: Pro toggle for testing (only visible in emulator mode)
                    if (useEmulators) ...[
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 24,
                        color: appTheme.bg,
                      ),
                      Consumer<SubscriptionProvider>(
                        builder: (context, subProvider, _) {
                          return _buildSettingsRow(
                            context,
                            appTheme,
                            label: 'Dev: Pro Mode',
                            icon: Icons.developer_mode,
                            showSplash: false,
                            onTap: () {
                              // Toggle: null -> true -> false -> null
                              final current = subProvider.hasDevOverride
                                  ? subProvider.isPro
                                  : null;
                              final next = current == null
                                  ? true
                                  : current == true
                                      ? false
                                      : null;
                              subProvider.setDevOverride(next);
                            },
                            trailing: _buildDevProToggle(
                                context, appTheme, subProvider),
                          );
                        },
                      ),
                    ],
                  ],
                ),
                // Account Section
                const SizedBox(height: 16),
                _buildSectionHeader(context, "Account", appTheme,
                    email: widget.email),
                const SizedBox(height: 8),
                _buildSectionCard(
                  context,
                  appTheme,
                  children: [
                    // Subscription row - disabled for anonymous users
                    _buildSettingsRow(
                      context,
                      appTheme,
                      label: 'Subscription',
                      icon: Icons.workspace_premium,
                      trailing: Text(
                        widget.subscriptionTier,
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: widget.subscriptionTier == 'FREE'
                              ? appTheme.textMuted
                              : appTheme.primary,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onUpgradeSubscription?.call();
                      },
                    ),
                    Divider(
                      height: 1,
                      thickness: 1,
                      indent: 24,
                      color: appTheme.bg,
                    ),
                    if (widget.isAnonymous)
                      _buildSettingsRow(
                        context,
                        appTheme,
                        label: "Create Account",
                        icon: Icons.person_add,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onCreateAccount?.call();
                        },
                      )
                    else ...[
                      _buildSettingsRow(
                        context,
                        appTheme,
                        label: "Sign out",
                        icon: Icons.logout,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onSignOut();
                        },
                      ),
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 24, // Align with text after icon
                        color: appTheme.bg,
                      ),
                      _buildSettingsRow(
                        context,
                        appTheme,
                        label: "Delete account",
                        icon: Icons.delete_forever,
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onDeleteAccount();
                        },
                        isDestructive: true,
                      ),
                    ],
                  ],
                ),
                SizedBox(
                    height: 48 +
                        MediaQuery.paddingOf(context)
                            .bottom), // Extra space at bottom including safe area
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, AppTheme appTheme,
      {String? email}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title.toUpperCase(),
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appTheme.textMuted,
            ),
          ),
          if (email != null)
            Text(
              '${email.substring(0, 3)}***${email.substring(email.length - 3)}',
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: appTheme.border,
              ).copyWith(
                letterSpacing: 0.5,
              ),
            ),
        ],
      ),
    );
  }

  /// Builds a section card with rounded corners and bgLight background
  Widget _buildSectionCard(
    BuildContext context,
    AppTheme appTheme, {
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: appTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  /// Builds a reusable settings row with optional icon, label, and trailing widget
  Widget _buildSettingsRow(
    BuildContext context,
    AppTheme appTheme, {
    required String label,
    IconData? icon,
    Widget? trailing,
    VoidCallback? onTap,
    bool isDestructive = false,
    bool showSplash = true,
    bool isDisabled = false,
  }) {
    final Color textColor = isDisabled
        ? appTheme.bgDark
        : isDestructive
            ? appTheme.danger
            : appTheme.text;

    Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: textColor,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: textColor,
                ),
              ),
            ],
          ),
          if (trailing != null) trailing,
        ],
      ),
    );

    if (onTap != null) {
      if (showSplash) {
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: content,
        );
      } else {
        return GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: content,
        );
      }
    }

    return content;
  }

  /// Builds the unit system toggle (Imperial / Switch / Metric)
  Widget _buildUnitSystemToggle(BuildContext context, AppTheme appTheme) {
    final bool isUS = _currentLocale == 'US';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Imperial label
        Text(
          'Imperial',
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isUS ? appTheme.primary : appTheme.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        // Switch container
        UnitSystemSwitch(
          isUS: isUS,
          circleColor: appTheme.primary,
        ),
        const SizedBox(width: 8),
        // Metric label
        Text(
          'Metric',
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: !isUS ? appTheme.primary : appTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildThemeToggle(
      BuildContext context, AppTheme appTheme, ThemeMode mode) {
    return mode == ThemeMode.system
        ? const Icon(Icons.brightness_6)
        : mode == ThemeMode.light
            ? const Icon(Icons.wb_sunny)
            : const Icon(Icons.brightness_2);
  }

  /// Builds the dev Pro toggle indicator (Auto / Pro / Free)
  Widget _buildDevProToggle(
      BuildContext context, AppTheme appTheme, SubscriptionProvider provider) {
    final String label;
    final Color color;
    if (!provider.hasDevOverride) {
      label = 'Auto';
      color = appTheme.textMuted;
    } else if (provider.isPro) {
      label = 'Pro';
      color = appTheme.primary;
    } else {
      label = 'Free';
      color = appTheme.danger;
    }
    return Text(
      label,
      style: AppFont.primaryTextStyle(
        context,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: color,
      ),
    );
  }
}
