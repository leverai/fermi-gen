import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// A selector widget using Material 3 Filter Chips in a grid layout.
/// Can be configured to allow no selection or enforce a default selection.
/// Uses AppTheme colors:
/// - Unselected: `bg` background, `border` text
/// - Selected: `bgDark` background, `text` text with border
///
/// The grid contains a configurable number of columns and as many rows as needed.
/// Chips always have equal widths and heights.
/// Can be configured to fill parent's width/height or use fixed size.
class SelectorWidget extends StatelessWidget {
  const SelectorWidget({
    super.key,
    required this.options,
    this.selected,
    required this.onChanged,
    this.allowNoSelection = true,
    this.closeOnReselect = false,
    this.useFixedSize = false,
    this.columns = 3,
  });

  /// List of selectable options
  final List<SelectorOption> options;

  /// Currently selected option value (null if no selection)
  final String? selected;

  /// Callback when selection changes
  final ValueChanged<String?> onChanged;

  /// If false, a selection is always required (clicking selected chip does nothing unless closeOnReselect is true)
  final bool allowNoSelection;

  /// If true, tapping the already-selected chip will trigger onChanged (useful for closing popups)
  final bool closeOnReselect;

  /// If true, uses fixed size based on content.
  /// Fixed size calculation: width = 48 * columns * 2, height = 48 * numRows
  /// If false, fills parent's width/height with a minimum height of 48px.
  final bool useFixedSize;

  /// Number of columns in the grid (default: 3).
  /// The grid will create as many rows as needed to display all options.
  final int columns;

  static const double _chipHeight = 40.0;
  static const double _spacing = 4.0;
  static const double _fontSize = 16.0;

  Widget _buildIcon(String? iconUrl, IconData? icon, Color color) {
    if (iconUrl != null) {
      return SvgPicture.network(
        iconUrl,
        width: 16,
        height: 16,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        placeholderBuilder: (context) => SizedBox(
          width: 16,
          height: 16,
          // ignore: deprecated_member_use
          child: Icon(Icons.circle, size: 8, color: color.withOpacity(0.3)),
        ),
      );
    } else if (icon != null) {
      return Icon(icon, size: 16, color: color);
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Calculate number of rows needed
    final int numRows = (options.length / columns).ceil();

    // Wrap in container with styling
    final container = Container(
      decoration: const BoxDecoration(),
      padding: const EdgeInsets.all(_spacing),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate chip width based on available space (after padding)
          final double availableWidth = constraints.maxWidth;
          final double chipWidth =
              (availableWidth - (_spacing * (columns - 1))) / columns;
          final double aspectRatio = chipWidth / _chipHeight;

          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            childAspectRatio: aspectRatio,
            children: options.map((option) {
              return _buildChip(context, appTheme, option);
            }).toList(),
          );
        },
      ),
    );

    // If using fixed size, wrap with SizedBox to constrain dimensions
    if (useFixedSize) {
      // Fixed size calculation: width = 48 * columns * 2 (for reasonable chip width)
      // height = 48 * numRows (48px per row)
      // Using 48px as base unit for consistency with spec
      const double baseUnit = 48.0;
      final double fixedWidth = baseUnit * columns * 2;
      final double fixedHeight = baseUnit * numRows; // 48px per row

      return SizedBox(
        width: fixedWidth,
        height: fixedHeight,
        child: container,
      );
    }

    // For fill parent mode, ensure minimum height of 48px (for single row)
    // This ensures the row in main_screen.dart maintains 48px height
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: 48.0,
      ),
      child: container,
    );
  }

  Widget _buildChip(
      BuildContext context, AppTheme appTheme, SelectorOption option) {
    final bool isSelected = selected == option.value;

    return GestureDetector(
      onTap: () {
        if (isSelected && !allowNoSelection && !closeOnReselect) return;
        onChanged(isSelected
            ? (allowNoSelection ? null : option.value)
            : option.value);
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? appTheme.bgDark : appTheme.bg,
          border: isSelected
              ? Border.all(
                  color: appTheme.border,
                  width: 2,
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.iconUrl != null || option.icon != null) ...[
              _buildIcon(
                option.iconUrl,
                option.icon,
                isSelected ? appTheme.text : appTheme.border,
              ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(
                option.label,
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: _fontSize,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? appTheme.text : appTheme.border,
                  height: 1.2,
                ).copyWith(letterSpacing: 0.8),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Represents a single selectable option in the SelectorWidget
class SelectorOption {
  const SelectorOption({
    required this.label,
    required this.value,
    this.icon,
    this.iconUrl,
  });

  /// Display label for the option
  final String label;

  /// Value returned when this option is selected
  final String value;

  /// Optional Material icon to display before the label
  final IconData? icon;

  /// Optional URL to an SVG icon (takes precedence over icon if both provided)
  final String? iconUrl;
}
