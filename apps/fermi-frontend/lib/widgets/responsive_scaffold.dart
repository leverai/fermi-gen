import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// Maximum width for content in responsive layouts.
/// Covers all phone sizes including larger models (iPhone Pro Max at 428px)
/// with headroom, while appearing well-centered on tablets and desktops.
const double kMaxContentWidth = 540.0;

/// A responsive scaffold wrapper that constrains content to a maximum width.
///
/// On narrow screens (< 540px), content fills the full width normally.
/// On wider screens (tablets, web), content is capped at 540px and centered.
///
/// Usage:
/// ```dart
/// ResponsiveScaffold(
///   backgroundColor: appTheme.bg,
///   body: YourContentWidget(),
///   bottomNavigationBar: YourBottomNav(), // optional
/// )
/// ```
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.backgroundColor,
    this.outerBackgroundColor,
  });

  /// The main content of the scaffold.
  final Widget body;

  /// Optional bottom navigation bar (will also be constrained).
  final Widget? bottomNavigationBar;

  /// Background color for the inner content area.
  final Color? backgroundColor;

  /// Background color for the outer area on wide screens.
  /// Defaults to `appTheme.bgDark`.
  final Color? outerBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final outerBg = outerBackgroundColor ?? appTheme.bgDark;
    final innerBg = backgroundColor ?? appTheme.bg;

    return Scaffold(
      backgroundColor: outerBg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
          child: ColoredBox(
            color: innerBg,
            child: body,
          ),
        ),
      ),
      bottomNavigationBar: bottomNavigationBar != null
          ? ColoredBox(
              color: outerBg,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
                  child: bottomNavigationBar,
                ),
              ),
            )
          : null,
    );
  }
}

/// A simpler wrapper for constraining content width without a full scaffold.
///
/// Use this inside existing Scaffolds or Stacks to constrain specific content.
class ResponsiveContentWrapper extends StatelessWidget {
  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  final Widget child;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    Widget content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
        child: child,
      ),
    );

    if (backgroundColor != null) {
      content = ColoredBox(
        color: backgroundColor!,
        child: content,
      );
    }

    return content;
  }
}
