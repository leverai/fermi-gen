import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/color_contrast.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// A card displaying the submitted answer and score in a single column.
///
/// Layout:
/// ```
/// Answer
/// <answer>
/// ────────
/// Score
/// <score>
/// ```
class AnswerScoreCard extends StatelessWidget {
  const AnswerScoreCard({
    super.key,
    required this.answer,
    required this.score,
    this.backgroundColor,
  });

  final AnswerValue answer;
  final int score;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final Color bgColor = backgroundColor ?? appTheme.bgLight;
    final Color textColor = bestOn(bgColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: "Answer: <answer>"
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ans.',
                style: AppFont.secondaryTextStyle(
                  context,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: appTheme.textMuted,
                ).copyWith(
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                ' |  ',
                style: AppFont.secondaryTextStyle(
                  context,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: appTheme.borderMuted,
                ),
              ),
              _buildAnswerText(context, textColor),
            ],
          ),
          const SizedBox(height: 2),
          // Row 2: "Score: <score>"
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pts.',
                style: AppFont.secondaryTextStyle(
                  context,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: appTheme.textMuted,
                ).copyWith(
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                '  |  ',
                style: AppFont.secondaryTextStyle(
                  context,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: appTheme.borderMuted,
                ),
              ),
              Text(
                '+${_formatWithCommas(score)}',
                style: AppFont.secondaryTextStyle(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: appTheme.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerText(BuildContext context, Color textColor) {
    // Build parts separately to apply different font weights
    final String numberPart = answer.number.toString();
    final String omPart =
        answer.orderOfMagnitude.isEmpty ? '' : answer.orderOfMagnitude;
    final String unitPart = answer.unit.isEmpty ? '' : ' ${answer.unit}';

    // Number and OM get heavier weight, unit stays light
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: numberPart + omPart,
            style: AppFont.secondaryTextStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          if (unitPart.isNotEmpty)
            TextSpan(
              text: unitPart,
              style: AppFont.secondaryTextStyle(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: textColor,
              ),
            ),
        ],
      ),
    );
  }

  String _formatWithCommas(int number) {
    return number.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }
}
