import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/screens/main/widgets/daily_question_card.dart';
import 'package:fermi_frontend/screens/main/widgets/daily_question_archive_sheet.dart';
import 'package:fermi_frontend/screens/daily_question/daily_question_screen.dart';
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
        height: 190,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Show error state if loading failed
    if (controller.errorMessage != null) {
      return const SizedBox.shrink(); // Silently hide on API error
    }

    // Get sorted dates for carousel (most recent first)
    final dates = controller.carouselDates;
    if (dates.isEmpty) {
      return const SizedBox.shrink(); // No DQs available
    }

    final todayDate = controller.todayDate;
    final todayDocument = controller.todayDocument;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190, // Increased height to accommodate shadows
          child: ListView.separated(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            clipBehavior:
                Clip.none, // Allow shadows to exceed carousel bounds if needed
            scrollDirection: Axis.horizontal,
            itemCount: dates.length + 1, // Dates + Archive Button
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              // Archive Button (Last item)
              if (index == dates.length) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: _buildArchiveButton(context, appTheme),
                );
              }

              final date = dates[index];
              final participated = controller.weeklyItems[date] ?? false;
              final isToday = date == todayDate;
              final hasUnseen = controller.hasUnseenResults(date);

              // Determine display status and navigation behavior
              String displayStatus;
              VoidCallback? onTapCallback;

              if (isToday) {
                // Today's card: use real-time Firestore status
                final status = todayDocument?.status ?? 'NOT_STARTED';
                // print(
                //     '[DQCarousel] isToday=true, date=$date, todayDate=$todayDate, '
                //     'todayDocument=${todayDocument != null}, status=$status, participated=$participated');

                if (status == 'ACTIVE') {
                  if (!participated) {
                    // User can play
                    displayStatus = 'ACTIVE';
                    onTapCallback = () {
                      // print('[DQCarousel] Navigating to DailyQuestionScreen');
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const DailyQuestionScreen(),
                        ),
                      );
                    };
                  } else {
                    // User already submitted - go to screen to view submission
                    displayStatus = 'SUBMITTED';
                    onTapCallback = () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          // Don't pass questionDate - screen will use controller.todayDate
                          builder: (context) => const DailyQuestionScreen(),
                        ),
                      );
                    };
                  }
                } else if (status == 'CLOSED') {
                  final resultsReady = todayDocument?.resultsReady ?? false;
                  if (resultsReady) {
                    // Results are ready - navigate to unified screen
                    displayStatus = 'RESULTS_READY';
                    onTapCallback = () {
                      controller.markResultsSeen(date);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DailyQuestionScreen(
                            questionDate: date,
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
                  // NOT_STARTED - disable tap interaction
                  displayStatus = 'NOT_STARTED';
                  onTapCallback = null;
                }
              } else {
                // Past dates: always RESULTS_READY (all past DQs are closed)
                displayStatus = 'RESULTS_READY';
                onTapCallback = () {
                  controller.markResultsSeen(date);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DailyQuestionScreen(
                        questionDate: date,
                      ),
                    ),
                  );
                };
              }

              return Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: isToday
                      ? MediaQuery.of(context).size.width - 112
                      : 120, // Today is much wider
                  child: DailyQuestionCard(
                    date: DateTime.parse(date),
                    status: displayStatus,
                    isToday: isToday,
                    participated: participated,
                    hasUnseenResults: hasUnseen,
                    showTitle: isToday,
                    onTap: onTapCallback,
                    windowStart: isToday ? todayDocument?.windowStart : null,
                  ),
                ),
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
        height: double.infinity, // Added explicit height to match cards
        decoration: BoxDecoration(
          color: appTheme.bgLight,
          borderRadius: BorderRadius.circular(appTheme.borderRadius),
          border: Border.all(
            color: appTheme.bgLight,
            width: appTheme.borderWidth,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month, color: appTheme.text),
              const SizedBox(height: 8),
              Text(
                'Archive',
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: appTheme.text,
                ).copyWith(letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
