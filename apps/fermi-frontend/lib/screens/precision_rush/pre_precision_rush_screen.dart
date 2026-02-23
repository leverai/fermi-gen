import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/subscription_service.dart';
import 'package:fermi_frontend/services/feedback_service.dart';
import 'package:fermi_frontend/services/ad_service.dart';
import 'package:fermi_frontend/models/precision_rush_models.dart';
import 'package:fermi_frontend/models/survival_models.dart'
    show LeaderboardPeriod;
import 'package:fermi_frontend/models/user_limits.dart';
import 'package:fermi_frontend/screens/paywall_screen.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/avatar_widget.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/utils/answer_format.dart';

/// Pre-Precision Rush screen shown before starting a run.
class PrePrecisionRushScreen extends StatefulWidget {
  const PrePrecisionRushScreen({super.key});

  @override
  State<PrePrecisionRushScreen> createState() => _PrePrecisionRushScreenState();
}

class _PrePrecisionRushScreenState extends State<PrePrecisionRushScreen> {
  bool _isLoading = true;
  String? _error;
  PRStatsResponse? _stats;
  UserLimits? _userLimits;
  bool _isReturning = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final results = await Future.wait([
        apiService.prGetStats(),
        apiService.getUserLimitsTyped(),
      ]);
      if (mounted) {
        setState(() {
          _stats = PRStatsResponse.fromJson(results[0] as Map<String, dynamic>);
          _userLimits = results[1] as UserLimits;
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

  Future<void> _handleStart({bool withAd = false, int? runId}) async {
    if (mounted) {
      setState(() {
        _isReturning = true;
      });
    }

    String path = '/precision-rush?withAd=$withAd';
    if (runId != null) {
      path += '&runId=$runId';
    }
    await context.push(path);

    if (mounted) {
      // Refresh data when returning from run
      setState(() {
        _isReturning = false;
      });
      _fetchData();
    }
  }

  void _handleLeave() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/main');
    }
  }

  void _showPaywall() {
    final authService = context.read<AuthService>();
    final isAnonymous = authService.isAnonymous;

    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          subscriptionService:
              Provider.of<SubscriptionService>(context, listen: false),
          isAnonymous: isAnonymous,
        ),
      ),
    )
        .then((purchased) {
      if (purchased == true) {
        _fetchData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    if (_isLoading || _isReturning) {
      return ResponsiveContainer(
        backgroundColor: appTheme.bg,
        child: Scaffold(
          backgroundColor: appTheme.bg,
          body: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return ResponsiveContainer(
        backgroundColor: appTheme.bg,
        child: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error: $_error',
                    style: TextStyle(color: appTheme.danger)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchData,
                  child: const Text('Try Again'),
                ),
                TextButton(
                  onPressed: _handleLeave,
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ResponsiveContainer(
      backgroundColor: appTheme.bg,
      child: DefaultTabController(
        length: 2,
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) {
            if (didPop) return;
            _handleLeave();
          },
          child: Scaffold(
            backgroundColor: appTheme.bg,
            body: SafeArea(
              child: Column(
                children: [
                  // Header
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: Icon(Icons.chevron_left,
                            color: appTheme.border, size: 32),
                        onPressed: () {
                          FeedbackService.instance.secondaryClick();
                          _handleLeave();
                        },
                        tooltip: 'Back',
                      ),
                    ),
                  ),

                  // Tab Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: appTheme.bgDark,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: appTheme.bgLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        labelStyle: AppFont.primaryTextStyle(
                          context,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                        unselectedLabelStyle: AppFont.primaryTextStyle(
                          context,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        labelColor: appTheme.text,
                        unselectedLabelColor: appTheme.textMuted,
                        tabs: const [
                          Tab(text: 'Play'),
                          Tab(text: 'Leaderboard'),
                        ],
                        onTap: (_) => FeedbackService.instance.buttonPress(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Content
                  Expanded(
                    child: TabBarView(
                      children: [
                        _PRPlayTab(
                          stats: _stats,
                          userLimits: _userLimits,
                          onStart: _handleStart,
                          onShowPaywall: _showPaywall,
                        ),
                        const _PRLeaderboardTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PRPlayTab extends StatefulWidget {
  final PRStatsResponse? stats;
  final UserLimits? userLimits;
  final Future<void> Function({bool withAd, int? runId}) onStart;
  final VoidCallback onShowPaywall;

  const _PRPlayTab({
    required this.stats,
    required this.userLimits,
    required this.onStart,
    required this.onShowPaywall,
  });

  @override
  State<_PRPlayTab> createState() => _PRPlayTabState();
}

class _PRPlayTabState extends State<_PRPlayTab> {
  void _handleWatchAd() {
    final adService = AdService.instance;
    if (!adService.isAdLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not ready. Please try again.')),
      );
      adService.loadRewardedAd();
      return;
    }

    adService.showRewardedAd(
      onComplete: () {
        if (!mounted) return;
        widget.onStart(withAd: true);
      },
      onSkipped: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Ad skipped. Please watch the full ad.')),
        );
      },
      onFailed: () {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ad failed to play. Please try again.')),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final prColor = appTheme.precisionRush;

    // Limits check
    final bool isResume = widget.stats?.activeRunId != null;
    final bool canPlay =
        isResume || (widget.userLimits?.canPlayPrecisionRush ?? true);
    final int bestTas = widget.stats?.bestTas.toInt() ?? 0;
    // final int avgTas = widget.stats?.averageTas.toInt() ?? 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: appTheme.bgLight,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: Icon(
                Icons.bolt,
                size: 48,
                color: prColor,
              ),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              'Precision Rush',
              textAlign: TextAlign.center,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: appTheme.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Speed meets accuracy.\n6 Questions.',
              textAlign: TextAlign.center,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: appTheme.textMuted,
                height: 1.4,
              ),
            ),

            // Stats
            if (bestTas > 0) ...[
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      Text(
                        'Best',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: appTheme.textMuted,
                        ),
                      ),
                      Text(
                        formatNumberWithCommas(bestTas),
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: prColor,
                        ),
                      ),
                    ],
                  ),
                  // const SizedBox(width: 32),
                  // Column(
                  //   children: [
                  //     Text(
                  //       'Average',
                  //       style: AppFont.primaryTextStyle(
                  //         context,
                  //         fontSize: 14,
                  //         fontWeight: FontWeight.w500,
                  //         color: appTheme.textMuted,
                  //       ),
                  //     ),
                  //     Text(
                  //       formatNumberWithCommas(avgTas),
                  //       style: AppFont.primaryTextStyle(
                  //         context,
                  //         fontSize: 20,
                  //         fontWeight: FontWeight.w700,
                  //         color: appTheme.text,
                  //       ),
                  //     ),
                  //   ],
                  // ),
                ],
              ),
            ],
            if (bestTas > 0)
              const SizedBox(height: 36)
            else
              const SizedBox(height: 48),

            // Actions
            if (canPlay)
              SizedBox(
                width: 200,
                child: MainButton(
                  onPressed: () => widget.onStart(
                      withAd: false, runId: widget.stats?.activeRunId),
                  label:
                      isResume ? MainButtonLabel.resume : MainButtonLabel.start,
                  backgroundColor: prColor,
                  shadowColor: appTheme.precisionRushMuted,
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 130,
                    child: MainButton(
                      onPressed: widget.onShowPaywall,
                      customLabel: 'Go PRO',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'or',
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: appTheme.textMuted,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 130,
                    child: MainButton(
                      onPressed: _handleWatchAd,
                      customLabel: 'Watch Ad 🎬',
                      backgroundColor: appTheme.secondary,
                      shadowColor: appTheme.secondaryMuted,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 40),

            // Descriptive Footer
            Text(
              'Join the leaderboard!',
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: appTheme.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You are rewarded for speed and accuracy.',
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: appTheme.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              '40 Seconds each • Resume anytime',
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: appTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PRLeaderboardTab extends StatefulWidget {
  const _PRLeaderboardTab();

  @override
  State<_PRLeaderboardTab> createState() => _PRLeaderboardTabState();
}

class _PRLeaderboardTabState extends State<_PRLeaderboardTab>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final _scrollController = ScrollController();
  final List<PRLeaderboardEntry> _entries = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;
  PRLeaderboardEntry? _currentUser;
  LeaderboardPeriod _selectedPeriod = LeaderboardPeriod.weekly;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fetchLeaderboard();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoading &&
        _hasMore) {
      _fetchLeaderboard();
    }
  }

  Future<void> _fetchLeaderboard() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.prGetLeaderboard(
        page: _currentPage,
        pageSize: 25,
        period: _selectedPeriod,
      );

      if (mounted) {
        setState(() {
          _entries.addAll(response.entries);
          _currentUser = response.currentUser;
          _hasMore = _currentPage < response.totalPages;
          _currentPage++;
          _isLoading = false;
        });

        if (_currentPage == 2) {
          _animationController.forward(from: 0);
        }
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

  Widget _buildRankBadge(AppTheme theme, int rank) {
    Color badgeColor;
    if (rank == 1) {
      badgeColor = const Color(0xFFFFD700); // Gold
    } else if (rank == 2) {
      badgeColor = const Color(0xFFC0C0C0); // Silver
    } else if (rank == 3) {
      badgeColor = const Color(0xFFCD7F32); // Bronze
    } else {
      return Text(
        '#$rank',
        style: AppFont.primaryTextStyle(
          context,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.textMuted,
        ),
      );
    }

    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: badgeColor, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '$rank',
        style: AppFont.primaryTextStyle(
          context,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: badgeColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final prColor = appTheme.precisionRush;

    Widget content;

    if (_entries.isEmpty && _isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _entries.isEmpty) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Failed to load leaderboard',
                style: TextStyle(color: appTheme.danger)),
            TextButton(
              onPressed: _fetchLeaderboard,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_entries.isEmpty) {
      content = Center(
        child: Text(
          'No records yet. Be the first!',
          style: AppFont.primaryTextStyle(context, color: appTheme.textMuted),
        ),
      );
    } else {
      content = ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _entries.length + (_isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _entries.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }

          final entry = _entries[index];
          final isMe = _currentUser != null &&
              _currentUser!.rank == entry.rank &&
              _currentUser!.bestTas == entry.bestTas;

          final animation = CurvedAnimation(
            parent: _animationController,
            curve: Interval(
              (index * 0.05).clamp(0.0, 0.6),
              ((index * 0.05) + 0.4).clamp(0.0, 1.0),
              curve: Curves.easeOutCubic,
            ),
          );

          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.1),
                end: Offset.zero,
              ).animate(animation),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: appTheme.bgLight,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      isMe ? Border.all(color: prColor.withOpacity(0.5)) : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: _buildRankBadge(appTheme, entry.rank),
                    ),
                    const SizedBox(width: 12),
                    AvatarWidget(
                      imageUrl: entry.picture,
                      size: 40,
                      backgroundColor: appTheme.bgLight,
                      placeholder:
                          Icon(Icons.person, color: appTheme.text, size: 20),
                      rankPictureUrl: entry.rankPicture,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.displayName ?? 'Anonymous',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: appTheme.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      formatNumberWithCommas(entry.bestTas),
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: prColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: LeaderboardPeriod.values.map((period) {
              final isSelected = _selectedPeriod == period;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                    period.label,
                    style: AppFont.primaryTextStyle(
                      context,
                      color: isSelected ? appTheme.text : appTheme.textMuted,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected && _selectedPeriod != period) {
                      setState(() {
                        _selectedPeriod = period;
                        _entries.clear();
                        _currentPage = 1;
                        _hasMore = true;
                        _currentUser = null;
                        _isLoading = false;
                      });
                      _fetchLeaderboard();
                    }
                  },
                  backgroundColor: appTheme.bgLight,
                  selectedColor: prColor.withOpacity(0.2),
                  checkmarkColor: prColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? prColor
                          : appTheme.border.withOpacity(0.5),
                    ),
                  ),
                  showCheckmark: false,
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: content,
        ),
      ],
    );
  }
}
