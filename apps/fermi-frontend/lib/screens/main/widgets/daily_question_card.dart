import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class DailyQuestionCard extends StatelessWidget {
  final DateTime date;
  final String
      status; // 'ACTIVE', 'RESULTS_READY', 'SUBMITTED', 'PENDING', 'NOT_STARTED'
  final bool isToday;
  final bool participated;
  final bool hasUnseenResults;
  final bool showTitle;
  final VoidCallback? onTap; // Nullable to support disabled state

  const DailyQuestionCard({
    super.key,
    required this.date,
    required this.status,
    required this.isToday,
    this.participated = false,
    this.hasUnseenResults = false,
    this.showTitle = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

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
        child: Stack(
          children: [
            Container(
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
                  // Content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showTitle) ...[
                        Text(
                          'Daily Guess',
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: isToday ? appTheme.bg : appTheme.text,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
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
                    ],
                  ),

                  // Status Button
                  _buildStatusButton(context, appTheme),
                ],
              ),
            ),
            // Unseen results indicator (green dot)
            if (hasUnseenResults)
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
                      color: isToday ? appTheme.primary : appTheme.bgLight,
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

  Widget _buildStatusButton(BuildContext context, AppTheme appTheme) {
    String buttonText;
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'ACTIVE':
        buttonText = 'PLAY';
        bgColor = isToday ? appTheme.bg : appTheme.primary;
        textColor = isToday ? appTheme.primary : appTheme.bg;
        break;
      case 'SUBMITTED':
        buttonText = 'Submitted ✓';
        bgColor = isToday
            ? appTheme.bg.withOpacity(0.8)
            : appTheme.success.withOpacity(0.2);
        textColor = isToday ? appTheme.success : appTheme.success;
        break;
      case 'PENDING':
        buttonText = 'Pending...';
        bgColor = isToday
            ? appTheme.bg.withOpacity(0.6)
            : appTheme.borderMuted.withOpacity(0.3);
        textColor = isToday ? appTheme.textMuted : appTheme.textMuted;
        break;
      case 'NOT_STARTED':
        buttonText = 'Coming Soon';
        bgColor = isToday
            ? appTheme.bg.withOpacity(0.5)
            : appTheme.borderMuted.withOpacity(0.3);
        textColor = isToday ? appTheme.textMuted : appTheme.textMuted;
        break;
      case 'RESULTS_READY':
        buttonText = participated ? 'View Results' : 'See Results';
        bgColor = isToday ? appTheme.bg : appTheme.primary.withOpacity(0.1);
        textColor = isToday ? appTheme.primary : appTheme.primary;
        break;
      default:
        buttonText = status;
        bgColor = appTheme.borderMuted;
        textColor = appTheme.textMuted;
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(appTheme.borderRadius / 2),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Text(
        buttonText,
        style: AppFont.secondaryTextStyle(
          context,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
    );
  }
}
