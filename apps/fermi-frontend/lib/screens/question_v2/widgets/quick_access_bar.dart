import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// A draggable quick-access bar that triggers the numpad input sequence.
/// When dragged up, it opens the numpad for the first digit input.
/// When dragged down, it closes any open bottom sheets.
class QuickAccessBar extends StatefulWidget {
  const QuickAccessBar({
    super.key,
    required this.enabled,
    required this.onTrigger,
    required this.onClose,
  });

  /// Whether the quick access bar is enabled (should be editable)
  final bool enabled;

  /// Callback when drag threshold is reached to open numpad
  final VoidCallback onTrigger;

  /// Callback when downward drag is detected to close bottom sheets
  final VoidCallback onClose;

  @override
  State<QuickAccessBar> createState() => _QuickAccessBarState();
}

class _QuickAccessBarState extends State<QuickAccessBar> {
  static const double _dragThreshold =
      80.0; // Distance to drag before opening keyboard
  static const double _dragDownThreshold =
      20.0; // Distance to drag down before closing bottom sheets

  double _dragDistance = 0.0; // Current drag distance
  double _totalDownwardDrag = 0.0; // Track total downward drag

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      // Return an empty Container when disabled
      return Container();
    }

    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Calculate color interpolation based on drag progress
    final dragProgress = (_dragDistance / _dragThreshold).clamp(0.0, 1.0);
    final textColor = Color.lerp(
      appTheme.bgLight,
      appTheme.primary,
      dragProgress,
    )!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) {
        setState(() {
          _dragDistance = 0.0;
          _totalDownwardDrag = 0.0;
        });
      },
      onVerticalDragUpdate: (details) {
        setState(() {
          // Negative delta.dy means dragging up, positive means dragging down
          final deltaY = details.delta.dy;

          // Track downward drag separately
          if (deltaY > 0) {
            _totalDownwardDrag += deltaY;
          } else {
            _totalDownwardDrag = 0.0; // Reset if dragging up
          }

          // Update drag distance for upward drag (opening keyboard)
          _dragDistance -= deltaY;
          _dragDistance = _dragDistance.clamp(0.0, _dragThreshold);
        });

        // Close bottom sheets when dragging down past threshold
        if (_totalDownwardDrag >= _dragDownThreshold) {
          widget.onClose();
          // Reset drag tracking
          setState(() => _totalDownwardDrag = 0.0);
        }

        // Open keyboard when threshold reached (dragging up)
        if (_dragDistance >= _dragThreshold) {
          widget.onTrigger();
          // Reset after a short delay to allow animation
          Future.delayed(const Duration(milliseconds: 200), () {
            if (mounted) {
              setState(() => _dragDistance = 0.0);
            }
          });
        }
      },
      onVerticalDragEnd: (details) {
        // Snap back if threshold not reached
        if (_dragDistance < _dragThreshold) {
          setState(() {
            _dragDistance = 0.0;
            _totalDownwardDrag = 0.0;
          });
        }
      },
      child: Stack(
        children: [
          // Text vertically centered between dot indicator and submit bar
          // Dot indicator is ~33px from top, submit bar is 116px from top
          // Center is at ~74.5px from top (offset ~17px from center of quick access area)
          Positioned(
            bottom: 24 * 2 + 4,
            left: 0,
            right: 0,
            child: Transform.translate(
              offset: Offset(0, -_dragDistance * 0.25),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Swipe ',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: textColor,
                        decoration: TextDecoration.none,
                      ).copyWith(letterSpacing: 1),
                    ),
                    SvgPicture.asset(
                      'assets/icons/up-arrow.svg',
                      width: 14,
                      height: 14,
                      colorFilter: ColorFilter.mode(
                        textColor,
                        BlendMode.srcIn,
                      ),
                    ),
                    Text(
                      ' for Numpad',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: textColor,
                        decoration: TextDecoration.none,
                      ).copyWith(letterSpacing: 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
