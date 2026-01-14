import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/screens/main/widgets/daily_question_carousel.dart';
import 'package:fermi_frontend/widgets/bounce_effect_wrapper.dart';

/// Displays the "Games" tab content with game options.
///
/// Contains the top bar, welcome message, Daily Question carousel, and Party card.
class GamesTab extends StatelessWidget {
  Widget _buildFreeTierInfo(BuildContext context, AppTheme appTheme) {
    final controller = context.watch<MainScreenController>();
    final userLimits = controller.userLimitsDto;

    // Don't show anything for Pro users or if limits aren't loaded
    if (userLimits == null || userLimits.isUnlimited) {
      return const SizedBox.shrink();
    }

    final bool canHost = userLimits.canHost;
    final int remaining = userLimits.partyHostingsRemaining;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          canHost ? Icons.info_outline : Icons.lock_outline,
          size: 14,
          color: appTheme.bg.withAlpha(canHost ? 200 : 150),
        ),
        const SizedBox(width: 6),
        Text(
          canHost
              ? '$remaining free hostings left this week'
              : 'Weekly limit reached',
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: appTheme.bg.withAlpha(canHost ? 200 : 150),
          ),
        ),
      ],
    );
  }

  Widget _buildSurvivalFreeTierInfo(BuildContext context, AppTheme appTheme) {
    final controller = context.watch<MainScreenController>();
    final userLimits = controller.userLimitsDto;

    // Don't show anything for Pro users or if limits aren't loaded
    if (userLimits == null || userLimits.isSurvivalUnlimited) {
      return const SizedBox.shrink();
    }

    final bool canPlay = userLimits.canPlaySurvival;
    final int remaining = userLimits.survivalRunsRemaining;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          canPlay ? Icons.info_outline : Icons.lock_outline,
          size: 14,
          color: appTheme.bg.withAlpha(canPlay ? 200 : 150),
        ),
        const SizedBox(width: 6),
        Text(
          canPlay ? '$remaining free runs left today' : 'Daily limit reached',
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: appTheme.bgLight.withAlpha(canPlay ? 200 : 150),
          ),
        ),
      ],
    );
  }

  const GamesTab({
    super.key,
    this.displayName,
    required this.onPartyCardTapped,
    required this.onSurvivalCardTapped,
  });

  /// User's display name for the welcome message.
  final String? displayName;

  /// Callback when the Party card is tapped.
  final VoidCallback onPartyCardTapped;

  /// Callback when the Survival card is tapped.
  final VoidCallback onSurvivalCardTapped;

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            _buildTopBar(appTheme),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 24),
                    _buildWelcomeMessage(context, appTheme),
                    const SizedBox(height: 48),
                    const DailyQuestionCarousel(),
                    const SizedBox(height: 24),
                    _buildSurvivalCard(context, appTheme),
                    const SizedBox(height: 24),
                    _buildPartyCard(context, appTheme),
                  ],
                ),
              ),
            ),
          ],
        ));
  }

  Widget _buildTopBar(AppTheme appTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/llc_logo.svg',
            height: 24,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              width: 1,
              height: 24,
              color: appTheme.borderMuted,
            ),
          ),
          SvgPicture.asset(
            'assets/icons/logo-fg.svg',
            height: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildWelcomeMessage(BuildContext context, AppTheme appTheme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Hello, ${displayName ?? "Guest"}!',
            textAlign: TextAlign.center,
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: appTheme.text,
              height: 1.2,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Ready to Guesstimate?',
            textAlign: TextAlign.center,
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: appTheme.textMuted,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPartyCard(BuildContext context, AppTheme appTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: BounceEffectWrapper(
        onTap: onPartyCardTapped,
        decoration: BoxDecoration(
          color: appTheme.secondary,
          borderRadius: BorderRadius.circular(appTheme.borderRadius),
          boxShadow: const [], // No shadow for Party card
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Party',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: appTheme.bg,
                        ),
                      ),
                      Text(
                        'Play a round with friends.',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: appTheme.bg.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.grid_view_rounded,
                  size: 48,
                  color: appTheme.bg,
                )
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFreeTierInfo(context, appTheme),
                Text(
                  'Tap to play',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: appTheme.bg.withAlpha(200),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurvivalCard(BuildContext context, AppTheme appTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: BounceEffectWrapper(
        onTap: onSurvivalCardTapped,
        decoration: BoxDecoration(
          color: appTheme.survival,
          borderRadius: BorderRadius.circular(appTheme.borderRadius),
          boxShadow: const [],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Survival',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: appTheme.bgLight,
                        ),
                      ),
                      Text(
                        'Beat the average player. Play\nuntil you loose.',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: appTheme.bgLight.withAlpha(200),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.local_fire_department,
                  size: 48,
                  color: appTheme.bgLight,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSurvivalFreeTierInfo(context, appTheme),
                Text(
                  'Tap to play',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: appTheme.bgLight.withAlpha(200),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
