import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/utils/om_constants.dart';

/// A widget that mirrors the slider's value as formatted text in real-time.
///
/// Displays the current answer value in a human-readable format:
/// - "124 Million" for 124M
/// - "1" for 1 (no OM)
/// - "999 Trillion" for 999T
class SliderTextMirror extends StatelessWidget {
  const SliderTextMirror({
    super.key,
    required this.value,
    this.fontSize = 14.0,
    this.fontWeight = FontWeight.w500,
  });

  final AnswerValue value;
  final double fontSize;
  final FontWeight fontWeight;

  /// Get the full word for an order of magnitude symbol.
  String _getOMWord(String omSymbol) {
    final index = orderOfMagnitudeSymbols.indexOf(omSymbol);
    if (index < 0 || index >= orderOfMagnitudeWords.length) {
      return '';
    }
    return orderOfMagnitudeWords[index];
  }

  /// Format the answer value as display text.
  String _formatValue(AnswerValue answer) {
    final omWord = _getOMWord(answer.orderOfMagnitude);
    if (omWord.isEmpty) {
      // No order of magnitude, just show the number
      return '${answer.number}';
    }
    // Capitalize first letter of OM word
    final capitalizedWord = omWord[0].toUpperCase() + omWord.substring(1);
    return '${answer.number} $capitalizedWord';
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      decoration: BoxDecoration(
        color: appTheme.bgDark,
        borderRadius: BorderRadius.circular(60),
      ),
      child: Text(
        _formatValue(value),
        style: AppFont.primaryTextStyle(
          context,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: appTheme.text,
        ),
      ),
    );
  }
}
