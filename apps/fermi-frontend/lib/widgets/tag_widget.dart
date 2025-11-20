import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// A reusable tag widget that displays a short text label within a styled container.
///
/// The appearance is themeable using [AppTheme].
/// The widget displays text in a "pill" shape with rounded corners and a border.
class TagWidget extends StatelessWidget {
  /// Creates a [TagWidget].
  ///
  /// The [text] parameter is required and represents the label to display.
  /// The [category] parameter is optional and can be used to identify the context
  /// for potential future theming extensions.
  const TagWidget({
    super.key,
    required this.text,
    this.category,
  });

  /// The text label to display within the tag.
  final String text;

  /// Optional category identifier for the tag.
  /// This can be used for future theming or styling purposes.
  final String? category;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        margin: const EdgeInsets.only(
          left: 0.3,
          right: 0.3,
          top: 0.3,
          bottom: 0.5, // Slightly thicker at bottom for gradient effect
        ),
        child: Text(
          text,
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: appTheme.borderMuted,
            decoration: TextDecoration.none,
          ).copyWith(
            letterSpacing: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
