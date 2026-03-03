import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/models/avatar_info.dart';
import 'package:fermi_frontend/models/player_stats.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/local_settings_service.dart';
import 'package:fermi_frontend/services/feedback_service.dart';
import 'package:fermi_frontend/services/ad_service.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/utils/answer_format.dart';
import 'package:fermi_frontend/widgets/avatar_widget.dart';
import 'package:fermi_frontend/widgets/styled_dialog.dart';
import 'package:lottie/lottie.dart';

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({
    super.key,
    required this.apiService,
    this.currentDisplayName,
    this.currentAvatarUrl,
    required this.onSave,
  });

  final ApiService apiService;
  final String? currentDisplayName;
  final String? currentAvatarUrl;
  final Function(String? displayName, String? avatarUrl) onSave;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  late final TextEditingController _nameController;
  List<AvatarInfo> _avatars = [];
  String? _selectedAvatarUrl;
  int _currentPoints = 0;
  bool _isLoadingAvatars = true;
  bool _isSaving = false;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentDisplayName);
    _selectedAvatarUrl = widget.currentAvatarUrl;
    _loadAvatars();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatars() async {
    try {
      final avatarsFuture = widget.apiService.getAvatars();
      final statsFuture = widget.apiService.getPlayerStatsTyped();

      final results = await Future.wait([avatarsFuture, statsFuture]);

      final avatars = results[0] as List<AvatarInfo>;
      final stats = (results[1] as PlayerStatsResponse).stats;

      if (mounted) {
        setState(() {
          _avatars = avatars;
          _currentPoints = stats.points;
          _isLoadingAvatars = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingAvatars = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
      }
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Empty is allowed
    }

    final trimmed = value.trim();

    // Length validation
    if (trimmed.length < 3) {
      return 'Name must be at least 3 characters';
    }
    if (trimmed.length > 30) {
      return 'Name must be at most 30 characters';
    }

    // Allow alphanumeric, spaces, and common special characters
    final validPattern = RegExp(r'^[a-zA-Z0-9\s._\-]+$');
    if (!validPattern.hasMatch(trimmed)) {
      return 'Name can only contain letters, numbers, spaces, and ._-';
    }

    return null;
  }

  /// Extract relative path from full avatar URL for backend validation.
  /// Backend expects paths like /static/avatars/letters/m.svg, not full URLs.
  String? _extractRelativeAvatarPath(String? url) {
    if (url == null) return null;
    const marker = '/static/avatars/';
    final idx = url.indexOf(marker);
    if (idx != -1) {
      return url.substring(idx);
    }
    // Already a relative path or external URL, return as-is
    return url;
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    final error = _validateName(name);

    if (error != null) {
      setState(() => _nameError = error);
      return;
    }

    setState(() {
      _isSaving = true;
      _nameError = null;
    });

    try {
      final avatarPath = _extractRelativeAvatarPath(_selectedAvatarUrl);
      await widget.apiService.updateUserProfile(
        displayName: name.isNotEmpty ? name : null,
        avatarUrl: avatarPath,
      );
      widget.onSave(name.isNotEmpty ? name : null, _selectedAvatarUrl);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _onAvatarTap(AvatarInfo avatar, bool isTrulyUnlocked) {
    if (isTrulyUnlocked) {
      setState(() => _selectedAvatarUrl = avatar.url);
    } else {
      _buyAvatar(avatar);
    }
  }

  Future<void> _buyAvatar(AvatarInfo avatar) async {
    if (_currentPoints < avatar.price) {
      final appTheme =
          Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
      showDialog(
        context: context,
        builder: (dialogContext) => StyledDialog(
          message: 'Insufficient Points',
          contentWidget: _AnimatedAvatarWidget(avatarUrl: avatar.url),
          secondaryMessage:
              'This avatar costs ${formatNumberWithCommas(avatar.price)} points. '
              'You currently have ${formatNumberWithCommas(_currentPoints)} points.',
          primaryButtonLabel: 'Watch Ad',
          primaryButtonColor: appTheme.secondary,
          onPrimaryPressed: () => _handleWatchAd(dialogContext),
          primaryButtonWidget:
              _buildWatchAdButtonContent(dialogContext, appTheme),
          leftWidget: _buildOkButton(dialogContext, appTheme),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final appTheme =
            Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
        return StyledDialog(
          message: 'Confirm Purchase',
          contentWidget: _AnimatedAvatarWidget(avatarUrl: avatar.url),
          secondaryMessage: 'Unlock this avatar?',
          primaryButtonLabel: 'Buy',
          primaryButtonColor: appTheme.primary,
          onPrimaryPressed: () => Navigator.of(context).pop(true),
          secondaryButtonLabel: 'Cancel',
          onSecondaryPressed: () => Navigator.of(context).pop(false),
          primaryButtonWidget: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                'assets/icons/points.svg',
                width: 16,
                height: 16,
              ),
              const SizedBox(width: 8),
              Text(
                formatNumberWithCommas(avatar.price),
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.bgLight,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirmed != true) return;

    try {
      final remaining = await widget.apiService.spendPoints(avatar.price);
      if (mounted) {
        // Save locally for persistence and immediate UI update
        await LocalSettingsService.instance.addOwnedAvatar(avatar.url);
        setState(() {
          _currentPoints = remaining;
          FeedbackService.instance.buttonPress();
        });
        _showSuccessAnimation();
        // Reload avatars to update unlocked status from backend as well
        _loadAvatars();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
  }

  void _handleWatchAd(BuildContext dialogContext) {
    final adService = AdService.instance;
    if (!adService.isAdLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not ready. Please try again.')),
      );
      adService.loadRewardedAd();
      return;
    }

    adService.showRewardedAd(
      onComplete: () async {
        if (!mounted) return;
        try {
          final newBalance = await widget.apiService.earnAdPoints();
          if (mounted) {
            setState(() => _currentPoints = newBalance);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to earn points: $e')),
            );
          }
        }
        if (dialogContext.mounted && Navigator.of(dialogContext).canPop()) {
          Navigator.of(dialogContext).pop();
        }
      },
      onSkipped: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ad skipped. Please watch the full ad.')),
        );
      },
      onFailed: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad failed to play. Please try again.')),
        );
      },
    );
  }

  Widget _buildOkButton(BuildContext dialogContext, AppTheme appTheme) {
    return SizedBox(
      height: 48,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: appTheme.highlight.withOpacity(0.2),
          onTap: () => Navigator.of(dialogContext).pop(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'OK',
                textAlign: TextAlign.center,
                style: AppFont.primaryTextStyle(
                  dialogContext,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.textMuted,
                ).copyWith(letterSpacing: 0.2),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWatchAdButtonContent(
      BuildContext dialogContext, AppTheme appTheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/icons/points.svg',
          width: 14,
          height: 14,
        ),
        const SizedBox(width: 4),
        Text(
          '+500',
          style: AppFont.primaryTextStyle(
            dialogContext,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: appTheme.bgLight,
          ),
        ),
        const SizedBox(width: 4),
        const Text('🎬', style: TextStyle(fontSize: 14)),
      ],
    );
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        });
        return Center(
          child: Lottie.asset(
            'assets/lotties/Success.json',
            width: 200,
            height: 200,
            repeat: false,
          ),
        );
      },
    );
  }

  /// Build grouped avatar grids with dividers between groups.
  List<Widget> _buildGroupedAvatarGrids(AppTheme appTheme) {
    // Group avatars by their group field
    final Map<String, List<AvatarInfo>> grouped = {};
    for (final avatar in _avatars) {
      grouped.putIfAbsent(avatar.group, () => []).add(avatar);
    }

    final widgets = <Widget>[];
    // Explicit group order: letters first (all level 1), then folks, then animals
    const groupOrder = ['letters', 'folks', 'animals'];
    final groups = groupOrder.where((g) => grouped.containsKey(g)).toList();

    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final avatarsInGroup = grouped[group]!;

      // Add divider between groups (not before first group)
      if (i > 0) {
        widgets.add(const SizedBox(height: 16));
        widgets.add(Divider(color: appTheme.borderMuted, thickness: 1));
        widgets.add(const SizedBox(height: 16));
      }

      // Build grid for this group
      widgets.add(
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.75,
          ),
          itemCount: avatarsInGroup.length,
          itemBuilder: (context, index) {
            return _buildAvatarItem(avatarsInGroup[index], appTheme);
          },
        ),
      );
    }

    return widgets;
  }

  /// Build a single avatar item widget.
  Widget _buildAvatarItem(AvatarInfo avatar, AppTheme appTheme) {
    final isSelected = _selectedAvatarUrl == avatar.url;
    return ValueListenableBuilder<Set<String>>(
      valueListenable: LocalSettingsService.instance.ownedAvatars,
      builder: (context, ownedAvatars, _) {
        final isTrulyUnlocked =
            avatar.unlocked || ownedAvatars.contains(avatar.url);

        return GestureDetector(
          onTap: () => _onAvatarTap(avatar, isTrulyUnlocked),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = constraints.maxWidth;
                    Widget avatarWidget = AvatarWidget(
                      imageUrl: avatar.url,
                      size: size,
                      padding: const EdgeInsets.all(4.0),
                      placeholder: CircularProgressIndicator(
                        color: appTheme.primary,
                        strokeWidth: 2,
                      ),
                    );

                    if (!isTrulyUnlocked && _currentPoints < avatar.price) {
                      avatarWidget = Opacity(
                        opacity: 0.5,
                        child: avatarWidget,
                      );
                    }

                    return Stack(
                      children: [
                        avatarWidget,
                        if (isSelected)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: appTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: appTheme.bgLight,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: appTheme.bgLight,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
              // Price row
              const SizedBox(height: 4),
              if (!isTrulyUnlocked)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/icons/points.svg',
                      width: 10,
                      height: 10,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      formatNumberWithCommas(avatar.price),
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _currentPoints >= avatar.price
                            ? appTheme.primary
                            : appTheme.textMuted,
                      ),
                    ),
                  ],
                )
              else
                const SizedBox(height: 14), // Spacer to maintain alignment
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                _isSaving
                    ? const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : TextButton(
                        onPressed: _handleSave,
                        child: Text(
                          'Save',
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: appTheme.primary,
                          ),
                        ),
                      ),
                Text(
                  'Edit profile',
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
                  onPressed: () {
                    FeedbackService.instance.secondaryClick();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                crossAxisAlignmentLabel('Display name', appTheme, context),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  style: TextStyle(color: appTheme.text),
                  onChanged: (value) {
                    // Clear error when user types
                    if (_nameError != null) {
                      setState(() => _nameError = null);
                    }
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: appTheme.bgDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _nameError != null
                            ? appTheme.danger
                            : appTheme.borderMuted,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _nameError != null
                            ? appTheme.danger
                            : appTheme.borderMuted,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: _nameError != null
                            ? appTheme.danger
                            : appTheme.primary,
                      ),
                    ),
                    errorText: _nameError,
                    errorStyle: TextStyle(color: appTheme.danger),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                  ),
                ),
                const SizedBox(height: 24),

                // Divider
                Divider(color: appTheme.borderMuted, thickness: 1),
                const SizedBox(height: 24),

                if (_isLoadingAvatars)
                  const Center(child: CircularProgressIndicator())
                else
                  ..._buildGroupedAvatarGrids(appTheme),
                // Extra space at bottom
                SizedBox(height: 48 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget crossAxisAlignmentLabel(
      String text, AppTheme appTheme, BuildContext context) {
    return Text(
      text,
      style: AppFont.primaryTextStyle(
        context,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: appTheme.textMuted,
      ),
    );
  }
}

class _AnimatedAvatarWidget extends StatefulWidget {
  final String avatarUrl;

  const _AnimatedAvatarWidget({required this.avatarUrl});

  @override
  State<_AnimatedAvatarWidget> createState() => _AnimatedAvatarWidgetState();
}

class _AnimatedAvatarWidgetState extends State<_AnimatedAvatarWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001) // perspective
            ..rotateY(_animation.value * 2 * math.pi),
          child: AvatarWidget(
            imageUrl: widget.avatarUrl,
            size: 200,
            padding: const EdgeInsets.all(4.0),
            placeholder: CircularProgressIndicator(
              color: appTheme.primary,
              strokeWidth: 2,
            ),
          ),
        );
      },
    );
  }
}
