import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/utils/color_contrast.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// Small capsule showing a submitted answer like "234 M km".
class SubmittedAnswerChip extends StatelessWidget {
  const SubmittedAnswerChip(
      {super.key, required this.answer, this.backgroundColor});

  final AnswerValue answer;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    // When used post-reveal, parent should pass the per-question score's scale color in
    // via an inherited wrapper; keep this component simple and let parent color the bg.
    // Map the submitted answer's numeric magnitude to a score scale proxy if available
    // Here we keep text color fg and change only background via a scale color when revealed
    final Color bgColor = backgroundColor ?? Colors.white;
    // Simple, robust rule: choose black or white based on WCAG contrast.
    final Color textColor = bestOn(bgColor);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(100),
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
            style: AppFont.secondaryTextStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w600, // Heavier weight for number + OM
              color: textColor,
            ),
          ),
          if (unitPart.isNotEmpty)
            TextSpan(
              text: unitPart,
              style: AppFont.secondaryTextStyle(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w300, // Light weight for unit
                color: textColor,
              ),
            ),
        ],
      ),
    );
  }
}
