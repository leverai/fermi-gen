// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/unit_system_switch.dart';

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
  });

  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;
  final bool isAnonymous;
  final VoidCallback? onCreateAccount;
  final String? email;
  final String? currentLocale;
  final ValueChanged<String>? onLocaleChanged;

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
        color: appTheme.bgLight,
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
              color: appTheme.borderMuted,
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
                      color: appTheme.text, size: 32),
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
                _buildSectionHeader(context, "Regional Settings", appTheme),
                const SizedBox(height: 8),
                _buildUnitSystemRow(context, appTheme),
                // Account Section
                const SizedBox(height: 24),
                _buildSectionHeader(context, "Account", appTheme,
                    email: widget.email),
                const SizedBox(height: 8),
                if (widget.isAnonymous)
                  _buildMenuItem(
                    context,
                    icon: Icons.person_add,
                    label: "Create Account",
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onCreateAccount?.call();
                    },
                    appTheme: appTheme,
                  )
                else ...[
                  _buildMenuItem(
                    context,
                    icon: Icons.logout,
                    label: "Sign out",
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onSignOut();
                    },
                    appTheme: appTheme,
                  ),
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: appTheme.borderMuted.withOpacity(0.3),
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.delete_forever,
                    label: "Delete account",
                    onTap: () {
                      Navigator.of(context).pop();
                      widget.onDeleteAccount();
                    },
                    appTheme: appTheme,
                    isDestructive: true,
                  ),
                ],
                const SizedBox(height: 48), // Extra space at bottom
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
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: appTheme.textMuted,
            ),
          ),
          if (email != null)
            Text(
              email,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: appTheme.borderMuted,
              ).copyWith(
                letterSpacing: 0.5,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required AppTheme appTheme,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isDestructive ? appTheme.danger : appTheme.text,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDestructive ? appTheme.danger : appTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitSystemRow(BuildContext context, AppTheme appTheme) {
    final bool isUS = _currentLocale == 'US';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Unit system',
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: appTheme.text,
            ),
          ),
          GestureDetector(
            onTap: () {
              final newLocale = isUS ? 'EU' : 'US';
              setState(() {
                _currentLocale = newLocale;
              });
              widget.onLocaleChanged?.call(newLocale);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Imperial label
                Text(
                  'Imperial',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: isUS ? FontWeight.w600 : FontWeight.w400,
                    color: isUS ? appTheme.secondary : appTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                // Switch container
                UnitSystemSwitch(
                  isUS: isUS,
                  appTheme: appTheme,
                ),
                const SizedBox(width: 6),
                // Metric label
                Text(
                  'Metric',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: !isUS ? FontWeight.w600 : FontWeight.w400,
                    color: !isUS ? appTheme.secondary : appTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
