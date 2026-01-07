import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/screens/main/widgets/daily_question_carousel.dart';
import 'package:fermi_frontend/widgets/bounce_effect_wrapper.dart';

/// Displays the "Games" tab content with game options.
///
/// Contains the top bar, welcome message, Daily Question carousel, and Party card.
class GamesTab extends StatelessWidget {
  const GamesTab({
    super.key,
    this.displayName,
    required this.onPartyCardTapped,
  });

  /// User's display name for the welcome message.
  final String? displayName;

  /// Callback when the Party card is tapped.
  final VoidCallback onPartyCardTapped;

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
                    const SizedBox(height: 32),
                    const DailyQuestionCarousel(),
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
                          color: appTheme.text,
                        ),
                      ),
                      Text(
                        'Play a round with friends.',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: appTheme.text.withAlpha(140),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.grid_view_rounded,
                  size: 48,
                  color: appTheme.text.withAlpha(140),
                )
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                'Tap to play',
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: appTheme.text.withAlpha(140),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
