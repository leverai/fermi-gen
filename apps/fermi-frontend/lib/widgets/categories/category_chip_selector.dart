import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/services/feedback_service.dart';

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
/// - Two sections: a smart-search input box and a chip selection area
/// - Search and chip selection are mutually exclusive: typing a query greys
///   out the chips; tapping a chip clears the query (driven by the parent)
/// - Unselected chips appear in the "Or choose:" area
/// - Fixed container height regardless of selection state
/// - Uses hue-incrementing color system for chip colors
///
/// Smart search is gated by [searchEnabled]: when false the search box is
/// hidden entirely and the widget behaves exactly like the legacy chip
/// selector.
class CategoryChipSelector extends StatefulWidget {
  final List<CategoryChipItem> categories;
  final Set<int> initialSelectedIndices;
  final ValueChanged<Set<int>>? onSelectionChanged;
  final HSLColor startColor;

  /// Whether the smart-search box is shown (server flag). When false, the box
  /// is hidden and only the chips render.
  final bool searchEnabled;

  /// Controller backing the search [TextField]. Owned by the parent so the
  /// text survives rebuilds and can be set programmatically (e.g. tapping a
  /// recent-search chip). Required when [searchEnabled] is true.
  final TextEditingController? searchController;

  /// Called when the search text changes.
  final ValueChanged<String>? onSearchChanged;

  /// Whether a (non-empty) search is currently active. When true the chips
  /// are greyed out / disabled.
  final bool isSearching;

  const CategoryChipSelector({
    super.key,
    required this.categories,
    this.initialSelectedIndices = const {},
    this.onSelectionChanged,
    this.startColor = const HSLColor.fromAHSL(1.0, 175.75, 0.56, 0.55),
    this.searchEnabled = false,
    this.searchController,
    this.onSearchChanged,
    this.isSearching = false,
  });

  @override
  State<CategoryChipSelector> createState() => _CategoryChipSelectorState();
}

class _CategoryChipSelectorState extends State<CategoryChipSelector> {
  late Set<int> _selectedIndices;

  @override
  void initState() {
    super.initState();
    _selectedIndices = Set<int>.from(widget.initialSelectedIndices);
  }

  @override
  void didUpdateWidget(CategoryChipSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedIndices != widget.initialSelectedIndices) {
      _selectedIndices = Set<int>.from(widget.initialSelectedIndices);
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

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
    widget.onSelectionChanged?.call(Set<int>.from(_selectedIndices));
  }

  void _selectAll() {
    // "All" means no specific selection - clear all
    if (_selectedIndices.isNotEmpty) {
      setState(() {
        _selectedIndices.clear();
      });
      widget.onSelectionChanged?.call(Set<int>.from(_selectedIndices));
    }
    // If already empty (All selected), do nothing - cannot uncheck
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Smart-search box (only when the server flag is on).
        if (widget.searchEnabled) ...[
          Text(
            'Type categories:',
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: appTheme.text,
            ),
          ),
          const SizedBox(height: 16),
          _buildSearchBox(appTheme),
          const SizedBox(height: 24),
          // "Or choose:" label with "All" checkbox right-aligned
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'or choose:',
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: appTheme.text,
                ),
              ),
              AllChip(
                isSelected: _selectedIndices.isEmpty,
                onTap: _selectAll,
              ),
            ],
          ),
        ] else ...[
          // Legacy: just the "Choose categories" label + "All" chip.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Choose categories:',
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: appTheme.text,
                ),
              ),
              AllChip(
                isSelected: _selectedIndices.isEmpty,
                onTap: _selectAll,
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        // Chip selection area
        _buildChipSelectionArea(appTheme),
      ],
    );
  }

  /// The real smart-search input. Styled after the "Edit profile" name field
  /// (profile_sheet.dart): filled `bgDark`, rounded outline borders that turn
  /// `primary` when focused.
  Widget _buildSearchBox(AppTheme appTheme) {
    final Color borderColor = appTheme.borderMuted;

    return TextField(
      controller: widget.searchController,
      onChanged: widget.onSearchChanged,
      style: TextStyle(color: appTheme.text),
      textInputAction: TextInputAction.search,
      maxLength: 100,
      buildCounter: (context,
              {required currentLength, required isFocused, maxLength}) =>
          null,
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: appTheme.bgDark,
        hintText: 'E.g. How many X in Y, Christmas',
        hintStyle: AppFont.primaryTextStyle(
          context,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: appTheme.borderMuted,
        ),
        prefixIcon: Icon(Icons.search, size: 20, color: appTheme.borderMuted),
        suffixIcon: (widget.searchController?.text.isNotEmpty ?? false)
            ? IconButton(
                icon: Icon(Icons.close, size: 18, color: appTheme.borderMuted),
                onPressed: () {
                  widget.searchController?.clear();
                  widget.onSearchChanged?.call('');
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: appTheme.primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildChipSelectionArea(AppTheme appTheme) {
    // When a search is active, chips are disabled (greyed out) to enforce the
    // mutually-exclusive search/category model.
    final bool disabled = widget.isSearching;
    return Opacity(
      opacity: disabled ? 0.4 : 1.0,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: List.generate(widget.categories.length, (index) {
          final isSelected = _selectedIndices.contains(index);
          final color = _getCategoryColor(index);

          return CategoryChip(
            label: widget.categories[index].title,
            color: color,
            isSelected: isSelected,
            showCheckmark: false,
            onTap: disabled ? null : () => _toggleSelection(index),
          );
        }),
      ),
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
        onTap: onTap != null
            ? () {
                FeedbackService.instance.secondaryClick();
                onTap!();
              }
            : null,
        borderRadius: BorderRadius.circular(8),
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
            borderRadius: BorderRadius.circular(8),
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

/// A special "All" chip that indicates all items are selected (none filtered).
///
/// Features:
/// - When selected (checked): textMuted color, no interaction feedback
/// - When unselected: text color, clickable to select all
/// - Clicking when selected does nothing
class AllChip extends StatelessWidget {
  final bool isSelected;
  final VoidCallback? onTap;

  static const double _height = 20.0;

  const AllChip({
    super.key,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Color based on selection state per requirements:
    // - checked (isSelected): textMuted (disabled appearance)
    // - unchecked (!isSelected): text (active appearance)
    final contentColor =
        isSelected ? appTheme.textMuted.withAlpha(160) : appTheme.text;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isSelected
            ? null
            : () {
                FeedbackService.instance.secondaryClick();
                onTap?.call();
              }, // Only clickable when unchecked
        borderRadius: BorderRadius.circular(8),
        splashColor:
            isSelected ? Colors.transparent : appTheme.text.withAlpha(30),
        highlightColor:
            isSelected ? Colors.transparent : appTheme.text.withAlpha(15),
        child: Container(
          height: _height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                size: 16,
                color: contentColor,
              ),
              const SizedBox(width: 6),
              Text(
                'All',
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: contentColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
