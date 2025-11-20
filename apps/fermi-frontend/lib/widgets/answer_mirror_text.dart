import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/utils/om_constants.dart';

/// Displays a human-readable mirror of the answer widget state.
///
/// Format: "123 million meters" (removes leading zeros, shows full names)
/// Uses AnimatedSize to smoothly transition between different text lengths.
///
/// During reveal (when submittedAnswer is provided and editable is false),
/// freezes on the submitted answer and stops mirroring the current value.
/// This allows users to see their submitted answer alongside the correct answer.
class AnswerMirrorText extends StatefulWidget {
  const AnswerMirrorText({
    super.key,
    required this.value,
    required this.unitOptions,
    this.submittedAnswer,
    this.editable = true,
  });

  final AnswerValue value;
  final Map<String, String> unitOptions; // Full name -> abbreviation
  final AnswerValue?
      submittedAnswer; // Player's submitted answer (frozen during reveal)
  final bool editable; // False during reveal/locked states

  @override
  State<AnswerMirrorText> createState() => _AnswerMirrorTextState();
}

class _AnswerMirrorTextState extends State<AnswerMirrorText> {
  String _getOmFullName(String omSymbol) {
    if (omSymbol.isEmpty) return '';

    // Find index in symbols list
    final index = orderOfMagnitudeSymbols.indexOf(omSymbol);
    if (index < 0 || index >= orderOfMagnitudeWords.length) return '';

    // Return the full word (lowercase)
    return orderOfMagnitudeWords[index].toLowerCase();
  }

  String _getUnitFullName(String unitAbbr) {
    if (unitAbbr.isEmpty) return '';

    // Find the full name from widget.unitOptions (key where value matches abbreviation)
    for (final entry in widget.unitOptions.entries) {
      if (entry.value == unitAbbr) {
        return entry.key.toLowerCase();
      }
    }
    return unitAbbr; // Fallback to abbreviation if not found
  }

  String _formatAnswer() {
    // During reveal (not editable + has submitted answer), show submitted answer
    // Otherwise, show current answer value
    final AnswerValue displayValue =
        (!widget.editable && widget.submittedAnswer != null)
            ? widget.submittedAnswer!
            : widget.value;

    final parts = <String>[];

    // Add number (no leading zeros)
    parts.add(displayValue.number.toString());

    // Add OM full name if present
    final omName = _getOmFullName(displayValue.orderOfMagnitude);
    if (omName.isNotEmpty) {
      parts.add(omName);
    }

    // Add unit full name if present
    final unitName = _getUnitFullName(displayValue.unit);
    if (unitName.isNotEmpty) {
      parts.add(unitName);
    }

    return parts.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final baseStyle = AppFont.primaryTextStyle(
      context,
      fontSize: 12,
      fontWeight: FontWeight.w300,
      decoration: TextDecoration.none,
    ).copyWith(
      letterSpacing: 1.5,
    );

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Your answer: ',
              style: baseStyle.copyWith(
                color: appTheme.borderMuted,
              ),
            ),
            TextSpan(
              text: _formatAnswer(),
              style: baseStyle.copyWith(
                fontWeight: FontWeight.w600,
                color: appTheme.border,
                letterSpacing: 2.5,
              ),
            ),
          ],
        ),
        textAlign: TextAlign.left,
      ),
    );
  }
}
