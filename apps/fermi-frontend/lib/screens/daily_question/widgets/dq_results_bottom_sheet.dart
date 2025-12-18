import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/question_widget.dart';
import 'package:fermi_frontend/widgets/slider_text_mirror.dart';

/// Handle status for the DQ results bottom sheet.
enum DQResultsHandleStatus {
  /// Results not yet ready, show countdown.
  pending,

  /// Results are ready but user hasn't viewed them.
  ready,

  /// User has viewed the results.
  seen,
}

/// Draggable bottom sheet for displaying Daily Question results.
/// Shows a handle with status text and the full results when expanded.
class DQResultsBottomSheet extends StatefulWidget {
  /// Date of the DQ in YYYY-MM-DD format.
  final String questionDate;

  /// Current handle status.
  final DQResultsHandleStatus status;

  /// When results will be ready (for countdown display).
  final DateTime? windowEnd;

  /// Callback when the sheet is expanded (user views results).
  final VoidCallback? onResultsViewed;

  /// Pre-loaded results (optional, will fetch if not provided).
  final DQResultsResponse? results;

  /// Service to fetch results if not provided.
  final DailyQuestionService? service;

  const DQResultsBottomSheet({
    super.key,
    required this.questionDate,
    required this.status,
    this.windowEnd,
    this.onResultsViewed,
    this.results,
    this.service,
  });

  @override
  State<DQResultsBottomSheet> createState() => _DQResultsBottomSheetState();
}

class _DQResultsBottomSheetState extends State<DQResultsBottomSheet> {
  DQResultsResponse? _results;
  bool _isLoading = false;
  String? _error;
  bool _isExpanded = false;

  // Timer for countdown
  Timer? _countdownTimer;
  Duration _timeUntilResults = Duration.zero;

  @override
  void initState() {
    super.initState();
    _results = widget.results;

    if (widget.status == DQResultsHandleStatus.pending &&
        widget.windowEnd != null) {
      _startCountdownTimer();
    }

    // Load results if ready and not provided
    if (widget.status != DQResultsHandleStatus.pending && _results == null) {
      _loadResults();
    }
  }

