import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum PAChiermontTier {
  top1('GODLIKE', 'Behold, for he hath not guessed, but divined.', '🤯'),
  top5('EXQUISITE', 'You cooked with this one!', '😎'),
  top10('ACE', 'You\'re on the dean\'s list.', '😏'),
  bottom10('Source: Trust Me Bro',
      'Confidence: 100%. Accuracy: 0%. A dangerous combination.', '🤭'),
  bottom5('WRONG GALAXY',
      'You are statistically significant, but not in a good way.', '😪'),
  bottom1('Um...', 'Should we be worried about you?', '😵‍💫');

  final String title;
  final String description;
  final String emoji;

  const PAChiermontTier(this.title, this.description, this.emoji);
}

class PACard extends StatelessWidget {
  const PACard({
    super.key,
    required this.percentile,
    required this.questionText,
    required this.userAnswer,
    required this.correctAnswer,
  });

  /// The player's percentile (0.0 to 100.0).
  /// 99.0 means top 1% (best). 1.0 means bottom 1% (worst).
  final double percentile;
  final String questionText;
  final String userAnswer;
  final String correctAnswer;

  PAChiermontTier? _getTier() {
    if (percentile >= 99) return PAChiermontTier.top1;
    if (percentile >= 95) return PAChiermontTier.top5;
    if (percentile >= 90) return PAChiermontTier.top10;
    if (percentile <= 1) return PAChiermontTier.bottom1;
    if (percentile <= 5) return PAChiermontTier.bottom5;
    if (percentile <= 10) return PAChiermontTier.bottom10;
    return null;
  }

  Color _getThemeColor(AppTheme theme, PAChiermontTier tier) {
    final hsl = HSLColor.fromColor(theme.success);
    final nextHue = (hsl.hue + ((tier.index - 1) * 53)) % 360;
    return hsl.withHue(nextHue).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final tier = _getTier();

    if (tier == null) {
      return const SizedBox.shrink();
    }

    final themeColor = _getThemeColor(appTheme, tier);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: appTheme.bgLight,
        borderRadius: BorderRadius.circular(appTheme.borderRadius),
        border: Border.all(
          color: appTheme.border,
          width: appTheme.borderWidth,
        ),
        boxShadow: [
          BoxShadow(
            color: appTheme.shadowColor,
            offset: appTheme.shadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: themeColor.withAlpha(40),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(appTheme.borderRadius - 1),
                topRight: Radius.circular(appTheme.borderRadius - 1),
              ),
              border: Border(
                bottom: BorderSide(
                  color: appTheme.border,
                  width: appTheme.borderWidth,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(tier.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.title.toUpperCase(),
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: themeColor,
                          height: 1.1,
                        ).copyWith(letterSpacing: 1.0),
                      ),
                      Text(
                        percentile > 50
                            ? 'Top ${100 - percentile}%'
                            : 'Bottom ${percentile}%',
                        style: AppFont.secondaryTextStyle(
                          context,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: appTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.description,
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 16,
                    height: 1.4,
                    color: appTheme.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
                Divider(color: appTheme.borderMuted, height: 1),
                const SizedBox(height: 16),
                Text(
                  'The Question:',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 12,
                    color: appTheme.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  questionText,
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 14,
                    color: appTheme.text,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'You Said:',
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 12,
                              color: appTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            userAnswer,
                            style: AppFont.secondaryTextStyle(
                              context,
                              fontSize: 16,
                              color: appTheme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Answer:',
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 12,
                              color: appTheme.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            correctAnswer,
                            style: AppFont.secondaryTextStyle(
                              context,
                              fontSize: 16,
                              color: appTheme.text,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
