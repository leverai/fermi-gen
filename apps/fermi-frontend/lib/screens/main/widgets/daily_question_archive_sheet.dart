// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/screens/daily_question/daily_question_screen.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class DailyQuestionArchiveSheet extends StatefulWidget {
  const DailyQuestionArchiveSheet({super.key});

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
          // Month/Year selector
          _buildMonthSelector(appTheme),
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

                return InkWell(
                  onTap: hasData
                      ? () {
                          // Check if this is today's active DQ
                          final dqController =
                              context.read<DailyQuestionController>();
                          final isToday = dateStr == dqController.todayDate;
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
                            // Navigate to DQ play screen
                            Navigator.of(context).pop(); // Close the sheet
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DailyQuestionScreen(),
                              ),
                            );
                          } else if (isActive && hasParticipated) {
                            // Already submitted - go to unified screen
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DailyQuestionScreen(
                                  questionDate: dateStr,
                                ),
                              ),
                            );
                          } else {
                            // Past date or closed - show unified screen with results
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DailyQuestionScreen(
                                  questionDate: dateStr,
                                ),
                              ),
                            );
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
