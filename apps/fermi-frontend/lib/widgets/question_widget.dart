import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/tag_widget.dart';
import 'package:fermi_frontend/widgets/animated_like_dislike.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// A widget that displays question text with optional tags.
///
/// When the content exceeds the available height, the widget becomes scrollable
/// and displays a fade effect at the bottom to indicate that more content is available.
/// The fade effect uses a [ShaderMask] with a gradient that extends slightly beyond
/// the bottom edge to ensure complete coverage of all pixels.
///
/// The widget supports optional like/dislike voting functionality that can be
/// displayed below the question content.
class QuestionWidget extends StatefulWidget {
  final String text;
  final List<String> tags;
  final double height; // Fixed pixel height
  final bool showBorder; // Whether to show the border decoration
  final double bottomSpacing; // Spacing after tags (default: 12px)

  // Like widget parameters (optional, only shown after reveal)
  final bool showLikeWidget;
  final int? initialLikes;
  final VoteState? initialVoteState;
  final Future<void> Function()? onUpvote;
  final Future<void> Function()? onDeUpvote;
  final Future<void> Function()? onDownvote;
  final Future<void> Function()? onDeDownvote;
  final Key? likeWidgetKey;

  // Reveal color (optional, animates text color to score scale on reveal)
  final Color? revealedColor;

  const QuestionWidget({
    super.key,
    required this.text,
    required this.height,
    this.tags = const [],
    this.showBorder = true,
    this.bottomSpacing = 12.0,
    this.showLikeWidget = false,
    this.initialLikes,
    this.initialVoteState,
    this.onUpvote,
    this.onDeUpvote,
    this.onDownvote,
    this.onDeDownvote,
    this.likeWidgetKey,
    this.revealedColor,
  });

  @override
  State<QuestionWidget> createState() => _QuestionWidgetState();
}

class _QuestionWidgetState extends State<QuestionWidget> {
  final ScrollController _scrollController = ScrollController();
  bool _isScrollable = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkIfScrollable());
    _scrollController.addListener(_checkIfScrollable);
  }

  @override
  void didUpdateWidget(QuestionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-check scrollability when text or tags change, as content size may have changed
    if (oldWidget.text != widget.text || oldWidget.tags != widget.tags) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkIfScrollable());
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkIfScrollable);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkIfScrollable() {
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      if (!_isScrollable) {
        setState(() {
          _isScrollable = true;
        });
      }
    } else {
      if (_isScrollable) {
        setState(() {
          _isScrollable = false;
        });
      }
    }
  }

  List<Widget> _buildTagsWithDividers(BuildContext context, List<String> tags) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final List<Widget> widgets = [];

    for (int i = 0; i < tags.length; i++) {
      widgets.add(TagWidget(text: tags[i]));

      // Add divider after each tag except the last one
      if (i < tags.length - 1) {
        widgets.add(
          Container(
            width: 1,
            height: 12,
            color: appTheme.borderMuted,
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildScrollableContent() {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Determine text color: use theme text color (static)
    final Color textColor = appTheme.text;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
            decoration: TextDecoration.none,
            height: 1.5,
          ).copyWith(letterSpacing: 0.4),
          child: Text(
            widget.text,
            textAlign: TextAlign.left,
            softWrap: true,
            overflow: TextOverflow.visible,
          ),
        ),
        if (widget.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _buildTagsWithDividers(context, widget.tags),
          ),
        ],
        SizedBox(height: widget.bottomSpacing),
      ],
    );

    final scrollView = SingleChildScrollView(
      controller: _scrollController,
      physics: _isScrollable
          ? const BouncingScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      child: SizedBox(
        width: double.infinity,
        child: content,
      ),
    );

    // Apply fade effect using ShaderMask to indicate scrollability.
    // The gradient fades from opaque at top to transparent at bottom, starting at 74% height.
    // We extend the bounds by 1px to ensure complete coverage of the bottom edge pixel,
    // which fixes a common rendering issue where the last pixel row remains unfaded.
    final fadedScrollable = ShaderMask(
      shaderCallback: (Rect bounds) {
        if (_isScrollable) {
          // Extend bounds by 1px at bottom to ensure gradient covers the edge completely.
          // This addresses a known Flutter rendering issue where edge pixels can remain unfaded.
          final extendedBounds = Rect.fromLTRB(
            bounds.left,
            bounds.top,
            bounds.right,
            bounds.bottom + 1.0,
          );
          // Use theme text color for gradient
          final Color gradientColor = appTheme.text;
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              gradientColor,
              gradientColor,
              Colors.transparent,
            ],
            stops: const [0.0, 0.74, 1.0],
          ).createShader(extendedBounds);
        } else {
          // No fade effect when content fits within the available space.
          // Use theme text color for gradient
          final Color gradientColor = appTheme.text;
          return LinearGradient(
            colors: [gradientColor, gradientColor],
          ).createShader(bounds);
        }
      },
      blendMode: BlendMode.dstIn,
      child: scrollView,
    );

    if (widget.bottomSpacing == 0) {
      return Align(
        alignment: Alignment.bottomLeft,
        child: fadedScrollable,
      );
    }
    return fadedScrollable;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: widget.showBorder
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomCenter,
                colors: [
                  appTheme.border,
                  appTheme.borderMuted,
                  appTheme.bgLight,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: Container(
        margin: widget.showBorder
            ? const EdgeInsets.all(1)
            : EdgeInsets.zero, // 1px border effect
        decoration: widget.showBorder
            ? BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomCenter,
                  colors: [
                    // ignore: deprecated_member_use
                    appTheme.bgLight.withOpacity(1),
                    appTheme.bg,
                  ],
                  stops: const [0.0, 0.7],
                ),
                borderRadius: BorderRadius.circular(11),
              )
            : null,
        child: Column(
          children: [
            Expanded(
              child: ClipRect(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 8,
                    bottom: widget.bottomSpacing == 0 ? 0 : 8,
                  ),
                  child: _buildScrollableContent(),
                ),
              ),
            ),
            if (widget.showLikeWidget) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AnimatedLikeDislike(
                      key: widget.likeWidgetKey,
                      voteState: widget.initialVoteState ?? VoteState.none,
                      likeCount: widget.initialLikes ?? 0,
                      onUpvote: widget.onUpvote ?? () async {},
                      onDeUpvote: widget.onDeUpvote ?? () async {},
                      onDownvote: widget.onDownvote ?? () async {},
                      onDeDownvote: widget.onDeDownvote ?? () async {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}
