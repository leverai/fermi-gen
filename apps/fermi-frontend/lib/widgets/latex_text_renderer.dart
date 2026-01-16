import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:latext/latext.dart';

/// A widget that renders text with inline LaTeX expressions.
///
/// LaTeX expressions in the text are delimited by `$...$`.
/// This widget uses the latext package for proper KaTeX-compatible rendering.
class LatexTextRenderer extends StatelessWidget {
  const LatexTextRenderer({
    super.key,
    required this.text,
    this.latexExpressions = const [],
    this.textStyle,
    this.textColor,
  });

  /// The full text containing LaTeX expressions (e.g., "The formula is $e^{ix}$").
  final String text;

  /// List of LaTeX expressions that appear in the text (from snippet_latex).
  /// Note: This is provided for compatibility but latext parses $...$ directly.
  final List<String> latexExpressions;

  /// Optional text style for non-LaTeX text.
  final TextStyle? textStyle;

  /// Optional text color.
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final effectiveTextStyle = textStyle ??
        AppFont.primaryTextStyle(
          context,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textColor ?? appTheme.text,
          height: 1.5,
        );

    // If no LaTeX delimiters, just return plain text
    if (!text.contains(r'$')) {
      return Text(text, style: effectiveTextStyle);
    }

    // Use LaTexT for mixed text/math content
    // LaTexT automatically parses $...$ delimiters
    return LaTexT(
      laTeXCode: Text(text, style: effectiveTextStyle),
    );
  }
}

/// A simpler widget for rendering a standalone LaTeX block expression.
class LatexBlock extends StatelessWidget {
  const LatexBlock({
    super.key,
    required this.latex,
    this.textStyle,
    this.alignment = Alignment.centerLeft,
  });

  final String latex;
  final TextStyle? textStyle;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Align(
      alignment: alignment,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: appTheme.primary.withAlpha(15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: appTheme.primary.withAlpha(40),
            width: 1,
          ),
        ),
        // Wrap in $...$ if not already delimited for latext parsing
        child: LaTexT(
          laTeXCode: Text(
            latex.startsWith(r'$') ? latex : '\$$latex\$',
            style: TextStyle(
              fontFamily: 'serif',
              fontStyle: FontStyle.italic,
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: appTheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
