import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// A simplified Material 3 uncontained carousel for category selection.
///
/// Categories are displayed as cards with automatically-generated colors
/// using the formula: hsl(startHue + i*53, startSat, startLight).
///
/// Card dimensions and spacing follow the design system:
/// - Fixed card size: 120px × 144px (multiples of 24px)
/// - 24px spacing between cards
/// - All internal padding uses multiples of 12px
///
/// Supports deselection: tapping a selected card will deselect it (pass null to callbacks).
class CategoryCarouselM3 extends StatefulWidget {
  final List<CategoryItemM3> categories;
  final int? initialIndex;
  final ValueChanged<int?>? onCategorySelected;
  final ValueChanged<int?>? onCenteredIndexChanged;
  final HSLColor startColor;

  const CategoryCarouselM3({
    super.key,
    required this.categories,
    this.initialIndex,
    this.onCategorySelected,
    this.onCenteredIndexChanged,
    this.startColor = const HSLColor.fromAHSL(1.0, 39, 0.55, 0.61),
  });

  @override
  State<CategoryCarouselM3> createState() => _CategoryCarouselM3State();
}

class _CategoryCarouselM3State extends State<CategoryCarouselM3> {
  int? _selectedIndex;

  // Fixed card dimensions: multiples of 24px
  static const double _cardWidth = 24.0 * 5; // 120px
  static const double _cardHeight = 24.0 * 6; // 144px
  static const double _spacing = 16.0; // 24px spacing between cards

  final CarouselController _controller = CarouselController();

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex != null && widget.categories.isNotEmpty
        ? widget.initialIndex!.clamp(0, widget.categories.length - 1)
        : null;

