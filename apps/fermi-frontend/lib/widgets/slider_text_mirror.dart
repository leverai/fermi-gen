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
    this.unitOptions = const {},
    this.fontSize = 14.0,
    this.fontWeight = FontWeight.w500,
  });

  final AnswerValue value;
  final Map<String, String> unitOptions; // Full name -> abbreviation map
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

  /// Format the answer value as display text (number + order of magnitude only).
  /// Unit is now displayed separately in UnitTape.
  String _formatValue(AnswerValue answer) {
    final omWord = _getOMWord(answer.orderOfMagnitude);
    final parts = <String>[answer.number.toString()];

    if (omWord.isNotEmpty) {
      // Capitalize first letter of OM word
      final capitalizedWord = omWord[0].toUpperCase() + omWord.substring(1);
      parts.add(capitalizedWord);
    }

    // Unit removed - now displayed in UnitTape widget

    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // No container styling - parent container handles background/padding
    return Text(
      _formatValue(value),
      style: AppFont.primaryTextStyle(
        context,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: appTheme.secondary,
      ),
    );
  }
}
