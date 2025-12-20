import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

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
  });

  @override
  State<DailyQuestionCard> createState() => _DailyQuestionCardState();
}

class _DailyQuestionCardState extends State<DailyQuestionCard> {
  Timer? _countdownTimer;
  Duration _timeUntilActive = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.status == 'NOT_STARTED' && widget.windowStart != null) {
      _startCountdownTimer();
    }
  }

  @override
  void didUpdateWidget(DailyQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle status change or windowStart change
    if (widget.status != oldWidget.status ||
        widget.windowStart != oldWidget.windowStart) {
      if (widget.status == 'NOT_STARTED' && widget.windowStart != null) {
        _startCountdownTimer();
      } else {
        _countdownTimer?.cancel();
        _countdownTimer = null;
      }
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _updateTimeUntilActive();

    // Update every minute to avoid excessive rebuilds
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateTimeUntilActive();
    });
  }

  void _updateTimeUntilActive() {
    if (widget.windowStart == null) return;

    final now = DateTime.now().toUtc();
    final remaining = widget.windowStart!.difference(now);

    if (mounted) {
      setState(() {
        _timeUntilActive = remaining.isNegative ? Duration.zero : remaining;
      });
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
    return 'soon';
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Formatting
    final dayFormat = DateFormat('d');
    final monthFormat = DateFormat('MMM');
    final weekdayFormat = DateFormat('EEEE');

    final isDisabled = widget.onTap == null;

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(appTheme.borderRadius),
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: widget.isToday
                    ? appTheme.primary
                    : (widget.participated
                        ? appTheme.primary
                        : appTheme.bgLight),
                borderRadius: BorderRadius.circular(appTheme.borderRadius),
                border: Border.all(
                  color: appTheme.primary,
                  width: appTheme.borderWidth,
                ),
                boxShadow: widget.isToday
                    ? [
                        BoxShadow(
                          color: appTheme.shadowColor,
                          offset: appTheme.shadowOffset,
                          blurRadius: 0,
                        ),
                      ]
                    : [],
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: widget.isToday
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Content
                  Column(
                    crossAxisAlignment: widget.isToday
                        ? CrossAxisAlignment.start
                        : CrossAxisAlignment.center,
                    children: [
                      if (widget.showTitle) ...[
                        Text(
                          'Daily Guess',
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: widget.isToday ? appTheme.bg : appTheme.text,
                          ),
                        ),
                        Text(
                          'Challenge the World!',
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: widget.isToday
                                ? appTheme.bgDark
                                : appTheme.borderMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      // For non-today cards, show weekday at the top
                      if (!widget.isToday)
                        Text(
                          weekdayFormat.format(widget.date),
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: widget.participated
                                ? appTheme.bg
                                : appTheme.text,
                          ),
                        ),
                    ],
                  ),

                  const Spacer(),

                  // Bottom part: Date and Status button (only for today's card)
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
                              style: AppFont.secondaryTextStyle(
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
                        _buildStatusButton(context, appTheme),
                      ],
                    ),
                ],
              ),
            ),

            // Unseen results indicator (green dot)
            if (widget.hasUnseenResults)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: appTheme.success,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color:
                          widget.isToday ? appTheme.primary : appTheme.bgLight,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(BuildContext context, AppTheme appTheme,
      {bool small = false}) {
    String buttonText;
    Color bgColor;
    Color textColor;

    switch (widget.status) {
      case 'ACTIVE':
        buttonText = 'PLAY';
        bgColor = widget.isToday ? appTheme.bg : appTheme.primary;
        textColor = widget.isToday ? appTheme.primary : appTheme.bg;
        break;
      case 'SUBMITTED':
        buttonText = 'Submitted ✓';
        bgColor = widget.isToday
            ? appTheme.bg.withOpacity(0.8)
            : appTheme.success.withOpacity(0.2);
        textColor = widget.isToday ? appTheme.success : appTheme.success;
        break;
      case 'PENDING':
        buttonText = 'Pending...';
        bgColor = widget.isToday
            ? appTheme.bg.withOpacity(0.6)
            : appTheme.borderMuted.withOpacity(0.3);
        textColor = widget.isToday ? appTheme.textMuted : appTheme.textMuted;
        break;
      case 'NOT_STARTED':
        // Show countdown timer if windowStart is available
        if (widget.windowStart != null) {
          final remaining = _formatRemainingTime(_timeUntilActive);
          buttonText = 'Starts in: $remaining';
        } else {
          buttonText = 'Coming Soon';
        }
        bgColor = widget.isToday
            ? appTheme.bg.withOpacity(0.5)
            : appTheme.borderMuted.withOpacity(0.3);
        textColor = widget.isToday ? appTheme.textMuted : appTheme.textMuted;
        break;
      case 'RESULTS_READY':
        buttonText = widget.participated ? 'View Results' : 'See Results';
        bgColor =
            widget.isToday ? appTheme.bg : appTheme.primary.withOpacity(0.1);
        textColor = widget.isToday ? appTheme.primary : appTheme.primary;
        break;
      default:
        buttonText = widget.status;
        bgColor = appTheme.borderMuted;
        textColor = appTheme.textMuted;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(appTheme.borderRadius / 2),
      ),
      padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 12, vertical: small ? 4 : 8),
      child: Text(
        buttonText,
        style: AppFont.secondaryTextStyle(
          context,
          fontSize: small ? 12 : 14,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
