import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/utils/env.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// A reusable avatar widget that handles both SVG and raster images.
///
/// Automatically detects SVG URLs (by .svg extension) and uses the appropriate
/// renderer. Provides loading and error fallbacks.
/// Optionally displays a rank icon overlay in the top-right corner.
class AvatarWidget extends StatelessWidget {
  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.size = 48.0,
    this.placeholder,
    this.backgroundColor,
    this.padding = EdgeInsets.zero,
    this.boxShadow,
    this.rankPictureUrl,
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

  /// URL to the rank picture SVG. If provided, displays in top-right corner.
  final String? rankPictureUrl;

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
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final Widget placeholderWidget = placeholder ?? _defaultPlaceholder;

    final avatarContainer = Container(
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

    // If no rank picture, return just the avatar
    if (rankPictureUrl == null) {
      return avatarContainer;
    }

    // Otherwise, wrap in a Stack with rank overlay in top-right corner
    final rankIconSize = size * 0.45;

    // Handle relative URLs (safety fallback)
    String effectiveRankUrl = rankPictureUrl!;
    if (effectiveRankUrl.startsWith('/')) {
      try {
        final baseUrlStr = resolveApiBaseUrlOrThrow();
        final uri = Uri.parse(baseUrlStr);
        // Use origin (scheme://host:port) because static files are mounted at root /static
        // not under /api/v1
        effectiveRankUrl = '${uri.origin}$effectiveRankUrl';
      } catch (_) {
        // Fallback: leave as is if base url resolution fails
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatarContainer,
          Positioned(
            top: -2,
            right: -2,
            child: SizedBox(
              width: rankIconSize,
              height: rankIconSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Shadow layer - slightly smaller to account for SVG padding/whitespace
                  Container(
                    width: rankIconSize * 0.75,
                    height: rankIconSize * 0.75,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: appTheme.shadowColor.withOpacity(0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  // Icon layer
                  SvgPicture.network(
                    effectiveRankUrl,
                    width: rankIconSize,
                    height: rankIconSize,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSvgImage(Widget placeholderWidget, {bool applyScaling = true}) {
    final svgWidget = SvgPicture.network(
      imageUrl!,
      fit: BoxFit.cover,
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
