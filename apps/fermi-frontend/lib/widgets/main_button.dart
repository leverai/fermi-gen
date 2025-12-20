// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/circular_determinate_spinner.dart';

/// A highly stylized main action button with a space-bar look.
///
/// - Size scales proportionally to the screen based on a 402x874 baseline
///   where the button measures 175x48.
/// - Supports an optional label from a predefined set and an optional
///   spacebar-like glyph (a short horizontal line near the bottom).
/// - Uses AppTheme colors: button face uses `primary`, text/glyph use `bgDark`
///   for optimal contrast against the primary color.

/// Allowed labels for the main button.
enum MainButtonLabel { create, join, start, submit, next, finish }

extension MainButtonLabelText on MainButtonLabel {
  String get text {
    switch (this) {
      case MainButtonLabel.create:
        return 'Create';
      case MainButtonLabel.join:
        return 'Join';
      case MainButtonLabel.start:
        return 'Start';
      case MainButtonLabel.submit:
        return 'Submit';
      case MainButtonLabel.next:
        return 'Next';
      case MainButtonLabel.finish:
        return 'Finish';
    }
  }
}

class MainButtonController extends ChangeNotifier {
  /// Triggers a visual press animation on the attached MainButton.
  /// This does not invoke onPressed; callers should trigger actions separately.
  void triggerPress() {
    notifyListeners();
  }
}

class MainButton extends StatefulWidget {
  /// Creates a MainButton.
  ///
  /// The [onPressed] callback is called when the button is tapped.
  /// If [onPressed] is null, the button will be disabled.
  /// If [isLoading] is true, the button will show a DotsSpinner and be disabled.
  const MainButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.iconAssetPath,
    this.label,
    this.showSpacebarGlyph = false,
    this.controller,
  });

  /// Called when the button is tapped.
  ///
  /// If null, the button will be disabled and shown with reduced opacity.
  /// This can be an async function for operations that need loading state.
  final VoidCallback? onPressed;

  /// Whether to show the loading spinner instead of the play icon.
  ///
  /// When true, the button displays a DotsSpinner and becomes non-interactive.
  final bool isLoading;

  /// Optional icon asset path to display instead of the default controller icon.
  ///
  /// The icon will be tinted using the app theme's bgDark color for contrast.
  /// Defaults to 'assets/icons/controller.png' when not provided.
  final String? iconAssetPath;

  /// Optional predefined label to display in the center of the button.
  final MainButtonLabel? label;

  /// Whether to render the spacebar-like glyph (a short horizontal line)
  /// near the bottom of the button face. Defaults to false.
  final bool showSpacebarGlyph;

  /// Optional controller to programmatically trigger the press animation.
  final MainButtonController? controller;

  @override
  State<MainButton> createState() => _MainButtonState();
}

