import 'dart:ui';
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

class _AnimatedLikeDislikeState extends State<AnimatedLikeDislike> {
  late VoteState _state;
  late int _likes;
  static final NumberFormat _compactNumberFormat = NumberFormat.compact();

  @override
  void initState() {
    super.initState();
    _state = widget.voteState;
    _likes = widget.likeCount;
  }

  @override
  void didUpdateWidget(covariant AnimatedLikeDislike oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.voteState != widget.voteState) _state = widget.voteState;
    if (oldWidget.likeCount != widget.likeCount) _likes = widget.likeCount;
  }

  Future<bool?> _onUpvoteButtonTapped(bool isLiked) async {
    if (isLiked) {
      // Was liked, now unliking
      setState(() {
        _state = VoteState.none;
        _likes = (_likes - 1).clamp(0, 1 << 31);
      });
      await widget.onDeUpvote();
      return false;
    } else {
      // Was not liked, now liking
      final wasDownvoted = _state == VoteState.downvoted;
      setState(() {
        _state = VoteState.upvoted;
        _likes += 1;
      });

      if (wasDownvoted) {
        await widget.onDeDownvote();
      }
      await widget.onUpvote();
      return true;
    }
  }

  Future<bool?> _onDownvoteButtonTapped(bool isLiked) async {
    if (isLiked) {
      // Was downvoted, now removing downvote
      setState(() {
        _state = VoteState.none;
      });
      await widget.onDeDownvote();
      return false;
    } else {
      // Was not downvoted, now downvoting
      final wasUpvoted = _state == VoteState.upvoted;
      setState(() {
        _state = VoteState.downvoted;
        if (wasUpvoted) {
          _likes = (_likes - 1).clamp(0, 1 << 31);
        }
      });

      if (wasUpvoted) {
        await widget.onDeUpvote();
      }
      await widget.onDownvote();
      return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible) return const SizedBox.shrink();

    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final isUpvoted = _state == VoteState.upvoted;
    final isDownvoted = _state == VoteState.downvoted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LikeButton(
          size: 24,
          isLiked: isUpvoted,
          likeCount: _likes,
          countBuilder: (int? count, bool isLiked, String text) {
            return Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Text(
                count == null ? "0" : _compactNumberFormat.format(count),
                style: AppFont.secondaryTextStyle(
                  context,
                  fontSize: 17,
                  fontWeight: FontWeight.w300,
                  color: appTheme.border,
                  decoration: TextDecoration.none,
                ).copyWith(
                  letterSpacing: 0.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            );
          },
          likeBuilder: (bool isLiked) {
            return Icon(
              isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
              color: isLiked ? appTheme.primary : appTheme.border,
              size: 24,
            );
          },
          bubblesColor: BubblesColor(
            dotPrimaryColor: appTheme.primary,
            dotSecondaryColor: appTheme.primaryMuted,
          ),
          circleColor: CircleColor(
            start: appTheme.primary.withOpacity(0.3),
            end: appTheme.primary,
          ),
          onTap: _onUpvoteButtonTapped,
        ),
        const SizedBox(width: 12),
        Container(width: 1, height: 24, color: appTheme.borderMuted),
        const SizedBox(width: 12),
        LikeButton(
          size: 24,
          isLiked: isDownvoted,
          likeCount: null,
          likeBuilder: (bool isLiked) {
            return Icon(
              isLiked ? Icons.thumb_down : Icons.thumb_down_outlined,
              color: isLiked ? appTheme.danger : appTheme.border,
              size: 24,
            );
          },
          bubblesColor: BubblesColor(
            dotPrimaryColor: appTheme.danger,
            dotSecondaryColor: appTheme.danger.withOpacity(0.5),
          ),
          circleColor: CircleColor(
            start: appTheme.danger.withOpacity(0.3),
            end: appTheme.danger,
          ),
          onTap: _onDownvoteButtonTapped,
        ),
      ],
    );
  }
}
