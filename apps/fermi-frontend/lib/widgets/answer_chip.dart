import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/color_contrast.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// A chip displaying the submitted answer.
///
/// Layout:
/// ```
/// Answer
/// <answer>
/// ```
class AnswerChip extends StatelessWidget {
  const AnswerChip({
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
      padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical:
              6), // Slightly more padding often looks better with asymmetric corners
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4), // The "sharp" corner for the quote look
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: _buildAnswerText(context, textColor),
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
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
            ).copyWith(height: 1.0),
          ),
          if (unitPart.isNotEmpty)
            TextSpan(
              text: unitPart,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: textColor,
              ).copyWith(height: 1.0),
            ),
        ],
      ),
    );
  }
}