  @override
  void didUpdateWidget(DQResultsBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Status changed from pending to ready
    if (oldWidget.status == DQResultsHandleStatus.pending &&
        widget.status != DQResultsHandleStatus.pending) {
      _countdownTimer?.cancel();
      if (_results == null) {
        _loadResults();
      }
    }

    // Window end changed
    if (widget.windowEnd != oldWidget.windowEnd &&
        widget.status == DQResultsHandleStatus.pending) {
      _startCountdownTimer();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _updateTimeUntilResults();

    // Update every minute to avoid excessive rebuilds
    _countdownTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _updateTimeUntilResults();
    });
  }

  void _updateTimeUntilResults() {
    if (widget.windowEnd == null) return;

    final now = DateTime.now().toUtc();
    final remaining = widget.windowEnd!.difference(now);

    if (mounted) {
      setState(() {
        _timeUntilResults = remaining.isNegative ? Duration.zero : remaining;
      });
    }
  }

  Future<void> _loadResults() async {
    if (widget.service == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results =
          await widget.service!.getResultsForDate(widget.questionDate);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _getFriendlyErrorMessage(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  String _getFriendlyErrorMessage(String error) {
    final errorLower = error.toLowerCase();
    if (errorLower.contains('results are not yet available') ||
        errorLower.contains('not yet available') ||
        errorLower.contains('409')) {
      return 'Results are pending. Please check back later.';
    }
    if (errorLower.contains('no daily question found') ||
        errorLower.contains('not found') ||
        errorLower.contains('404')) {
      return 'No daily question found for this date.';
    }
    if (error.length > 150) {
      return '${error.substring(0, 150)}...';
    }
    return error;
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
    return '${duration.inMinutes}m';
  }

  void _onSheetExpanded() {
    if (!_isExpanded) {
      _isExpanded = true;
      widget.onResultsViewed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return DraggableScrollableSheet(
      initialChildSize: 0.12,
      minChildSize: 0.12,
      maxChildSize: 0.75,
      snap: true,
      snapSizes: const [0.12, 0.75],
      builder: (context, scrollController) {
        return NotificationListener<DraggableScrollableNotification>(
          onNotification: (notification) {
            if (notification.extent > 0.5 &&
                widget.status == DQResultsHandleStatus.ready) {
              _onSheetExpanded();
            }
            return false;
          },
          child: Container(
            decoration: BoxDecoration(
              color: appTheme.bgLight,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: appTheme.shadowColor,
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ListView(
              controller: scrollController,
              padding: EdgeInsets.zero,
              children: [
                _buildHandle(appTheme),
                if (widget.status != DQResultsHandleStatus.pending)
                  _buildContent(appTheme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHandle(AppTheme appTheme) {
    String handleText;
    Color handleColor;
    bool enabled = widget.status != DQResultsHandleStatus.pending;

    switch (widget.status) {
      case DQResultsHandleStatus.pending:
        final remaining = _formatRemainingTime(_timeUntilResults);
        handleText = 'Results in $remaining';
        handleColor = appTheme.textMuted;
        break;
      case DQResultsHandleStatus.ready:
        handleText = 'Results ready!';
        handleColor = appTheme.success;
        break;
      case DQResultsHandleStatus.seen:
        handleText = 'Results seen';
        handleColor = appTheme.textMuted;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: enabled ? appTheme.border : appTheme.borderMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),
          // Status text
          Text(
            handleText,
            style: AppFont.secondaryTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: handleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(AppTheme appTheme) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(48),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _error!.toLowerCase().contains('pending')
                  ? Icons.schedule
                  : Icons.error_outline,
              size: 48,
              color: appTheme.danger,
            ),
            const SizedBox(height: 12),
            Text(
              _error!,
              style: AppFont.secondaryTextStyle(
                context,
                color: appTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_results == null) {
      return const SizedBox.shrink();
    }

    final results = _results!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Question (compact)
          QuestionWidget(
            text: results.questionText,
            tags: const [],
            height: 100,
          ),
          const SizedBox(height: 16),

          // Correct Answer
          _buildSection(
            appTheme,
            'Correct Answer',
            child: SliderTextMirror(value: results.correctAnswer),
          ),
          const SizedBox(height: 12),

          // User's Answer (if participated)
          if (results.userAnswer != null) ...[
            _buildSection(
              appTheme,
              'Your Answer',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SliderTextMirror(value: results.userAnswer!),
                  const SizedBox(height: 8),
                  if (results.userScore != null)
                    Text(
                      'Score: ${results.userScore!.toStringAsFixed(0)}',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: appTheme.primary,
                      ),
                    ),
                  if (results.userRank != null)
                    Text(
                      'Rank: #${results.userRank} of ${results.totalParticipants}',
                      style: AppFont.secondaryTextStyle(
                        context,
                        color: appTheme.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            _buildSection(
              appTheme,
              'Your Result',
              child: Text(
                'You did not participate in this question.',
                style: AppFont.secondaryTextStyle(
                  context,
                  color: appTheme.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Leaderboard
          _buildSection(
            appTheme,
            'Leaderboard (${results.totalParticipants})',
            child: results.leaderboard.isEmpty
                ? Text(
                    'No participants yet.',
                    style: AppFont.secondaryTextStyle(
                      context,
                      color: appTheme.textMuted,
                    ),
                  )
                : Column(
                    children: results.leaderboard.take(10).map((entry) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 28,
                              child: Text(
                                '#${entry.rank}',
                                style: AppFont.secondaryTextStyle(
                                  context,
                                  fontWeight: FontWeight.w700,
                                  color: appTheme.text,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                entry.displayName ?? 'Anonymous',
                                style: AppFont.secondaryTextStyle(
                                  context,
                                  color: appTheme.text,
                                ),
                              ),
                            ),
                            Text(
                              '${entry.score.toStringAsFixed(0)} pts',
                              style: AppFont.secondaryTextStyle(
                                context,
                                fontWeight: FontWeight.w600,
                                color: appTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(AppTheme appTheme, String title,
      {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.bg,
        borderRadius: BorderRadius.circular(appTheme.borderRadius),
        border: Border.all(
          color: appTheme.border,
          width: appTheme.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppFont.secondaryTextStyle(
              context,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: appTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