    // Center the initial item if one is selected
    if (_selectedIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToIndex(_selectedIndex!, animate: false);
        }
      });
    }
  }

  /// Compute the color for a category at the given index.
  Color _getCategoryColor(int index) {
    final hue = (widget.startColor.hue + (index + 1) * 53) % 360;
    return HSLColor.fromAHSL(
      1.0,
      hue,
      widget.startColor.saturation,
      widget.startColor.lightness,
    ).toColor();
  }

  void _scrollToIndex(int index, {bool animate = true}) {
    // We need the viewport width to center the item.
    // Since we don't have direct access to the viewport width here without LayoutBuilder,
    // we'll rely on the LayoutBuilder in the build method to store it or pass it.
    // For now, let's just scroll to the item's start position which brings it into view.
    // To center, we need: offset = (index * itemExtent) - (viewportWidth / 2) + (itemExtent / 2)

    // However, without viewport width, we can't center perfectly.
    // Let's use a simplified approach: scroll to the item.
    // But wait, we can get context.size?.width?

    const double itemExtent = _cardWidth + _spacing;
    final double viewportWidth = context.size?.width ?? 0;

    if (viewportWidth == 0) return;

    final double targetOffset =
        (index * itemExtent) - (viewportWidth / 2) + (itemExtent / 2);
    // Clamp is handled by the scrollable usually, but good to be safe?
    // We don't know the max scroll extent easily.

    // Actually, CarouselView might not support offset scrolling if it's not a ScrollView.
    // But assuming it is:

    if (animate) {
      _controller.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _controller.jumpTo(targetOffset);
    }
  }

  void _onCardTap(int index) {
    setState(() {
      // Toggle selection: if already selected, deselect; otherwise select
      if (_selectedIndex == index) {
        _selectedIndex = null;
      } else {
        _selectedIndex = index;
      }
    });

    widget.onCategorySelected?.call(_selectedIndex);
    widget.onCenteredIndexChanged?.call(_selectedIndex);

    // Center the tapped item
    _scrollToIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    // Vertical padding to prevent glow clipping (blurRadius: 8)
    // Using 24px (multiple of 12) for consistency with design system
    const double glowPadding = 16.0;

    return SizedBox(
      height: _cardHeight + (2 * glowPadding),
      child: LayoutBuilder(builder: (context, constraints) {
        return CarouselView(
          controller: _controller,
          itemExtent: _cardWidth + _spacing,
          shrinkExtent: _cardWidth + _spacing, // Prevent cards from shrinking
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: const HorizontalInsetShape(
            horizontalInset: 8.0,
            baseShape: RoundedRectangleBorder(),
          ),
          padding: const EdgeInsets.only(
            top: glowPadding,
            bottom: glowPadding,
            // No horizontal padding - spacing is handled by child Padding widgets
          ),
          onTap: (index) => _onCardTap(index),
          children: List.generate(
            widget.categories.length,
            (index) {
              final category = widget.categories[index];
              final categoryColor = _getCategoryColor(index);
              final isSelected = index == _selectedIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal:
                        8), // 12px on each side = 24px total between cards
                child: CategoryCardM3(
                  title: category.title,
                  svgPath: category.svgPath,
                  categoryColor: categoryColor,
                  isSelected: isSelected,
                  width: _cardWidth,
                  height: _cardHeight,
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

/// A simple data model for category items in the M3 carousel.
class CategoryItemM3 {
  final String id;
  final String title;
  final String svgPath;

  const CategoryItemM3({
    required this.id,
    required this.title,
    required this.svgPath,
  });
}

/// A single category card for the M3 carousel.
class CategoryCardM3 extends StatelessWidget {
  final String title;
  final String svgPath;
  final Color categoryColor;
  final bool isSelected;
  final double width;
  final double height;

  const CategoryCardM3({
    super.key,
    required this.title,
    required this.svgPath,
    required this.categoryColor,
    required this.isSelected,
    required this.width,
    required this.height,
  });

  /// Insert a zero-width space in the middle of text to encourage wrapping to two lines
  String _forceTwoLineText(String text) {
    if (text.length <= 1) return text;
    final midpoint = text.length ~/ 2;
    // Find a good break point (space or near midpoint)
    int breakPoint = midpoint;
    // Prefer breaking at a space if near the midpoint
    for (int i = 0; i < 5 && midpoint + i < text.length; i++) {
      if (text[midpoint + i] == ' ') {
        breakPoint = midpoint + i;
        break;
      }
      if (midpoint - i >= 0 && text[midpoint - i] == ' ') {
        breakPoint = midpoint - i;
        break;
      }
    }
    // Insert zero-width space (invisible but allows line break)
    return '${text.substring(0, breakPoint)}\u200B${text.substring(breakPoint)}';
  }

  Widget _buildIcon(
      BuildContext context, String svgPath, Color color, double height) {
    // If the path starts with 'icon:', use a Material icon instead
    if (svgPath.startsWith('icon:')) {
      final iconName = svgPath.substring(5);
      IconData iconData;

      switch (iconName) {
        case 'public':
          iconData = Icons.public;
          break;
        case 'rocket':
          iconData = Icons.rocket_launch;
          break;
        case 'nature':
          iconData = Icons.nature;
          break;
        case 'movie':
          iconData = Icons.movie;
          break;
        case 'lightbulb':
          iconData = Icons.lightbulb;
          break;
        case 'people':
          iconData = Icons.people;
          break;
        default:
          iconData = Icons.category;
      }

      // Fill the height of the container while maintaining aspect ratio
      return SizedBox(
        height: height,
        child: FittedBox(
          fit: BoxFit.fitHeight,
          child: Icon(
            iconData,
            color: color,
          ),
        ),
      );
    }

    // Otherwise try to load as SVG from network
    // Fill the height of the container while maintaining aspect ratio
    return SizedBox(
      height: height,
      child: SvgPicture.network(
        svgPath,
        height: height,
        colorFilter: ColorFilter.mode(
          color,
          BlendMode.srcIn,
        ),
        fit: BoxFit.fitHeight,
        placeholderBuilder: (context) => SizedBox(
          height: height,
          child: FittedBox(
            fit: BoxFit.fitHeight,
            child: Icon(
              Icons.category,
              color: color,
            ),
          ),
        ),
        // Handle errors gracefully
        errorBuilder: (context, error, stackTrace) => SizedBox(
          height: height,
          child: FittedBox(
            fit: BoxFit.fitHeight,
            child: Icon(
              Icons.category,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Background color: category color with lightness set to 80%
    final bgColor = HSLColor.fromColor(categoryColor)
        .withLightness(0.80)
        .toColor()
        // ignore: deprecated_member_use
        .withOpacity(0.2);

    // Card padding: 12px all around
    const double cardPadding = 12.0;
    // Text area: reserve fixed space for 2 lines
    // fontSize: 14, height: 1.2 → line height = 14 * 1.2 = 16.8px
    // 2 lines = 16.8 * 2 = 33.6px, round up to 44px to account for font rendering, spacing, and overflow
    const double textAreaHeight = 44.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(
          color: isSelected ? categoryColor : Colors.transparent,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  // ignore: deprecated_member_use
                  color: categoryColor.withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(cardPadding),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Use actual Column constraints instead of calculated values
            final availableHeight = constraints.maxHeight;
            // Calculate icon height based on actual available space
            final double actualIconHeight = availableHeight - textAreaHeight;

            return Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon fills its allocated height
                SizedBox(
                  height: actualIconHeight,
                  width: double.infinity,
                  child: _buildIcon(
                      context, svgPath, categoryColor, actualIconHeight),
                ),
                // Title text at bottom - fixed height for consistency
                SizedBox(
                  height: textAreaHeight,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: SizedBox(
                      // Constrain width to force wrapping to two lines
                      // Card width: 120px, padding: 12px each side = 96px available
                      // Constrain to ~80px to force wrapping
                      width: width - (2 * cardPadding) - 16,
                      child: Text(
                        _forceTwoLineText(title),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? appTheme.text : appTheme.border,
                          height: 1.2,
                        ).copyWith(letterSpacing: 0.8),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class HorizontalInsetShape extends OutlinedBorder {
  final double horizontalInset;
  final OutlinedBorder baseShape;

  const HorizontalInsetShape({
    this.horizontalInset = 0,
    this.baseShape = const RoundedRectangleBorder(),
  });

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return baseShape.getInnerPath(
      EdgeInsets.symmetric(horizontal: horizontalInset).deflateRect(rect),
      textDirection: textDirection,
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return baseShape.getOuterPath(
      Rect.fromLTRB(
        rect.left + horizontalInset,
        rect.top,
        rect.right - horizontalInset,
        rect.bottom,
      ),
      textDirection: textDirection,
    );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    baseShape.paint(
      canvas,
      Rect.fromLTRB(
        rect.left + horizontalInset,
        rect.top,
        rect.right - horizontalInset,
        rect.bottom,
      ),
      textDirection: textDirection,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return HorizontalInsetShape(
      horizontalInset: horizontalInset * t,
      baseShape: baseShape.scale(t) as OutlinedBorder,
    );
  }

  @override
  HorizontalInsetShape copyWith({BorderSide? side, double? horizontalInset}) {
    return HorizontalInsetShape(
      horizontalInset: horizontalInset ?? this.horizontalInset,
      baseShape: baseShape.copyWith(side: side),
    );
  }
}
