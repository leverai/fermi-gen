// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/models/ltt_sound_profile.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/local_settings_service.dart';
import 'package:fermi_frontend/services/feedback_service.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/utils/answer_format.dart';
import 'package:fermi_frontend/widgets/live_typing_text.dart';
import 'package:fermi_frontend/widgets/styled_dialog.dart';
import 'package:lottie/lottie.dart';

/// Screen for previewing, purchasing, and selecting LTT sound profiles.
class SoundProfileShopScreen extends StatefulWidget {
  final int currentPoints;
  final ApiService apiService;

  const SoundProfileShopScreen({
    super.key,
    required this.currentPoints,
    required this.apiService,
  });

  @override
  State<SoundProfileShopScreen> createState() => _SoundProfileShopScreenState();
}

class _SoundProfileShopScreenState extends State<SoundProfileShopScreen> {
  late int _availablePoints;
  String? _previewingProfile; // pathName of profile being previewed
  int _previewKey = 0; // Forces LTT widget rebuild on re-tap

  @override
  void initState() {
    super.initState();
    _availablePoints = widget.currentPoints;
  }

  Future<void> _buyProfile(LttSoundProfile profile) async {
    if (_availablePoints < profile.cost) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final appTheme =
            Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
        return StyledDialog(
          message: 'Confirm Purchase',
          secondaryMessage: 'Item: ${profile.displayName}',
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
                formatNumberWithCommas(profile.cost),
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
      final remaining = await widget.apiService.spendPoints(profile.cost);
      await LocalSettingsService.instance.addOwnedSoundProfile(profile);
      if (mounted) {
        setState(() => _availablePoints = remaining);
        FeedbackService.instance.buttonPress();
        _showSuccessAnimation();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
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

  void _selectProfile(LttSoundProfile? profile) {
    LocalSettingsService.instance.setSelectedSoundProfile(profile);
    FeedbackService.instance.secondaryClick();
    setState(() {});
  }

  void _togglePreview(LttSoundProfile profile) {
    setState(() {
      if (_previewingProfile == profile.pathName) {
        _previewingProfile = null;
      } else {
        _previewingProfile = profile.pathName;
        _previewKey++;
      }
    });
  }

  void _showCreditsDialog() {
    FeedbackService.instance.buttonPress();
    showDialog(
      context: context,
      builder: (context) {
        final appTheme =
            Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
        return StyledDialog(
          message: 'Sound Credits',
          secondaryMessage: 'MIT License\n\n'
              'Copyright (c) 2025 Nathan Fiscaletti\n\n'
              'Permission is hereby granted, free of charge, to any person obtaining a copy '
              'of this software and associated documentation files (the "Software"), to deal '
              'in the Software without restriction, including without limitation the rights '
              'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
              'copies of the Software, and to permit persons to whom the Software is '
              'furnished to do so, subject to the following conditions:\n\n'
              'The above copyright notice and this permission notice shall be included in all '
              'copies or substantial portions of the Software.\n\n'
              'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR '
              'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, '
              'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE '
              'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER '
              'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, '
              'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE '
              'SOFTWARE.',
          primaryButtonLabel: 'Close',
          primaryButtonColor: appTheme.primary,
          onPrimaryPressed: () => Navigator.of(context).pop(),
        );
      },
    ).then((_) {
      FeedbackService.instance.secondaryClick();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Scaffold(
      backgroundColor: appTheme.bgDark,
      appBar: AppBar(
        backgroundColor: appTheme.bgDark,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appTheme.text),
          onPressed: () {
            FeedbackService.instance.secondaryClick();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          'Typing Sounds',
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: appTheme.text,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/icons/points.svg',
                  width: 16,
                  height: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  formatNumberWithCommas(_availablePoints),
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: appTheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<LttSoundProfile?>(
        valueListenable: LocalSettingsService.instance.selectedSoundProfile,
        builder: (context, selectedProfile, _) {
          return ValueListenableBuilder<Set<LttSoundProfile>>(
            valueListenable: LocalSettingsService.instance.ownedSoundProfiles,
            builder: (context, ownedProfiles, _) {
              return ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                children: [
                  // // Silent option
                  // _buildProfileCard(
                  //   context,
                  //   appTheme,
                  //   name: 'Silent',
                  //   subtitle: 'No typing sound',
                  //   isOwned: true,
                  //   isSelected: selectedProfile == null,
                  //   cost: 0,
                  //   onSelect: () => _selectProfile(null),
                  //   onPreview: null,
                  //   isPreviewActive: false,
                  // ),
                  // const SizedBox(height: 8),

                  // Profile cards
                  ...LttSoundProfile.values.map((profile) {
                    final isOwned = ownedProfiles.contains(profile);
                    final isSelected = selectedProfile == profile;
                    final isPreviewActive =
                        _previewingProfile == profile.pathName;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildProfileCard(
                        context,
                        appTheme,
                        name: profile.displayName,
                        subtitle: _profileSubtitle(profile),
                        isOwned: isOwned,
                        isSelected: isSelected,
                        cost: profile.cost,
                        onSelect:
                            isOwned ? () => _selectProfile(profile) : null,
                        onBuy: !isOwned && _availablePoints >= profile.cost
                            ? () => _buyProfile(profile)
                            : null,
                        onPreview: () => _togglePreview(profile),
                        isPreviewActive: isPreviewActive,
                        previewWidget: isPreviewActive
                            ? Offstage(
                                child: LiveTypingText(
                                  key: ValueKey(
                                      '${profile.pathName}_$_previewKey'),
                                  text:
                                      'This is what ${profile.displayName} sounds like!',
                                  soundProfile: profile,
                                  bypassFeedbackEnabled: true,
                                  onTypingComplete: () {
                                    if (mounted &&
                                        _previewingProfile ==
                                            profile.pathName) {
                                      setState(() {
                                        _previewingProfile = null;
                                      });
                                    }
                                  },
                                ),
                              )
                            : null,
                        canAfford: _availablePoints >= profile.cost,
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // Credits button
                  Center(
                    child: GestureDetector(
                      onTap: _showCreditsDialog,
                      child: Text(
                        'Sounds: Copyright (c) 2025 Nathan Fiscaletti',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: appTheme.borderMuted,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _profileSubtitle(LttSoundProfile profile) {
    switch (profile) {
      case LttSoundProfile.alpaca:
        return 'Deep thock';
      case LttSoundProfile.holyPanda:
        return 'Tactile thock';
      case LttSoundProfile.gateronBlackInk:
        return 'Smooth & creamy';
      case LttSoundProfile.gateronRedInk:
        return 'Light linear';
      case LttSoundProfile.mxBrown:
        return 'Tactile bump';
      case LttSoundProfile.mxBlack:
        return 'Heavy linear';
      case LttSoundProfile.mxBlue:
        return 'Clicky';
      case LttSoundProfile.ios:
        return 'Soft tap';
      case LttSoundProfile.typewriter:
        return 'Vintage click';
    }
  }

  Widget _buildProfileCard(
    BuildContext context,
    AppTheme appTheme, {
    required String name,
    required String subtitle,
    required bool isOwned,
    required bool isSelected,
    required int cost,
    VoidCallback? onSelect,
    VoidCallback? onBuy,
    VoidCallback? onPreview,
    required bool isPreviewActive,
    Widget? previewWidget,
    bool canAfford = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: appTheme.bgLight,
        borderRadius: BorderRadius.circular(12),
        border:
            isSelected ? Border.all(color: appTheme.primary, width: 1.5) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Name & subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            name,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: appTheme.text,
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.check_circle,
                                size: 16, color: appTheme.primary),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                          color: appTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action buttons
                if (onPreview != null) ...[
                  _buildIconButton(
                    context,
                    appTheme,
                    icon: isPreviewActive
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                    onTap: onPreview,
                    color: appTheme.textMuted,
                  ),
                  const SizedBox(width: 8),
                ],

                if (isOwned)
                  _buildActionChip(
                    context,
                    appTheme,
                    label: isSelected ? 'Selected' : 'Select',
                    onTap: isSelected ? null : onSelect,
                    isPrimary: !isSelected,
                    isSubtle: isSelected,
                  )
                else
                  _buildPriceChip(
                    context,
                    appTheme,
                    cost: cost,
                    onTap: onBuy,
                    canAfford: canAfford,
                  ),
              ],
            ),
            if (previewWidget != null) previewWidget,
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context,
    AppTheme appTheme, {
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: appTheme.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _buildActionChip(
    BuildContext context,
    AppTheme appTheme, {
    required String label,
    VoidCallback? onTap,
    bool isPrimary = false,
    bool isSubtle = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isPrimary
              ? appTheme.primary
              : isSubtle
                  ? appTheme.bg
                  : appTheme.bgLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isPrimary
                ? Colors.white
                : isSubtle
                    ? appTheme.textMuted
                    : appTheme.text,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceChip(
    BuildContext context,
    AppTheme appTheme, {
    required int cost,
    VoidCallback? onTap,
    required bool canAfford,
  }) {
    if (cost == 0) {
      return _buildActionChip(context, appTheme,
          label: 'Free', onTap: onTap, isPrimary: true);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: canAfford ? appTheme.primary.withOpacity(0.15) : appTheme.bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              'assets/icons/points.svg',
              width: 12,
              height: 12,
            ),
            const SizedBox(width: 4),
            Text(
              formatNumberWithCommas(cost),
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: canAfford ? appTheme.primary : appTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
