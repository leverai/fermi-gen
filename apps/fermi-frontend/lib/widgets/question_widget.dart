import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/tag_widget.dart';
import 'package:fermi_frontend/widgets/animated_like_dislike.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/live_typing_text.dart';
import 'package:fermi_frontend/models/ltt_sound_profile.dart';
import 'package:fermi_frontend/services/local_settings_service.dart';

/// A widget that displays question text with optional tags.
///
/// This is a simple, non-scrollable text display. The widget adapts its height
/// to fit the content.
class QuestionWidget extends StatelessWidget {
  final String text;
  final List<String> tags;
  final bool showBorder;
  final double bottomSpacing;

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
            color: appTheme.textMuted.withAlpha(40),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildContent(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final Color textColor = appTheme.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<LttSoundProfile?>(
          valueListenable: LocalSettingsService.instance.selectedSoundProfile,
          builder: (context, soundProfile, _) {
            return LiveTypingText(
              text: text,
              textAlign: TextAlign.left,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
                decoration: TextDecoration.none,
                height: 1.5,
              ).copyWith(letterSpacing: 0.4),
              soundProfile: soundProfile,
            );
          },
        ),
        if (tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _buildTagsWithDividers(context, tags),
          ),
        ],
        SizedBox(height: bottomSpacing),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Simple content without border
    if (!showBorder) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildContent(context),
          if (showLikeWidget) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedLikeDislike(
                    key: likeWidgetKey,
                    voteState: initialVoteState ?? VoteState.none,
                    likeCount: initialLikes ?? 0,
                    onUpvote: onUpvote ?? () async {},
                    onDeUpvote: onDeUpvote ?? () async {},
                    onDownvote: onDownvote ?? () async {},
                    onDeDownvote: onDeDownvote ?? () async {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    // Content with border decoration
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
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
      ),
      child: Container(
        margin: const EdgeInsets.all(1), // 1px border effect
        decoration: BoxDecoration(
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
        ),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildContent(context),
              if (showLikeWidget) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedLikeDislike(
                        key: likeWidgetKey,
                        voteState: initialVoteState ?? VoteState.none,
                        likeCount: initialLikes ?? 0,
                        onUpvote: onUpvote ?? () async {},
                        onDeUpvote: onDeUpvote ?? () async {},
                        onDownvote: onDownvote ?? () async {},
                        onDeDownvote: onDeDownvote ?? () async {},
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
