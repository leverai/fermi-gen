import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/screens/main/widgets/daily_question_card.dart';
import 'package:fermi_frontend/screens/main/widgets/daily_question_archive_sheet.dart';
import 'package:fermi_frontend/screens/daily_question/daily_question_screen.dart';
import 'package:fermi_frontend/screens/daily_question/daily_question_results_screen.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class DailyQuestionCarousel extends StatelessWidget {
  const DailyQuestionCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DailyQuestionController>();
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    if (controller.isLoading) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Show error state if loading failed
    if (controller.errorMessage != null) {
      return const SizedBox.shrink(); // Silently hide on API error
    }

    // We want to show Today + Past 6 days in the carousel + Archive Button
    // The controller has `archive` (all past DQs) and `statusResponse` (today).
    // Let's combine them into a list of "Display Items".

    // 1. Today
    final todayItem = controller.statusResponse;
    if (todayItem == null) {
      // No DQ available - silently hide
      return const SizedBox.shrink();
    }

    // 2. Past items from archive (limit to last 6)
    // Archive is already sorted by date desc from backend, but sort again to be safe
    final archive = List.from(controller.archive);
    archive
        .sort((a, b) => b.questionDate.compareTo(a.questionDate)); // Descending

    final recentArchive = archive.take(6).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Daily Question',
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: appTheme.text,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180, // Height for cards
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            scrollDirection: Axis.horizontal,
            itemCount: 1 +
                recentArchive.length +
                1, // Today + Archive + Archive Button
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              // Archive Button (Last item)
              if (index == 1 + recentArchive.length) {
                return _buildArchiveButton(context, appTheme);
              }

              // Today (First item)
              if (index == 0) {
                final windowStatus = todayItem.windowStatus;
                final userStatus = todayItem.userStatus;
                final hasResults = todayItem.hasResults;

                // Determine display status and navigation behavior
                String displayStatus;
                VoidCallback? onTapCallback;

                if (windowStatus == 'ACTIVE') {
                  if (userStatus == null || userStatus == 'NOT_STARTED') {
                    // User can play
                    displayStatus = 'ACTIVE';
                    onTapCallback = () {
                      print('[DQCarousel] Navigating to DailyQuestionScreen');
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const DailyQuestionScreen(),
                        ),
                      );
                    };
                  } else if (userStatus == 'IN_PROGRESS') {
                    // User started but hasn't submitted - backend disallows re-start
                    displayStatus = 'IN_PROGRESS';
                    onTapCallback = () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                              Text('You have already started this question.'),
                        ),
                      );
                    };
                  } else if (userStatus == 'SUBMITTED') {
                    // User submitted - show "submitted" state
                    displayStatus = 'SUBMITTED';
                    onTapCallback = () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'You have already submitted your answer. Results available after 8 PM CT.'),
                        ),
                      );
                    };
                  } else {
                    displayStatus = 'ACTIVE';
                    onTapCallback = null;
                  }
                } else if (windowStatus == 'CLOSED') {
                  if (hasResults) {
                    // Results are ready - navigate to results
                    displayStatus = 'RESULTS_READY';
                    onTapCallback = () {
                      print('[DQCarousel] Navigating to results');
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DailyQuestionResultsScreen(
                            questionDate: todayItem.questionDate ??
                                DateFormat('yyyy-MM-dd').format(DateTime.now()),
                          ),
                        ),
                      );
                    };
                  } else {
                    // Results pending - disable navigation
                    displayStatus = 'PENDING';
                    onTapCallback = () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Results are pending. Please check back later.'),
                        ),
                      );
                    };
                  }
                } else {
                  // NOT_STARTED or other
                  displayStatus = windowStatus;
                  onTapCallback = null;
                }

                return SizedBox(
                  width: 200, // Today is larger/wider
                  child: DailyQuestionCard(
                    date: DateTime.now(), // Today
                    status: displayStatus,
                    isToday: true,
                    score: userStatus == 'SUBMITTED'
                        ? null
                        : null, // Score only shown in results
                    rank: null,
                    onTap: onTapCallback,
                  ),
                );
              }

              // Archive Items (past DQs)
              final archiveItem = recentArchive[index - 1];
              return DailyQuestionCard(
                date: DateTime.parse(archiveItem.questionDate),
                status:
                    'RESULTS_READY', // All archive items are CLOSED with results
                isToday: false,
                score: archiveItem.userScore,
                rank: archiveItem.userRank,
                onTap: () {
                  // Navigate to results view for past DQs
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DailyQuestionResultsScreen(
                        questionDate: archiveItem.questionDate,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildArchiveButton(BuildContext context, AppTheme appTheme) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const DailyQuestionArchiveSheet(),
        );
      },
      borderRadius: BorderRadius.circular(appTheme.borderRadius),
      child: Container(
        width: 100,
        decoration: BoxDecoration(
          color: appTheme.bgLight,
          borderRadius: BorderRadius.circular(appTheme.borderRadius),
          border: Border.all(
            color: appTheme.borderMuted,
            width: appTheme.borderWidth,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month, color: appTheme.textMuted),
              const SizedBox(height: 8),
              Text(
                'Archive',
                style: AppFont.secondaryTextStyle(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: appTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
