// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/screens/daily_question/daily_question_screen.dart';
import 'package:fermi_frontend/screens/daily_question/pre_daily_question_screen.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class DailyQuestionArchiveSheet extends StatefulWidget {
  const DailyQuestionArchiveSheet({
    super.key,
    required this.mainScreenController,
  });

  /// Controller for refreshing stats when returning from DQ screen.
  final MainScreenController mainScreenController;

  @override
  State<DailyQuestionArchiveSheet> createState() =>
      _DailyQuestionArchiveSheetState();
}

class _DailyQuestionArchiveSheetState extends State<DailyQuestionArchiveSheet> {
  late int _selectedYear;
  late int _selectedMonth;
  Map<String, bool> _monthItems = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().toUtc();
    _selectedYear = now.year;
    _selectedMonth = now.month;
    _loadMonthlyArchive();
  }

  Future<void> _loadMonthlyArchive() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final service = context.read<DailyQuestionService>();
      final archive =
          await service.getMonthlyArchive(_selectedYear, _selectedMonth);
      if (mounted) {
        setState(() {
          _monthItems = archive.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth += delta;
      if (_selectedMonth > 12) {
        _selectedMonth = 1;
        _selectedYear++;
      } else if (_selectedMonth < 1) {
        _selectedMonth = 12;
        _selectedYear--;
      }
    });
    _loadMonthlyArchive();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: appTheme.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: appTheme.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: appTheme.borderMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Month/Year selector with Arrow
          SizedBox(
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildMonthSelector(appTheme),
                Positioned(
                  right: 16,
                  child: IconButton(
                    icon: Icon(Icons.keyboard_arrow_down,
                        color: appTheme.text, size: 32),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(
                          'Error loading archive',
                          style: AppFont.secondaryTextStyle(
                            context,
                            color: appTheme.danger,
                          ),
                        ),
                      )
                    : _buildCalendarGrid(appTheme),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector(AppTheme appTheme) {
    final monthName =
        DateFormat('MMMM yyyy').format(DateTime(_selectedYear, _selectedMonth));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left, color: appTheme.text),
          onPressed: () => _changeMonth(-1),
        ),
        SizedBox(
          width: 160,
          child: Text(
            monthName,
            textAlign: TextAlign.center,
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: appTheme.text,
            ),
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right, color: appTheme.text),
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(AppTheme appTheme) {
    final firstDayOfMonth = DateTime(_selectedYear, _selectedMonth, 1);
    final lastDayOfMonth = DateTime(_selectedYear, _selectedMonth + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startWeekday = firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday

    // Adjust to start from Sunday (0)
    final startOffset = startWeekday % 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Weekday headers
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((day) => Expanded(
                      child: Center(
                        child: Text(
                          day,
                          style: AppFont.secondaryTextStyle(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: appTheme.textMuted,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          // Calendar grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
              ),
              itemCount: startOffset + daysInMonth,
              itemBuilder: (context, index) {
                if (index < startOffset) {
                  return const SizedBox.shrink();
                }

                final day = index - startOffset + 1;
                final dateStr = DateFormat('yyyy-MM-dd')
                    .format(DateTime(_selectedYear, _selectedMonth, day));
                final participated = _monthItems[dateStr];
                final hasData = participated != null;
                // Get today's date to check if this is a future date
                final dqController = context.read<DailyQuestionController>();
                final todayDateStr = dqController.todayDate;
                final isFuture =
                    todayDateStr != null && dateStr.compareTo(todayDateStr) > 0;
                // Future dates with data are SCHEDULED (not viewable yet)
                final isTappable = hasData && !isFuture;

                return InkWell(
                  onTap: isTappable
                      ? () {
                          // Reuse dqController from outer scope
                          final isToday = dateStr == todayDateStr;
                          final todayDoc = dqController.todayDocument;
                          final isActive =
                              isToday && (todayDoc?.status == 'ACTIVE');
                          final isNotStarted =
                              isToday && (todayDoc?.status == 'NOT_STARTED');
                          final hasParticipated =
                              dqController.weeklyItems[dateStr] ?? false;

                          // NOT_STARTED - do nothing (DQ hasn't activated yet)
                          if (isNotStarted) {
                            return;
                          }

                          if (isActive && !hasParticipated) {
                            // Navigate to pre-DQ screen first
                            // Capture controller and navigator before async gap to avoid lint warning
                            final mainController = widget.mainScreenController;
                            final navigator = Navigator.of(context);
                            navigator.pop(); // Close the sheet
                            navigator
                                .push(
                              MaterialPageRoute(
                                builder: (_) => PreDailyQuestionScreen(
                                  questionDate: dateStr,
                                  fromInvite: false,
                                ),
                              ),
                            )
                                .then((_) {
                              // Refresh stats when returning from DQ screen
                              // in case player submitted an answer
                              mainController.refreshInBackground();
                            });
                          } else if (isActive && hasParticipated) {
                            // Already submitted - go to unified screen
                            // Capture controller and navigator before async gap to avoid lint warning
                            final mainController = widget.mainScreenController;
                            final navigator = Navigator.of(context);
                            navigator.pop();
                            navigator
                                .push(
                              MaterialPageRoute(
                                builder: (_) => DailyQuestionScreen(
                                  questionDate: dateStr,
                                ),
                              ),
                            )
                                .then((_) {
                              // Refresh stats when returning from DQ screen
                              mainController.refreshInBackground();
                            });
                          } else {
                            // Past date or closed - check if user participated
                            final mainController = widget.mainScreenController;
                            final navigator = Navigator.of(context);
                            navigator.pop();

                            if (participated) {
                              // User participated - show results
                              navigator
                                  .push(
                                MaterialPageRoute(
                                  builder: (_) => DailyQuestionScreen(
                                    questionDate: dateStr,
                                  ),
                                ),
                              )
                                  .then((_) {
                                mainController.refreshInBackground();
                              });
                            } else {
                              // User hasn't participated - allow post-take
                              navigator
                                  .push(
                                MaterialPageRoute(
                                  builder: (_) => PreDailyQuestionScreen(
                                    questionDate: dateStr,
                                    isPostTake: true,
                                  ),
                                ),
                              )
                                  .then((_) {
                                mainController.refreshInBackground();
                              });
                            }
                          }
                        }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: hasData
                          ? (participated
                              ? appTheme.primary.withOpacity(0.2)
                              : appTheme.bgLight)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: hasData
                          ? Border.all(
                              color: participated
                                  ? appTheme.primary
                                  : appTheme.borderMuted,
                              width: 1,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            day.toString(),
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 14,
                              fontWeight:
                                  hasData ? FontWeight.w600 : FontWeight.w400,
                              color: hasData
                                  ? appTheme.text
                                  : appTheme.textMuted.withOpacity(0.5),
                            ),
                          ),
                          if (hasData && participated)
                            Container(
                              margin: const EdgeInsets.only(top: 2),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: appTheme.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
