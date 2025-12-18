import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/screens/daily_question/daily_question_results_screen.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class DailyQuestionArchiveSheet extends StatelessWidget {
  const DailyQuestionArchiveSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final controller = context.watch<DailyQuestionController>();
    final archive = controller.archive;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: appTheme.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: appTheme.borderMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Archive',
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: appTheme.text,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: archive.isEmpty
                ? Center(
                    child: Text(
                      'No past questions yet',
                      style: AppFont.secondaryTextStyle(
                        context,
                        color: appTheme.borderMuted,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: archive.length,
                    itemBuilder: (context, index) {
                      final item = archive[index];
                      final date = DateTime.parse(item.questionDate);
                      final dateFormat = DateFormat('MMM d, yyyy');
                      final weekdayFormat = DateFormat('EEEE');

                      return ListTile(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              weekdayFormat.format(date),
                              style: AppFont.secondaryTextStyle(
                                context,
                                fontSize: 12,
                                color: appTheme.borderMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateFormat.format(date),
                              style: AppFont.primaryTextStyle(
                                context,
                                fontWeight: FontWeight.w600,
                                color: appTheme.text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.questionText,
                              style: AppFont.secondaryTextStyle(
                                context,
                                fontSize: 12,
                                color: appTheme.textMuted,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                        trailing: item.userParticipated
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (item.userScore != null)
                                    Text(
                                      'Score: ${item.userScore!.toStringAsFixed(0)}',
                                      style: AppFont.primaryTextStyle(
                                        context,
                                        fontWeight: FontWeight.bold,
                                        color: appTheme.primary,
                                      ),
                                    ),
                                  if (item.userRank != null)
                                    Text(
                                      'Rank #${item.userRank}',
                                      style: AppFont.secondaryTextStyle(
                                        context,
                                        fontSize: 12,
                                        color: appTheme.textMuted,
                                      ),
                                    ),
                                ],
                              )
                            : Text(
                                'View Results',
                                style: AppFont.secondaryTextStyle(
                                  context,
                                  fontWeight: FontWeight.w600,
                                  color: appTheme.primary,
                                ),
                              ),
                        onTap: () {
                          // Navigate to results screen for past DQs
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => DailyQuestionResultsScreen(
                                questionDate: item.questionDate,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
