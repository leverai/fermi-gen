// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/widgets/avatar_widget.dart';

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

  /// Current user's display name for showing in leaderboard.
  final String? userDisplayName;

  /// Current user's avatar URL for showing in leaderboard.
  final String? userAvatarUrl;

  const DQResultsBottomSheet({
    super.key,
    required this.questionDate,
    required this.status,
    this.windowEnd,
    this.onResultsViewed,
    this.results,
    this.service,
    this.userDisplayName,
    this.userAvatarUrl,
  });

  @override
  State<DQResultsBottomSheet> createState() => _DQResultsBottomSheetState();
}

class _DQResultsBottomSheetState extends State<DQResultsBottomSheet> {
  DQResultsResponse? _results;
  bool _isLoading = false;
  String? _error;
  bool _isExpanded = false;
  bool _showAll = true; // Whether to include post-takers in leaderboard

  // Timer for countdown
  Timer? _countdownTimer;
  Duration _timeUntilResults = Duration.zero;

  // Scroll controller for the draggable sheet
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  static const double _minSize = 0.12;
  static const double _maxSize = 0.75;
  // Threshold to determine if sheet is expanded or collapsed for icon purpose
  // Midpoint between min and max
  static const double _expansionThreshold = (_minSize + _maxSize) / 2;

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

