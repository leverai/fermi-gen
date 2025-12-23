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
    this.borderColor,
    this.borderWidth = 2.0,
    this.backgroundColor,
    this.padding = EdgeInsets.zero,
  });

  /// URL of the avatar image. Can be an SVG or raster image.
  final String? imageUrl;

  /// Size of the avatar (width and height).
  final double size;

  /// Widget to show when no image URL is provided or while loading.
  final Widget? placeholder;

  /// Optional border color around the avatar.
  final Color? borderColor;

  /// Border width (default: 2.0).
  final double borderWidth;

  /// Background color of the avatar container.
  final Color? backgroundColor;

  /// Internal padding between the border and the image (useful for SVGs).
  final EdgeInsets padding;

  bool get _isSvg =>
      imageUrl != null && imageUrl!.toLowerCase().endsWith('.svg');

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
      ),
      child: Padding(
        padding: padding,
        child: ClipOval(
          child: imageUrl == null
              ? Center(child: placeholderWidget)
              : (_isSvg
                  ? _buildSvgImage(placeholderWidget)
                  : _buildRasterImage(placeholderWidget)),
        ),
      ),
    );
  }

  Widget _buildSvgImage(Widget placeholderWidget) {
    // Scale down to fit the square SVG inside the circle (1/sqrt(2) approx 0.707)
    return FractionallySizedBox(
      widthFactor: 0.707,
      heightFactor: 0.707,
      child: SvgPicture.network(
        imageUrl!,
        fit: BoxFit.contain,
        placeholderBuilder: (context) => Center(child: placeholderWidget),
      ),
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
