import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// Data model for category chip items.
class CategoryChipItem {
  final String id;
  final String title;

  const CategoryChipItem({
    required this.id,
    required this.title,
  });
}

/// A reusable chip-based multi-selection widget for categories.
///
/// Features:
/// - Two sections: input box (Coming Soon) and chip selection area
/// - Selected chips appear in the input box area
/// - Unselected chips appear in the "Or select:" area
/// - Fixed container height regardless of selection state
/// - Uses hue-incrementing color system for chip colors
class CategoryChipSelector extends StatefulWidget {
  final List<CategoryChipItem> categories;
  final Set<int> initialSelectedIndices;
  final ValueChanged<Set<int>>? onSelectionChanged;
  final HSLColor startColor;

  const CategoryChipSelector({
    super.key,
    required this.categories,
    this.initialSelectedIndices = const {},
    this.onSelectionChanged,
    this.startColor = const HSLColor.fromAHSL(1.0, 175.75, 0.56, 0.55),
  });

  @override
  State<CategoryChipSelector> createState() => _CategoryChipSelectorState();
}

class _CategoryChipSelectorState extends State<CategoryChipSelector> {
  late Set<int> _selectedIndices;
  final ScrollController _scrollController = ScrollController();

  // Fixed height for consistent layout
  static const double _inputBoxHeight = 48.0;

  @override
  void initState() {
    super.initState();
    _selectedIndices = Set<int>.from(widget.initialSelectedIndices);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CategoryChipSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedIndices != widget.initialSelectedIndices) {
      _selectedIndices = Set<int>.from(widget.initialSelectedIndices);
      // Also scroll to end if external selection changes? Maybe safest.
      _scrollToEnd();
    }
  }

  /// Compute the color for a category at the given index.
  /// Uses the same formula as the carousel: hue = startHue + (idx+1) * 53
  Color _getCategoryColor(int index) {
    final hue = (widget.startColor.hue + (index + 1) * 53) % 360;
    return HSLColor.fromAHSL(
      1.0,
      hue,
      widget.startColor.saturation,
      widget.startColor.lightness,
    ).toColor();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
    widget.onSelectionChanged?.call(Set<int>.from(_selectedIndices));
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Section label
        Text(
          'Type categories:',
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: appTheme.text,
          ),
        ),
        const SizedBox(height: 16),
        // Input box area with selected chips
        _buildInputBoxArea(appTheme),
        const SizedBox(height: 24),
        // "Or select:" label
        Text(
          'or select:',
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: appTheme.textMuted,
          ),
        ),
        const SizedBox(height: 16),
        // Chip selection area
        _buildChipSelectionArea(appTheme),
      ],
    );
  }

  Widget _buildInputBoxArea(AppTheme appTheme) {
    final selectedChips = <Widget>[];

    for (int i = 0; i < widget.categories.length; i++) {
      if (_selectedIndices.contains(i)) {
        selectedChips.add(
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: CategoryChip(
              label: widget.categories[i].title,
              color: _getCategoryColor(i),
              isSelected: true,
              onTap: () => _toggleSelection(i),
            ),
          ),
        );
      }
    }

    return Container(
      height: _inputBoxHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: appTheme.bgDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appTheme.borderMuted, width: 1),
      ),
      child: selectedChips.isEmpty
          ? _buildPlaceholder(appTheme)
          : SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(children: selectedChips),
            ),
    );
  }

  Widget _buildPlaceholder(AppTheme appTheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'E.g. Christmas',
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: appTheme.borderMuted,
            ),
          ),
          Text(
            '(Coming Soon)',
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: appTheme.borderMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChipSelectionArea(AppTheme appTheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(widget.categories.length, (index) {
        final isSelected = _selectedIndices.contains(index);
        final color = _getCategoryColor(index);

        return CategoryChip(
          label: widget.categories[index].title,
          color: color,
          isSelected: isSelected, // Pass actual selection state for opacity
          showCheckmark: false, // Never show checkmark in this area
          onTap: () => _toggleSelection(index),
        );
      }),
    );
  }
}

/// A single category chip with selection state.
///
/// Features:
/// - Unselected: low-alpha background, no border
/// - Selected: higher-alpha background with optional checkmark
/// - InkWell with splash effect for tactile feedback
class CategoryChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final bool showCheckmark;
  final VoidCallback? onTap;

  static const double _height = 32.0;

  const CategoryChip({
    super.key,
    required this.label,
    required this.color,
    required this.isSelected,
    this.showCheckmark = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Background alpha: low for unselected, higher for selected
    final bgColor = isSelected
        ? color.withAlpha((255 * 0.35).round())
        : color.withAlpha((255 * 0.12).round());

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        splashColor: isSelected
            ? Colors.transparent
            : color.withAlpha((255 * 0.3).round()),
        highlightColor: isSelected
            ? Colors.transparent
            : color.withAlpha((255 * 0.15).round()),
        child: Container(
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected && showCheckmark) ...[
                Icon(
                  Icons.check,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: isSelected ? appTheme.text : appTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
