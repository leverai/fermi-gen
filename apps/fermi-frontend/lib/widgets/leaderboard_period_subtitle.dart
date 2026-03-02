import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fermi_frontend/models/survival_models.dart'
    show LeaderboardPeriod;
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

class LeaderboardPeriodSubtitle extends StatefulWidget {
  final LeaderboardPeriod period;

  const LeaderboardPeriodSubtitle({super.key, required this.period});

  @override
  State<LeaderboardPeriodSubtitle> createState() =>
      _LeaderboardPeriodSubtitleState();
}

class _LeaderboardPeriodSubtitleState extends State<LeaderboardPeriodSubtitle> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(LeaderboardPeriodSubtitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.period != widget.period) {
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    if (widget.period == LeaderboardPeriod.weekly ||
        widget.period == LeaderboardPeriod.monthly) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");

    if (d.inDays > 0) {
      final days = twoDigits(d.inDays);
      final hours = twoDigits(d.inHours.remainder(24));
      final minutes = twoDigits(d.inMinutes.remainder(60));
      final seconds = twoDigits(d.inSeconds.remainder(60));
      return "$days:$hours:$minutes:$seconds";
    }

    String twoDigitMinutes = twoDigits(d.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(d.inSeconds.remainder(60));
    return "${twoDigits(d.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    String text = '';

    final now = DateTime.now().toUtc();

    if (widget.period == LeaderboardPeriod.weekly) {
      final nextMonday = DateTime.utc(now.year, now.month, now.day)
          .add(Duration(days: 8 - now.weekday));
      final diff = nextMonday.difference(now);
      text = 'Ends in ${_formatDuration(diff)}';
    } else if (widget.period == LeaderboardPeriod.monthly) {
      final nextMonthFirstDay = (now.month == 12)
          ? DateTime.utc(now.year + 1, 1, 1)
          : DateTime.utc(now.year, now.month + 1, 1);
      final diff = nextMonthFirstDay.difference(now);
      text = 'Ends in ${_formatDuration(diff)}';
    } else if (widget.period == LeaderboardPeriod.lastWeek) {
      final lastWeekMonday = DateTime.utc(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday + 6));
      final lastWeekSunday = DateTime.utc(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday));
      final format = DateFormat('MMM d');
      text =
          '${format.format(lastWeekMonday)} - ${format.format(lastWeekSunday)}';
    } else if (widget.period == LeaderboardPeriod.lastMonth) {
      final lastMonthFirstDay = (now.month == 1)
          ? DateTime.utc(now.year - 1, 12, 1)
          : DateTime.utc(now.year, now.month - 1, 1);
      final lastMonthLastDay = DateTime.utc(now.year, now.month, 1)
          .subtract(const Duration(days: 1));
      final format = DateFormat('MMM d');
      text =
          '${format.format(lastMonthFirstDay)} - ${format.format(lastMonthLastDay)}';
    } else {
      return const SizedBox.shrink();
    }

    return Text(
      text,
      style: AppFont.primaryTextStyle(
        context,
        fontSize: 14,
        color: appTheme.textMuted,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
