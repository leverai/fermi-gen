// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/press_effect_wrapper.dart';
import 'package:fermi_frontend/widgets/bounce_effect_wrapper.dart';

class DailyQuestionCard extends StatefulWidget {
  final DateTime date;
  final String
      status; // 'ACTIVE', 'RESULTS_READY', 'SUBMITTED', 'PENDING', 'NOT_STARTED'
  final bool isToday;
  final bool participated;
  final bool hasUnseenResults;
  final bool showTitle;
  final VoidCallback? onTap; // Nullable to support disabled state
  final DateTime? windowStart; // When DQ becomes ACTIVE (for countdown)
  final DateTime? windowEnd; // When DQ ends (for "Ends in" countdown)

  const DailyQuestionCard({
    super.key,
    required this.date,
    required this.status,
    required this.isToday,
    this.participated = false,
    this.hasUnseenResults = false,
    this.showTitle = false,
    this.onTap,
    this.windowStart,
    this.windowEnd,
  });

  @override
  State<DailyQuestionCard> createState() => _DailyQuestionCardState();
}

class _DailyQuestionCardState extends State<DailyQuestionCard> {
  Timer? _countdownTimer;
  Duration _timeUntilActive = Duration.zero;
  Duration _timeUntilEnd = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startCountdownTimerIfNeeded();
  }

  @override
  void didUpdateWidget(DailyQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle status change, windowStart change, or windowEnd change
    if (widget.status != oldWidget.status ||
        widget.windowStart != oldWidget.windowStart ||
        widget.windowEnd != oldWidget.windowEnd) {
      _startCountdownTimerIfNeeded();
    }
  }

  void _startCountdownTimerIfNeeded() {
    // Start timer if NOT_STARTED with windowStart OR ACTIVE/SUBMITTED with windowEnd
    final needsTimer =
        (widget.status == 'NOT_STARTED' && widget.windowStart != null) ||
            ((widget.status == 'ACTIVE' || widget.status == 'SUBMITTED') &&
                widget.windowEnd != null);

    if (needsTimer) {
      _startCountdownTimer();
    } else {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _updateCountdowns();

    // Update every minute to avoid excessive rebuilds
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateCountdowns();
    });
  }

  void _updateCountdowns() {
    final now = DateTime.now().toUtc();

    if (widget.windowStart != null) {
      final remaining = widget.windowStart!.difference(now);
      if (mounted) {
        setState(() {
          _timeUntilActive = remaining.isNegative ? Duration.zero : remaining;
        });
      }
    }

    if (widget.windowEnd != null) {
      final remaining = widget.windowEnd!.difference(now);
      if (mounted) {
        setState(() {
          _timeUntilEnd = remaining.isNegative ? Duration.zero : remaining;
        });
      }
    }
  }

  String _formatRemainingTime(Duration duration) {
    if (duration.inHours > 0) {
      final hours = duration.inHours;
      final minutes = duration.inMinutes.remainder(60);
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    }
    if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m';
    }
    return 'SOON';
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Formatting
    final dayFormat = DateFormat('d');
    final monthFormat = DateFormat('MMM');
    final weekdayFormat = DateFormat('EEEE');
    final weekdayShortFormat = DateFormat('EEE');

    final isDisabled = widget.onTap == null;

    final decoration = BoxDecoration(
      color: widget.isToday
          ? appTheme.primary
          : (widget.participated
              ? appTheme.primary.withAlpha(100)
              : appTheme.primary),
      borderRadius: BorderRadius.circular(appTheme.borderRadius),
      boxShadow: widget.isToday
          ? [] // No shadow for today's card
          : [],
    );

    final cardContent = Stack(
      children: [
        Container(
          width: double.infinity,
          height: double.infinity,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showTitle) ...[
                    Text(
                      'Daily Guess',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: appTheme.bg,
                      ),
                    ),
                    Text(
                      'Challenge the World!',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: appTheme.bg.withAlpha(200),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // For non-today cards, show weekday at the top
                  if (!widget.isToday)
                    Text(
                      weekdayShortFormat.format(widget.date),
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.participated
                            ? appTheme.bg.withAlpha(100)
                            : appTheme.bg,
                      ),
                    ),
                ],
              ),

              const Spacer(),

              // Bottom part: Date and timer/status (only for today's card)
              if (widget.isToday)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Date
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          weekdayFormat.format(widget.date).toUpperCase(),
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: appTheme.bg,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              dayFormat.format(widget.date),
                              style: AppFont.primaryTextStyle(
                                context,
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: appTheme.bg,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              monthFormat.format(widget.date).toUpperCase(),
                              style: AppFont.secondaryTextStyle(
                                context,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: appTheme.bg,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    // Bottom right: "Ends in" timer for ACTIVE/SUBMITTED, or submission status indicator
                    _buildBottomRightContent(context, appTheme),
                  ],
                ),
            ],
          ),
        ),
        // Status button positioned at top right (only for today's card)
        if (widget.isToday)
          Positioned(
            top: 16,
            right: 16,
            child: _buildStatusButton(context, appTheme),
          ),

        // "Seen" indicator for past cards where user has seen results
        if (!widget.isToday && widget.participated && !widget.hasUnseenResults)
          Positioned(
            bottom: 16,
            right: 16,
            child: Text(
              'Seen ✓',
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: appTheme.bg.withAlpha(100),
              ),
            ),
          ),
      ],
    );

    return Opacity(
      opacity: isDisabled ? 0.65 : 1.0,
      child: widget.isToday
          ? BounceEffectWrapper(
              onTap: widget.onTap,
              decoration: decoration,
              child: cardContent,
            )
          : PressEffectWrapper(
              onTap: widget.onTap,
              enablePushDown: false,
              decoration: decoration,
              child: cardContent,
            ),
    );
  }

  /// Builds the bottom right content for today's card:
  /// - For ACTIVE/SUBMITTED: shows "Tap to play" or "Submitted ✓"
  /// - For NOT_STARTED: shows "Starts in: X"
  /// - For other states: nothing (status button handles it)
  Widget _buildBottomRightContent(BuildContext context, AppTheme appTheme) {
    // For ACTIVE or SUBMITTED, show submission status indicator
    if (widget.status == 'ACTIVE' || widget.status == 'SUBMITTED') {
      final isSubmitted = widget.status == 'SUBMITTED';
      return Text(
        isSubmitted ? 'Submitted ✓' : 'Tap to play',
        style: AppFont.primaryTextStyle(
          context,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: appTheme.bg.withAlpha(200),
        ),
      );
    }

    // For NOT_STARTED, show "SOON"
    if (widget.status == 'NOT_STARTED') {
      return Text(
        'Soon',
        style: AppFont.primaryTextStyle(
          context,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: appTheme.bg.withAlpha(200),
        ),
      );
    }

    // For other states (RESULTS_READY, PENDING), show nothing at bottom right
    // as the status button at top right handles it
    return const SizedBox.shrink();
  }

  Widget _buildStatusButton(BuildContext context, AppTheme appTheme) {
    String buttonText;

    // For ACTIVE/SUBMITTED, show "Ends in: X" timer
    if ((widget.status == 'ACTIVE' || widget.status == 'SUBMITTED') &&
        widget.windowEnd != null &&
        widget.isToday) {
      final remaining = _formatRemainingTime(_timeUntilEnd);
      buttonText = remaining;
    } else {
      switch (widget.status) {
        case 'PENDING':
          buttonText = 'PENDING';
          break;
        case 'NOT_STARTED':
          // Show "Starts in: X" timer if windowStart is available
          if (widget.windowStart != null && widget.isToday) {
            final remaining = _formatRemainingTime(_timeUntilActive);
            buttonText = remaining;
          } else {
            buttonText = 'SOON';
          }
          break;
        case 'RESULTS_READY':
          buttonText = 'RESULTS';
          break;
        default:
          buttonText = widget.status;
      }
    }

    final showTimerIcon = widget.status != 'RESULTS_READY';

    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: buttonText == 'RESULTS'
            ? appTheme.warning
            : appTheme.primaryMuted.withAlpha(200),
        borderRadius: BorderRadius.circular(appTheme.borderRadius / 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTimerIcon) ...[
            SvgPicture.asset(
              'assets/icons/timer.svg',
              width: 14,
              height: 14,
              colorFilter: ColorFilter.mode(appTheme.primary, BlendMode.srcIn),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            buttonText,
            style: AppFont.secondaryTextStyle(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: appTheme.primary,
            ).copyWith(letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }
}
