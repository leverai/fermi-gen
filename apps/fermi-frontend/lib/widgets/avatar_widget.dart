import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A reusable avatar widget that handles both SVG and raster images.
///
/// Automatically detects SVG URLs (by .svg extension) and uses the appropriate
/// renderer. Provides loading and error fallbacks.
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.size = 48.0,
    this.placeholder,
    this.backgroundColor,
    this.padding = EdgeInsets.zero,
    this.boxShadow,
  });

  /// URL of the avatar image. Can be an SVG or raster image.
  final String? imageUrl;

  /// Size of the avatar (width and height).
  final double size;

  /// Widget to show when no image URL is provided or while loading.
  final Widget? placeholder;

  /// Background color of the avatar container.
  final Color? backgroundColor;

  /// Internal padding between the border and the image (useful for SVGs).
  final EdgeInsets padding;

  /// Optional shadow effect.
  final List<BoxShadow>? boxShadow;

  bool get _isSvg =>
      imageUrl != null && imageUrl!.toLowerCase().endsWith('.svg');

  /// Detect if URL is for an animals group avatar (needs scaling to avoid clipping)
  bool get _isAnimalsGroup =>
      imageUrl != null && imageUrl!.contains('/animals/');

  Widget get _defaultPlaceholder => Icon(
        Icons.person,
        size: size * 0.6,
      );

  @override
  Widget build(BuildContext context) {
    final Widget placeholderWidget = placeholder ?? _defaultPlaceholder;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        boxShadow: boxShadow,
      ),
      child: Padding(
        padding: padding,
        child: ClipOval(
          child: imageUrl == null
              ? Center(child: placeholderWidget)
              : (_isSvg
                  ? _buildSvgImage(placeholderWidget,
                      applyScaling: _isAnimalsGroup)
                  : _buildRasterImage(placeholderWidget)),
        ),
      ),
    );
  }

  Widget _buildSvgImage(Widget placeholderWidget, {bool applyScaling = true}) {
    final svgWidget = SvgPicture.network(
      imageUrl!,
      fit: BoxFit.contain,
      placeholderBuilder: (context) => Center(child: placeholderWidget),
    );

    if (!applyScaling) {
      return svgWidget;
    }

    // Scale down to fit the square SVG inside the circle (1/sqrt(2) approx 0.707)
    // This is needed for animal avatars to prevent clipping
    return FractionallySizedBox(
      widthFactor: 0.707,
      heightFactor: 0.707,
      child: svgWidget,
    );
  }

  Widget _buildRasterImage(Widget placeholderWidget) {
    return Image.network(
      imageUrl!,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Center(child: placeholderWidget),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(child: placeholderWidget);
      },
    );
  }
}
