import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/subscription_service.dart';
import 'package:fermi_frontend/models/survival_models.dart';
import 'package:fermi_frontend/models/user_limits.dart';
import 'package:fermi_frontend/screens/paywall_screen.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/widgets/avatar_widget.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// Pre-Survival screen shown before starting or resuming a survival run.
///
/// Displays the user's current streak and provides a button to proceed.
/// Free users are limited to 2 runs per day.
class PreSurvivalScreen extends StatefulWidget {
  const PreSurvivalScreen({super.key});

  @override
  State<PreSurvivalScreen> createState() => _PreSurvivalScreenState();
}

class _PreSurvivalScreenState extends State<PreSurvivalScreen> {
  bool _isLoading = true;
  String? _error;
  StreakInfo? _streakInfo;
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
      // Fetch streaks and limits in parallel
      final results = await Future.wait([
        apiService.survivalGetStreakStats(),
        apiService.getUserLimitsTyped(),
      ]);
      if (mounted) {
        setState(() {
          _streakInfo = StreakInfo.fromJson(results[0] as Map<String, dynamic>);
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

  Future<void> _handleStart() async {
    final currentStreak = _streakInfo?.currentStreak ?? 0;
    final bestStreak = _streakInfo?.bestStreak ?? 0;

    if (mounted) {
      setState(() {
        _isReturning = true;
      });
    }

    await context.push(
      '/survival?currentStreak=$currentStreak&bestStreak=$bestStreak',
    );

    if (mounted) {
      _handleLeave();
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
          onAuthRequired: isAnonymous
              ? () {
                  // Navigate to auth flow if anonymous
                  context.go('/welcome');
                }
              : null,
        ),
      ),
    )
        .then((purchased) {
      if (purchased == true) {
        // Refresh limits after purchase
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
                  // Header with back button
                  Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: Icon(Icons.chevron_left,
                            color: appTheme.border, size: 32),
                        onPressed: _handleLeave,
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
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      children: [
                        _SurvivalPlayTab(
                          streakInfo: _streakInfo,
                          userLimits: _userLimits,
                          onStart: _handleStart,
                          onShowPaywall: _showPaywall,
                        ),
                        const _SurvivalLeaderboardTab(),
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

class _SurvivalPlayTab extends StatelessWidget {
  final StreakInfo? streakInfo;
  final UserLimits? userLimits;
  final VoidCallback onStart;
  final VoidCallback onShowPaywall;

  const _SurvivalPlayTab({
    required this.streakInfo,
    required this.userLimits,
    required this.onStart,
    required this.onShowPaywall,
  });

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final streak = streakInfo?.currentStreak ?? 0;
    final bestStreak = streakInfo?.bestStreak ?? 0;
    final bool isResume = streak > 0;
    final bool canPlay = isResume || (userLimits?.canPlaySurvival ?? true);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo / Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: appTheme.bgLight,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              child: SvgPicture.asset(
                'assets/icons/logo-fg.svg',
              ),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              'Survival Mode',
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
              'Beat the Average Player.\nReady?',
              textAlign: TextAlign.center,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: appTheme.textMuted,
                height: 1.4,
              ),
            ),

            // Subtitle / Streak Info
            if (bestStreak > 0) ...[
              const SizedBox(height: 24),
              Text.rich(
                TextSpan(
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: appTheme.textMuted,
                  ),
                  children: [
                    const TextSpan(text: 'Streak: '),
                    TextSpan(text: streak > 0 ? '$streak' : '_'),
                    const TextSpan(text: ' / '),
                    TextSpan(
                      text: '$bestStreak',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: appTheme.survival,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (bestStreak > 0) const SizedBox(height: 36),
            if (bestStreak <= 0) const SizedBox(height: 48),

            // Action Button
            SizedBox(
              width: 200,
              child: MainButton(
                onPressed: canPlay ? onStart : onShowPaywall,
                label: canPlay
                    ? (isResume
                        ? MainButtonLabel.resume
                        : MainButtonLabel.start)
                    : null,
                customLabel: canPlay ? null : 'Get Unlimited',
              ),
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

class _SurvivalLeaderboardTab extends StatefulWidget {
  const _SurvivalLeaderboardTab();

  @override
  State<_SurvivalLeaderboardTab> createState() =>
      _SurvivalLeaderboardTabState();
}

class _SurvivalLeaderboardTabState extends State<_SurvivalLeaderboardTab> {
  final _scrollController = ScrollController();
  final List<LeaderboardEntry> _entries = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;
  LeaderboardEntry? _currentUser;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
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
      final response = await apiService.survivalGetLeaderboard(
        page: _currentPage,
        pageSize: 25,
      );

      if (mounted) {
        setState(() {
          _entries.addAll(response.entries);
          _currentUser = response.currentUser;
          _hasMore = _currentPage < response.totalPages;
          _currentPage++;
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

    if (_entries.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _entries.isEmpty) {
      return Center(
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
    }

    if (_entries.isEmpty) {
      return Center(
        child: Text(
          'No records yet. Be the first!',
          style: AppFont.primaryTextStyle(context, color: appTheme.textMuted),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
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
                  _currentUser!.bestStreak ==
                      entry
                          .bestStreak; // Rank can be shared, so this check is weak but sufficient for display highlights if needed. Actually backend handles "isMe" typically but here we rely on the currentUser object.
              // A better check for "isMe" would be user ID but we don't have it in the leaderboard entry.
              // For now, let's just highlight the currentUser section at the bottom.

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: appTheme.bgLight,
                  borderRadius: BorderRadius.circular(12),
                  border: isMe
                      ? Border.all(color: appTheme.survival.withOpacity(0.5))
                      : null,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${entry.bestStreak}',
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: appTheme.survival,
                          ),
                        ),
                        if (!entry.isCompleted)
                          Text(
                            'ACTIVE',
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: appTheme.success,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_currentUser != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: appTheme.bgLight,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              // This mimics the list item structure
              children: [
                SizedBox(
                  width: 40,
                  child: _buildRankBadge(appTheme, _currentUser!.rank),
                ),
                const SizedBox(width: 12),
                AvatarWidget(
                  imageUrl: _currentUser!.picture,
                  size: 40,
                  backgroundColor: appTheme.bgLight,
                  placeholder:
                      Icon(Icons.person, color: appTheme.text, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You',
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: appTheme.text,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${_currentUser!.bestStreak}',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: appTheme.survival,
                      ),
                    ),
                    if (!_currentUser!.isCompleted)
                      Text(
                        'ACTIVE',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: appTheme.success,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