class _MainButtonState extends State<MainButton>
    with SingleTickerProviderStateMixin {
  /// Whether the button is currently being pressed
  bool _isPressed = false;

  /// Whether the button is currently being hovered (desktop/web)
  bool _isHovered = false;

  /// Whether the button is enabled (has a non-null onPressed callback and is not loading)
  bool get _isEnabled => widget.onPressed != null && !widget.isLoading;

  VoidCallback? _controllerListener;

  // Baseline design used for spacebar glyph sizing (screen 402x874 -> button 175x48)
  static const double _baselineScreenWidth = 402.0;
  static const double _baselineButtonWidth = 175.0;

  // Hover overlay color
  static const Color _hoverOverlayColor =
      Color(0x1AFFFFFF); // rgba(255, 255, 255, 0.1)

  void _onTapDown(TapDownDetails details) {
    if (_isEnabled) {
      setState(() {
        _isPressed = true;
      });
    }
  }

  void _onPanDown(DragDownDetails details) {
    // Pan down fires even faster than tap down for immediate feedback
    if (_isEnabled) {
      setState(() {
        _isPressed = true;
      });
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (_isEnabled) {
      setState(() {
        _isPressed = false;
      });
      widget.onPressed?.call();
    }
  }

  void _onTapCancel() {
    if (_isEnabled) {
      setState(() {
        _isPressed = false;
      });
    }
  }

  void _onHover(bool hovering) {
    if (_isEnabled) {
      setState(() {
        _isHovered = hovering;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final Color buttonFaceColor = appTheme.primary;
    final Color iconFgColor = appTheme.bg;

    // Use fixed height of 48px
    const double buttonHeight = 48.0;
    final double borderRadius = appTheme.borderRadius;

    // Use calculated width for spacebar glyph sizing, but allow button to fill available width
    final Size screenSize = MediaQuery.of(context).size;
    final double calculatedButtonWidth =
        screenSize.width * (_baselineButtonWidth / _baselineScreenWidth);

    return Opacity(
      opacity: _isEnabled ? 1.0 : 0.4,
      child: SizedBox(
        width: double.infinity,
        height: buttonHeight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onPanDown: _onPanDown,
          child: MouseRegion(
            onEnter: (_) => _onHover(true),
            onExit: (_) => _onHover(false),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Shadow Layer (static)
                Positioned(
                  top: appTheme.shadowOffset.dy,
                  left: appTheme.shadowOffset.dx,
                  right: -appTheme.shadowOffset
                      .dx, // Extend to match width shift if needed, but here we just offset
                  bottom: -appTheme.shadowOffset.dy,
                  child: Container(
                    height: buttonHeight,
                    decoration: BoxDecoration(
                      color: appTheme.shadowColor,
                      borderRadius: BorderRadius.circular(borderRadius),
                    ),
                  ),
                ),
                // Button Face (top layer with color/position animation)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 50),
                  curve: Curves.easeOut,
                  top: _isPressed ? appTheme.shadowOffset.dy : 0.0,
                  left: _isPressed ? appTheme.shadowOffset.dx : 0.0,
                  right: _isPressed
                      ? -appTheme.shadowOffset.dx
                      : 0.0, // Keep width consistent
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: buttonHeight,
                        decoration: BoxDecoration(
                          color: buttonFaceColor,
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        child: Stack(
                          children: [
                            if (_isHovered)
                              Container(
                                decoration: BoxDecoration(
                                  color: _hoverOverlayColor,
                                  borderRadius:
                                      BorderRadius.circular(borderRadius),
                                ),
                              ),
                            if (_isPressed)
                              Container(
                                decoration: BoxDecoration(
                                  color: appTheme.text.withOpacity(0.2),
                                  borderRadius:
                                      BorderRadius.circular(borderRadius),
                                ),
                              ),
                            // Show content when not loading
                            if (!widget.isLoading) ...[
                              // Optional label placed near the top center
                              if (widget.label != null)
                                Positioned(
                                  top: buttonHeight * 0.14,
                                  left: 0,
                                  right: 0,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Text(
                                      widget.label!.text,
                                      textAlign: TextAlign.center,
                                      style: AppFont.primaryTextStyle(context,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w400,
                                              color: appTheme.text,
                                              decoration: TextDecoration.none)
                                          .copyWith(letterSpacing: 1.5),
                                    ),
                                  ),
                                ),
                              // Optional custom icon (fallback behavior from earlier API)
                              if (widget.label == null &&
                                  widget.iconAssetPath != null)
                                Center(
                                  child: ColorFiltered(
                                    colorFilter: ColorFilter.mode(
                                      iconFgColor,
                                      BlendMode.srcIn,
                                    ),
                                    child: Image.asset(
                                      widget.iconAssetPath!,
                                      width: 24,
                                      height: 24,
                                      errorBuilder:
                                          (context, error, stackTrace) => Icon(
                                        Icons.space_bar,
                                        color: iconFgColor,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ),
                              // Optional spacebar-like glyph near the bottom
                              if (widget.showSpacebarGlyph)
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: buttonHeight * 0.18,
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: SvgPicture.asset(
                                      widget.iconAssetPath ??
                                          'assets/icons/spacebar.svg',
                                      width: calculatedButtonWidth * 0.30,
                                      height: 8,
                                      colorFilter: ColorFilter.mode(
                                        appTheme.text,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      // Loading spinner positioned in top right corner
                      if (widget.isLoading)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularDeterminateSpinner(
                                progress: null, // null = indeterminate
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(covariant MainButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachController(oldWidget.controller);
      _attachController();
    }
  }

  void _attachController() {
    if (widget.controller == null) return;
    _controllerListener = () {
      if (!mounted) return;
      if (!_isEnabled) return;
      setState(() {
        _isPressed = true;
      });
      Future.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        setState(() {
          _isPressed = false;
        });
      });
    };
    widget.controller!.addListener(_controllerListener!);
  }

  void _detachController(MainButtonController? controller) {
    if (controller == null) return;
    if (_controllerListener != null) {
      controller.removeListener(_controllerListener!);
      _controllerListener = null;
    }
  }

  @override
  void dispose() {
    _detachController(widget.controller);
    super.dispose();
  }
}
