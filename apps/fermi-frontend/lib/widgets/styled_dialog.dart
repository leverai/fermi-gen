import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// A reusable styled dialog component with gradient borders and consistent styling.
///
/// This component can be used in two modes:
/// 1. **Standalone Dialog Mode** (`showAsDialog = true`): Wrapped in Flutter's `Dialog`
///    widget, suitable for use with `showDialog`.
/// 2. **Content Widget Mode** (`showAsDialog = false`): Returns just the styled
///    container, suitable for use within other widgets like `TutorialCoachMark`.
///
/// The component features:
/// - Gradient border styling (outer border gradient, inner background gradient)
/// - Consistent typography using `AppFont.primaryTextStyle`
/// - Customizable primary and secondary buttons
/// - Optional secondary message
/// - Support for custom button content via `primaryButtonWidget`
class StyledDialog extends StatelessWidget {
  const StyledDialog({
    super.key,
    required this.message,
    this.secondaryMessage,
    required this.primaryButtonLabel,
    required this.primaryButtonColor,
    required this.onPrimaryPressed,
    this.secondaryButtonLabel,
    this.onSecondaryPressed,
    this.showAsDialog = true,
    this.primaryButtonWidget,
  });

  /// Primary message text displayed at the top of the dialog.
  final String message;

  /// Optional secondary message text displayed below the primary message.
  final String? secondaryMessage;

  /// Label text for the primary button (used if `primaryButtonWidget` is null).
  final String primaryButtonLabel;

  /// Background color for the primary button.
  final Color primaryButtonColor;

  /// Callback when the primary button is pressed.
  final VoidCallback onPrimaryPressed;

  /// Optional label text for the secondary button.
  final String? secondaryButtonLabel;

  /// Optional callback when the secondary button is pressed.
  final VoidCallback? onSecondaryPressed;

  /// Whether to wrap the content in a `Dialog` widget.
  /// - `true`: Returns a `Dialog` widget (for use with `showDialog`)
  /// - `false`: Returns just the styled container (for use as content widget)
  final bool showAsDialog;

  /// Optional custom widget for the primary button content.
  /// If provided, this will be used instead of `primaryButtonLabel`.
  /// Useful for custom formatting like step counters with `RichText`.
  final Widget? primaryButtonWidget;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    final content = _buildContent(context, appTheme);

    if (showAsDialog) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 48),
        child: content,
      );
    }

    return content;
  }

  Widget _buildContent(BuildContext context, AppTheme appTheme) {
    final container = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomCenter,
          colors: [
            appTheme.border,
            appTheme.borderMuted,
            appTheme.borderMuted,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        margin: const EdgeInsets.all(1), // 1px border effect
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomCenter,
            colors: [
              appTheme.bgLight,
              appTheme.bg,
            ],
            stops: const [0.0, 1.0],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primary message
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message,
                  textAlign: TextAlign.left,
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: appTheme.text,
                    height: 1.5,
                  ).copyWith(
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              // Secondary message (if provided)
              if (secondaryMessage != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    secondaryMessage!,
                    textAlign: TextAlign.left,
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                      color: appTheme.highlight,
                      height: 1.4,
                    ).copyWith(
                      decoration: TextDecoration.none,
                    ),
                  ),
                ),
              ],
              // Buttons
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Secondary button (if provided)
                  if (secondaryButtonLabel != null &&
                      onSecondaryPressed != null)
                    SizedBox(
                      height: 12 * 4,
                      width: 12 * 9,
                      child: OutlinedButton(
                        onPressed: onSecondaryPressed,
                        style: ButtonStyle(
                          side: WidgetStateProperty.all(BorderSide.none),
                          minimumSize: WidgetStateProperty.all(
                            const Size(240, 48),
                          ),
                          maximumSize: WidgetStateProperty.all(
                            const Size(240, 48),
                          ),
                          padding: WidgetStateProperty.all(EdgeInsets.zero),
                          shape: WidgetStateProperty.all(
                            RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          overlayColor: WidgetStateProperty.resolveWith<Color?>(
                            (Set<WidgetState> states) {
                              if (states.contains(WidgetState.hovered) ||
                                  states.contains(WidgetState.pressed)) {
                                return appTheme.border;
                              }
                              return null;
                            },
                          ),
                        ),
                        child: Text(
                          secondaryButtonLabel!,
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: appTheme.highlight,
                          ).copyWith(letterSpacing: 0.2),
                        ),
                      ),
                    ),
                  if (secondaryButtonLabel != null &&
                      onSecondaryPressed != null)
                    const SizedBox(width: 24),
                  // Primary button
                  SizedBox(
                    height: 12 * 4,
                    width: 12 * 9,
                    child: ElevatedButton(
                      onPressed: onPrimaryPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryButtonColor,
                        foregroundColor: appTheme.bg,
                        minimumSize: const Size(240, 48),
                        maximumSize: const Size(240, 48),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: primaryButtonWidget ??
                          Text(
                            primaryButtonLabel,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: appTheme.bg,
                            ).copyWith(letterSpacing: 0.2),
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // When not showing as dialog, add 28px horizontal margin and fill parent width
    if (!showAsDialog) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        child: container,
      );
    }

    return container;
  }
}
