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

    final streak = _streakInfo?.currentStreak ?? 0;
    final bestStreak = _streakInfo?.bestStreak ?? 0;
    final bool isResume = streak > 0;

    // Check if user can play (has runs remaining or is resuming)
    // Resuming an existing run doesn't count against the limit
    final bool canPlay = isResume || (_userLimits?.canPlaySurvival ?? true);

    return ResponsiveContainer(
      backgroundColor: appTheme.bg,
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

                // Main Content
                Expanded(
                  child: Center(
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
                          // const SizedBox(height: 48),

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
                              onPressed: canPlay ? _handleStart : _showPaywall,
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
                            'One mistake and it\'s over!',
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: appTheme.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '40 Seconds each • Precision counts',
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