    // Listen to sheet controller to update icon
    _sheetController.addListener(_onSheetChanged);
  }

  void _onSheetChanged() {
    if (!_sheetController.isAttached) return;

    // Check if we need to update the expanded state based on size
    // We only update if crossing the threshold to avoid excessive rebuilds
    final currentSize = _sheetController.size;
    final isNowExpanded = currentSize > _expansionThreshold;

    // Only setState if the logical state has changed to prevent loop
    if (_isExpanded != isNowExpanded) {
      setState(() {
        _isExpanded = isNowExpanded;
      });
      // If expanded and not previously tracked, trigger callback
      if (isNowExpanded) {
        widget.onResultsViewed?.call();
      }
    }
  }

  void _toggleSheet() {
    if (!_sheetController.isAttached) return;

    // Toggle between min and max size
    // If currently closer to max, go to min. Else go to max.
    final targetSize =
        _sheetController.size > _expansionThreshold ? _minSize : _maxSize;

    _sheetController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(DQResultsBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Question date changed (new DQ scheduled after results reveal)
    if (widget.questionDate != oldWidget.questionDate) {
      // Clear old data and reset state
      _results = null;
      _error = null;
      // Reset sheet if needed? (optional, but good UX to collapse)
      if (_sheetController.isAttached) {
        _onSheetChanged(); // Re-evaluate expansion state
      }

      if (widget.status == DQResultsHandleStatus.pending &&
          widget.windowEnd != null) {
        _startCountdownTimer();
      } else {
        _countdownTimer?.cancel();
        if (widget.status != DQResultsHandleStatus.pending) {
          _loadResults();
        }
      }
      return; // No need to check other conditions
    }

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
    _sheetController.removeListener(_onSheetChanged);
    _sheetController.dispose();
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
      final results = await widget.service!.getResultsForDate(
        widget.questionDate,
        includePostTakes: _showAll,
      );
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

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return DraggableScrollableActuator(
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: _minSize,
        minChildSize: _minSize,
        maxChildSize: _maxSize,
        snap: true,
        snapSizes: const [_minSize, _maxSize],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: appTheme.bg,
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
                // Make handle tap-able to toggle sheet
                GestureDetector(
                  onTap: _toggleSheet,
                  behavior: HitTestBehavior
                      .translucent, // Allow tap on empty space in header
                  child: _buildHandle(appTheme),
                ),
                if (widget.status != DQResultsHandleStatus.pending)
                  _buildContent(appTheme),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHandle(AppTheme appTheme) {
    bool enabled = widget.status != DQResultsHandleStatus.pending;

    Widget handleContent;
    if (widget.status == DQResultsHandleStatus.pending) {
      final remaining = _formatRemainingTime(_timeUntilResults);
      handleContent = Text(
        'Results in: $remaining',
        style: AppFont.secondaryTextStyle(
          context,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: appTheme.textMuted,
        ),
      );
    } else {
      // For both ready and seen states, show "Leaderboard (N)"
      final totalParticipants = _results?.totalParticipants ?? 0;
      handleContent = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Leaderboard',
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: appTheme.text,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($totalParticipants)',
            style: AppFont.secondaryTextStyle(
              context,
              color: appTheme.textMuted,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Drag handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: appTheme.borderMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 4),
          // Status text/header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48), // Spacer
                handleContent,
                IconButton(
                  icon: Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: appTheme.borderMuted,
                    size: 32,
                  ),
                  onPressed: _toggleSheet,
                ),
              ],
            ),
          ),
          // Query row with Show All checkbox (only when results are ready)
          if (enabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    'Show All',
                    style: AppFont.secondaryTextStyle(
                      context,
                      fontSize: 12,
                      color: appTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: Checkbox(
                      value: _showAll,
                      activeColor: appTheme.secondary,
                      checkColor: appTheme.bgLight,
                      onChanged: (value) {
                        setState(() {
                          _showAll = value ?? true;
                        });
                        _loadResults();
                      },
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
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

    // Build leaderboard entries with user added if not in top 10
    final leaderboardEntries = _buildLeaderboardEntries(results);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Leaderboard entries
          if (leaderboardEntries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No participants yet.',
                style: AppFont.secondaryTextStyle(
                  context,
                  color: appTheme.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            ...leaderboardEntries,
        ],
      ),
    );
  }

  /// Build leaderboard entries, adding user if not in top 10
  List<Widget> _buildLeaderboardEntries(DQResultsResponse results) {
    final List<Widget> entries = [];
    final userRank = results.userRank;
    final top10 = results.leaderboard.take(10).toList();

    // Build top 10 entries
    for (final entry in top10) {
      entries.add(_buildLeaderboardRow(entry, entry.isCurrentUser));
    }

    // Add user's entry if they participated but aren't in top 10
    if (userRank != null && userRank > 10 && results.userScore != null) {
      // Add separator
      entries.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '···',
            style: AppFont.secondaryTextStyle(
              context,
              color: Theme.of(context).extension<AppTheme>()?.textMuted ??
                  AppTheme.defaultTheme().textMuted,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );

      // Create synthetic entry for current user
      final userEntry = DQLeaderboardEntry(
        rank: userRank,
        player: DQPlayer(
          displayName: widget.userDisplayName ?? 'You',
          avatarUrl: widget.userAvatarUrl,
        ),
        score: results.userScore!,
        timeTakenS: 0, // Not displayed
        isPostTake: results.userIsPostTake,
        isCurrentUser: true,
      );
      entries.add(_buildLeaderboardRow(userEntry, true));
    }

    return entries;
  }

  /// Build a single leaderboard row
  Widget _buildLeaderboardRow(DQLeaderboardEntry entry, bool isCurrentUser) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final player = entry.player;
    final displayName = player?.displayName ?? 'Anonymous';
    final avatarUrl = player?.avatarUrl;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? appTheme.primaryMuted.withOpacity(0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: isCurrentUser
            ? Border.all(color: appTheme.primary, width: 2)
            : null,
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rank}',
              style: AppFont.secondaryTextStyle(
                context,
                fontWeight: FontWeight.w700,
                color: isCurrentUser
                    ? appTheme.primary
                    : entry.isPostTake
                        ? appTheme.danger
                        : appTheme.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Avatar
          AvatarWidget(
            imageUrl: avatarUrl,
            size: 28,
            backgroundColor: appTheme.border,
            placeholder: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
              style: AppFont.secondaryTextStyle(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: appTheme.text,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Name
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    isCurrentUser ? '$displayName (You)' : displayName,
                    style: AppFont.secondaryTextStyle(
                      context,
                      color: appTheme.text,
                      fontWeight:
                          isCurrentUser ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Post-take indicator
                if (entry.isPostTake) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: appTheme.danger,
                  ),
                ],
              ],
            ),
          ),
          // Score
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
  }
}
