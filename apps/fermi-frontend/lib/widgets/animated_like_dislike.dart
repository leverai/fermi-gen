import 'package:flutter/material.dart';
import 'package:like_button/like_button.dart';
import 'package:intl/intl.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

enum VoteState { none, upvoted, downvoted }

class AnimatedLikeDislike extends StatefulWidget {
  const AnimatedLikeDislike({
    super.key,
    required this.voteState,
    required this.likeCount,
    required this.onUpvote,
    required this.onDeUpvote,
    required this.onDownvote,
    required this.onDeDownvote,
    this.visible = true,
  });

  final VoteState voteState;
  final int likeCount;
  final Future<void> Function() onUpvote;
  final Future<void> Function() onDeUpvote;
  final Future<void> Function() onDownvote;
  final Future<void> Function() onDeDownvote;
  final bool visible;

  @override
  State<AnimatedLikeDislike> createState() => _AnimatedLikeDislikeState();
}

class _AnimatedLikeDislikeState extends State<AnimatedLikeDislike>
    with SingleTickerProviderStateMixin {
  late VoteState _state;
  late int _likes;
  static final NumberFormat _compactNumberFormat = NumberFormat.compact();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _state = widget.voteState;
    _likes = widget.likeCount;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Slide animation: fall down when appearing, shoot up when disappearing
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5), // Start above
      end: Offset.zero, // End at normal position
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    // Fade animation
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    ));

    if (widget.visible) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedLikeDislike oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voteState != widget.voteState) _state = widget.voteState;
    if (oldWidget.likeCount != widget.likeCount) _likes = widget.likeCount;

    if (oldWidget.visible != widget.visible) {
      if (widget.visible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Target colors based on state
    final Color targetThumbUpColor =
        _state == VoteState.upvoted ? appTheme.success : appTheme.border;
    final Color targetThumbDownColor =
        _state == VoteState.downvoted ? appTheme.danger : appTheme.border;
    final Color targetTextColor = _state == VoteState.upvoted
        ? appTheme.success
        : _state == VoteState.downvoted
            ? appTheme.danger
            : appTheme.border;
    final Color separatorColor = appTheme.borderMuted;

    final bool upLiked = _state == VoteState.upvoted;
    final bool downLiked = _state == VoteState.downvoted;

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: _AnimatedColors(
          thumbUpColor: targetThumbUpColor,
          thumbDownColor: targetThumbDownColor,
          textColor: targetTextColor,
          separatorColor: separatorColor,
          child: Builder(builder: (context) {
            final colors = _AnimatedColors.of(context);
            return Container(
              height: 24, // 20% larger than 38
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LikeButton(
                    size: 24, // Controls both icon size and animation
                    isLiked: upLiked,
                    animationDuration: const Duration(milliseconds: 800),
                    bubblesSize: 60, // Larger bubbles for more visibility
                    circleSize: 30, // Larger circle animation
                    likeBuilder: (bool isLiked) => Container(
                      decoration: isLiked
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  // ignore: deprecated_member_use
                                  color: colors.thumbUpColor.withOpacity(0.2),
                                  blurRadius: 14,
                                  spreadRadius: 0,
                                ),
                              ],
                            )
                          : null,
                      child: Icon(
                        isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                        color: colors.thumbUpColor,
                        // Size controlled by LikeButton's size parameter
                      ),
                    ),
                    likeCount: _likes,
                    likeCountAnimationType: LikeCountAnimationType.all,
                    likeCountAnimationDuration:
                        const Duration(milliseconds: 400),
                    countBuilder: (count, isLiked, text) => Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text(
                        _compactNumberFormat.format(count ?? 0),
                        style: AppFont.secondaryTextStyle(
                          context,
                          fontSize: 17, // 20% larger than 14
                          fontWeight: FontWeight.w300,
                          color: colors.textColor,
                          decoration: TextDecoration.none,
                        ).copyWith(
                          letterSpacing: 0.0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                    onTap: (bool isLiked) async {
                      if (_state == VoteState.upvoted) {
                        await widget.onDeUpvote();
                        setState(() {
                          _state = VoteState.none;
                          _likes = (_likes - 1).clamp(0, 1 << 31);
                        });
                        return false;
                      }
                      if (_state == VoteState.downvoted) {
                        await widget.onDeDownvote();
                      }
                      await widget.onUpvote();
                      setState(() {
                        _state = VoteState.upvoted;
                        _likes += 1;
                      });
                      return true;
                    },
                    bubblesColor: BubblesColor(
                      dotPrimaryColor: appTheme.primary,
                      // ignore: deprecated_member_use
                      dotSecondaryColor: appTheme.primary.withOpacity(0.8),
                      // ignore: deprecated_member_use
                      dotThirdColor: appTheme.primary.withOpacity(0.6),
                      // ignore: deprecated_member_use
                      dotLastColor: appTheme.primary.withOpacity(0.4),
                    ),
                    circleColor: CircleColor(
                      // ignore: deprecated_member_use
                      start: appTheme.primary.withOpacity(0.3),
                      // ignore: deprecated_member_use
                      end: appTheme.primary.withOpacity(0.8),
                    ),
                  ),
                  const SizedBox(width: 12), // 20% larger
                  Container(
                    width: 1,
                    height: 24, // 20% larger than 20
                    color: colors.separatorColor,
                  ),
                  const SizedBox(width: 12), // 20% larger
                  LikeButton(
                    size: 24, // Controls both icon size and animation
                    isLiked: downLiked,
                    animationDuration: const Duration(milliseconds: 800),
                    bubblesSize: 60, // Larger bubbles for more visibility
                    circleSize: 30, // Larger circle animation
                    likeBuilder: (bool isLiked) => Container(
                      decoration: isLiked
                          ? BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  // ignore: deprecated_member_use
                                  color: colors.thumbDownColor.withOpacity(0.2),
                                  blurRadius: 14,
                                  spreadRadius: 0,
                                ),
                              ],
                            )
                          : null,
                      child: Transform.rotate(
                        angle: 3.14159, // flip thumb up to mimic thumb down
                        child: Icon(
                          isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                          color: colors.thumbDownColor,
                          // Size controlled by LikeButton's size parameter
                        ),
                      ),
                    ),
                    likeCount: null,
                    onTap: (bool isLiked) async {
                      if (_state == VoteState.downvoted) {
                        await widget.onDeDownvote();
                        setState(() => _state = VoteState.none);
                        return false;
                      }
                      if (_state == VoteState.upvoted) {
                        await widget.onDeUpvote();
                        setState(() => _likes = (_likes - 1).clamp(0, 1 << 31));
                      }
                      await widget.onDownvote();
                      setState(() => _state = VoteState.downvoted);
                      return true;
                    },
                    bubblesColor: BubblesColor(
                      dotPrimaryColor: appTheme.danger,
                      // ignore: deprecated_member_use
                      dotSecondaryColor: appTheme.danger.withOpacity(0.8),
                      // ignore: deprecated_member_use
                      dotThirdColor: appTheme.danger.withOpacity(0.6),
                      // ignore: deprecated_member_use
                      dotLastColor: appTheme.danger.withOpacity(0.4),
                    ),
                    circleColor: CircleColor(
                      // ignore: deprecated_member_use
                      start: appTheme.danger.withOpacity(0.3),
                      // ignore: deprecated_member_use
                      end: appTheme.danger.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

/// Widget that animates color transitions for the like/dislike buttons
class _AnimatedColors extends StatelessWidget {
  final Color thumbUpColor;
  final Color thumbDownColor;
  final Color textColor;
  final Color separatorColor;
  final Widget child;

  const _AnimatedColors({
    required this.thumbUpColor,
    required this.thumbDownColor,
    required this.textColor,
    required this.separatorColor,
    required this.child,
  });

  static _AnimatedColorsData of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_AnimatedColorsData>()!;
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: thumbUpColor),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      builder: (context, animatedThumbUpColor, _) {
        return TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: thumbDownColor),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          builder: (context, animatedThumbDownColor, _) {
            return TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: textColor),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              builder: (context, animatedTextColor, _) {
                return _AnimatedColorsData(
                  thumbUpColor: animatedThumbUpColor ?? thumbUpColor,
                  thumbDownColor: animatedThumbDownColor ?? thumbDownColor,
                  textColor: animatedTextColor ?? textColor,
                  separatorColor: separatorColor,
                  child: child,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _AnimatedColorsData extends InheritedWidget {
  final Color thumbUpColor;
  final Color thumbDownColor;
  final Color textColor;
  final Color separatorColor;

  const _AnimatedColorsData({
    required this.thumbUpColor,
    required this.thumbDownColor,
    required this.textColor,
    required this.separatorColor,
    required super.child,
  });

  @override
  bool updateShouldNotify(_AnimatedColorsData oldWidget) {
    return oldWidget.thumbUpColor != thumbUpColor ||
        oldWidget.thumbDownColor != thumbDownColor ||
        oldWidget.textColor != textColor ||
        oldWidget.separatorColor != separatorColor;
  }
}
