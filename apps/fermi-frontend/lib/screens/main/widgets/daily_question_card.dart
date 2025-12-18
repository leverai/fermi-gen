import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class DailyQuestionCard extends StatelessWidget {
  final DateTime date;
  final String
      status; // 'ACTIVE', 'RESULTS_READY', 'SUBMITTED', 'PENDING', 'IN_PROGRESS'
  final bool isToday;
  final double? score;
  final int? rank;
  final VoidCallback? onTap; // Nullable to support disabled state

  const DailyQuestionCard({
    super.key,
    required this.date,
    required this.status,
    required this.isToday,
    this.score,
    this.rank,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final isPlayed = status == 'RESULTS_READY' ||
        (status == 'ACTIVE' && score != null); // Simplistic check

    // Formatting
    final dayFormat = DateFormat('d');
    final monthFormat = DateFormat('MMM');
    final weekdayFormat = DateFormat('EEEE');

    final isDisabled = onTap == null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(appTheme.borderRadius),
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: Container(
          width: 160, // Fixed width for carousel items
          decoration: BoxDecoration(
            color: isToday ? appTheme.primary : appTheme.bgLight,
            borderRadius: BorderRadius.circular(appTheme.borderRadius),
            border: Border.all(
              color: appTheme.border,
              width: appTheme.borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: appTheme.shadowColor,
                offset: appTheme.shadowOffset,
                blurRadius: 0,
              ),
            ],
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date Header
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekdayFormat.format(date).toUpperCase(),
                    style: AppFont.secondaryTextStyle(
                      context,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isToday ? appTheme.bg : appTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        dayFormat.format(date),
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: isToday ? appTheme.bg : appTheme.text,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        monthFormat.format(date).toUpperCase(),
                        style: AppFont.secondaryTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isToday ? appTheme.bg : appTheme.text,
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Content / Status
              if (isPlayed)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (score != null)
                      Text(
                        'SCORE',
                        style: AppFont.secondaryTextStyle(
                          context,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isToday
                              ? appTheme.bg.withOpacity(0.7)
                              : appTheme.textMuted,
                        ),
                      ),
                    if (score != null)
                      Text(
                        score!.toStringAsFixed(0),
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: isToday ? appTheme.bg : appTheme.text,
                        ),
                      ),
                    if (rank != null)
                      Text(
                        'Rank #$rank',
                        style: AppFont.secondaryTextStyle(
                          context,
                          fontSize: 12,
                          color: isToday ? appTheme.bg : appTheme.text,
                        ),
                      ),
                  ],
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: status == 'SUBMITTED'
                        ? (isToday
                            ? appTheme.bg.withOpacity(0.8)
                            : appTheme.success)
                        : status == 'PENDING'
                            ? (isToday
                                ? appTheme.bg.withOpacity(0.6)
                                : appTheme.borderMuted)
                            : status == 'IN_PROGRESS'
                                ? (isToday
                                    ? appTheme.bg.withOpacity(0.7)
                                    : appTheme.primary.withOpacity(0.7))
                                : (isToday ? appTheme.bg : appTheme.primary),
                    borderRadius:
                        BorderRadius.circular(appTheme.borderRadius / 2),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    status == 'SUBMITTED'
                        ? 'Submitted ✓'
                        : status == 'PENDING'
                            ? 'Pending...'
                            : status == 'IN_PROGRESS'
                                ? 'In Progress'
                                : 'PLAY',
                    style: AppFont.secondaryTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: status == 'SUBMITTED'
                          ? (isToday ? appTheme.success : appTheme.bg)
                          : status == 'PENDING'
                              ? (isToday
                                  ? appTheme.textMuted
                                  : appTheme.textMuted)
                              : status == 'IN_PROGRESS'
                                  ? (isToday ? appTheme.textMuted : appTheme.bg)
                                  : (isToday ? appTheme.primary : appTheme.bg),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
