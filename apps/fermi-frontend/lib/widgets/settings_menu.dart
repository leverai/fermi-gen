import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class SettingsMenu extends StatefulWidget {
  final VoidCallback onSignOut;
  final VoidCallback onDeleteAccount;
  final VoidCallback onClose;
  final bool isAnonymous;
  final VoidCallback? onCreateAccount;

  const SettingsMenu({
    super.key,
    required this.onSignOut,
    required this.onDeleteAccount,
    required this.onClose,
    required this.isAnonymous,
    this.onCreateAccount,
  });

  @override
  State<SettingsMenu> createState() => _SettingsMenuState();
}

class _SettingsMenuState extends State<SettingsMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _controller.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Backdrop to close menu
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  color: appTheme.borderMuted.withOpacity(0.5),
                ),
              ),
            ),
          ),
          // Menu Content
          Positioned(
            bottom:
                74, // Positioned to align with the settings FAB (lifted by 48px)
            right: 24,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.bottomRight,
              child: Container(
                width: 250,
                decoration: BoxDecoration(
                  color: appTheme.bgLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: appTheme.border, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: appTheme.borderMuted.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionHeader(context, "Account"),
                    if (widget.isAnonymous)
                      // For anonymous users: show "Create Account" button
                      _buildMenuItem(
                        context,
                        icon: Icons.person_add,
                        label: "Create Account",
                        onTap: () {
                          _close();
                          widget.onCreateAccount?.call();
                        },
                        appTheme: appTheme,
                      )
                    else
                      // For regular users: show "Sign out" and "Delete account"
                      ...[
                      _buildMenuItem(
                        context,
                        icon: Icons.logout,
                        label: "Sign out",
                        onTap: () {
                          _close();
                          widget.onSignOut();
                        },
                        appTheme: appTheme,
                      ),
                      Divider(
                          height: 1,
                          thickness: 1,
                          color: appTheme.border.withOpacity(0.3)),
                      _buildMenuItem(
                        context,
                        icon: Icons.delete_forever,
                        label: "Delete account",
                        onTap: () {
                          _close();
                          widget.onDeleteAccount();
                        },
                        appTheme: appTheme,
                        isDestructive: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: AppFont.primaryTextStyle(
          context,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: appTheme.border,
        ),
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
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isDestructive ? appTheme.danger : appTheme.text,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: isDestructive ? appTheme.danger : appTheme.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
