// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/providers/subscription_provider.dart';
import 'package:fermi_frontend/services/subscription_service.dart';
import 'package:fermi_frontend/services/feedback_service.dart';
import 'package:fermi_frontend/services/ad_service.dart';
import 'package:fermi_frontend/screens/paywall_screen.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/screens/daily_question/daily_question_screen.dart';

/// Pre-Daily Question screen shown before starting an active DQ.
///
/// Displays the date and duration information, and provides a "Start" button
/// to proceed to the actual DQ screen. This prepares users before they begin
/// the timed question.
///
/// When the user taps Start, a 3-second countdown begins showing "Starting in X"
/// on the button. When the countdown completes, the user is navigated to the
/// DQ screen. The back/leave button cancels the countdown.
class PreDailyQuestionScreen extends StatefulWidget {
  /// The DQ date in YYYY-MM-DD format.
  final String questionDate;

  /// Whether this screen was reached via an invite link.
  /// If true, back/leave button navigates to main screen.
  /// If false, back/leave button uses Navigator.pop().
  final bool fromInvite;

  /// Whether this is a post-take (taking an older closed DQ).
  /// If true, uses post-take API endpoints.
  final bool isPostTake;

  const PreDailyQuestionScreen({
    super.key,
    required this.questionDate,
    this.fromInvite = false,
    this.isPostTake = false,
  });

  @override
  State<PreDailyQuestionScreen> createState() => _PreDailyQuestionScreenState();
}

class _PreDailyQuestionScreenState extends State<PreDailyQuestionScreen> {
  /// Countdown seconds remaining. null = not in countdown state.
  int? _countdownSeconds;

  /// Timer for the countdown.
  Timer? _countdownTimer;

  /// Whether user accessed via watching an ad (bypasses Pro check).
  bool _accessedWithAd = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _handleLeave(BuildContext context) {
    // Cancel any active countdown
    _cancelCountdown();

    if (widget.fromInvite) {
      // From invite link - go to main screen
      context.go('/main');
    } else {
      // From push navigation - pop back
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        context.go('/main');
      }
    }
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (_countdownSeconds != null) {
      setState(() {
        _countdownSeconds = null;
      });
    }
  }

  void _handleStart() {
    // Feature gating: post-take requires Pro subscription (unless accessed via ad)
    if (widget.isPostTake && !_accessedWithAd) {
      final subscriptionProvider = context.read<SubscriptionProvider>();
      if (!subscriptionProvider.isPro) {
        _showPaywall();
        return;
      }
    }

    // Start the countdown
    setState(() {
      _countdownSeconds = 3;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _countdownSeconds = _countdownSeconds! - 1;
      });

      if (_countdownSeconds! <= 0) {
        timer.cancel();
        _navigateToDailyQuestion();
      }
    });
  }

  void _showPaywall() {
    final subscriptionService = context.read<SubscriptionService>();
    final isAnonymous = FirebaseAuth.instance.currentUser?.isAnonymous ?? false;
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          subscriptionService: subscriptionService,
          isAnonymous: isAnonymous,
          onAuthRequired: () {
            Navigator.of(context).pop(); // Close paywall
            context.push('/upgrade-account');
          },
        ),
      ),
    )
        .then((purchased) {
      if (!mounted) return;
      if (purchased == true) {
        // Refresh subscription state after successful purchase
        context.read<SubscriptionProvider>().refresh();
      }
    });
  }

  /// Handle watch ad button: show rewarded ad and start post-take on completion.
  void _handleWatchAd() {
    final adService = AdService.instance;
    if (!adService.isAdLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad not ready. Please try again.')),
      );
      // Try to load ad for next time
      adService.loadRewardedAd();
      return;
    }

    adService.showRewardedAd(
      onComplete: () {
        if (!mounted) return;
        // Ad completed - mark as ad-access and start countdown
        setState(() {
          _accessedWithAd = true;
        });
        _handleStart();
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

  void _navigateToDailyQuestion() {
    if (!mounted) return;

    if (widget.fromInvite) {
      // For go_router managed pages, we can't use pushReplacement (page-based
      // routes don't support imperative replacement). Instead, push DQ on top.
      // When user leaves DQ, DailyQuestionScreen._navigateToMain() calls
      // context.go('/main') which clears the entire stack properly.
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => DailyQuestionScreen(
            questionDate: widget.questionDate,
            isPostTake: widget.isPostTake,
            withAd: _accessedWithAd,
          ),
        ),
      );
    } else {
      // For Navigator-pushed routes, pushReplacement removes pre-DQ from stack
      // so back navigation goes to main, not pre-DQ.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => DailyQuestionScreen(
            questionDate: widget.questionDate,
            isPostTake: widget.isPostTake,
            withAd: _accessedWithAd,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    // Parse the date
    final date = DateTime.parse(widget.questionDate);
    final dateFormat = DateFormat('MMMM d, yyyy');
    final formattedDate = dateFormat.format(date);

    final bool isCountingDown = _countdownSeconds != null;

    return ResponsiveContainer(
      backgroundColor: appTheme.bg,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
          _handleLeave(context);
        },
        child: Scaffold(
          backgroundColor: appTheme.bg,
          body: SafeArea(
            child: Column(
              children: [
                // Minimal Header
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: IconButton(
                      icon: Icon(Icons.chevron_left,
                          color: appTheme.border, size: 32),
                      onPressed: () {
                        FeedbackService.instance.secondaryClick();
                        _handleLeave(context);
                      },
                      tooltip: 'Leave',
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
                            'The Daily Guess',
                            textAlign: TextAlign.center,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: appTheme.text,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Subtitle
                          Text(
                            'Put your thinking hat on.\nReady?',
                            textAlign: TextAlign.center,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: appTheme.textMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Start button with optional lock icon for gated post-take
                          Consumer<SubscriptionProvider>(
                            builder: (context, subProvider, _) {
                              final bool isGated =
                                  widget.isPostTake && !subProvider.isPro;

                              // If counting down, just show countdown button
                              if (isCountingDown) {
                                return SizedBox(
                                  width: 200,
                                  child: MainButton(
                                    onPressed: null,
                                    customLabel:
                                        'Starting in $_countdownSeconds',
                                  ),
                                );
                              }

                              // For gated FREE users: Lock + Go PRO + or + Watch Ad 🎬
                              if (isGated) {
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // Go PRO button
                                    SizedBox(
                                      width: 130,
                                      child: MainButton(
                                        onPressed: _showPaywall,
                                        customLabel: 'Go PRO',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // "or" text
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
                                    // Watch Ad 🎬 button
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
                                );
                              }

                              // For PRO users or non-gated: simple Start button
                              return SizedBox(
                                width: 200,
                                child: MainButton(
                                  onPressed: _handleStart,
                                  label: MainButtonLabel.start,
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 40),

                          // Date info
                          Text(
                            formattedDate,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: appTheme.text,
                            ),
                          ),
                          const SizedBox(height: 4),

                          // Credits
                          Text(
                            'By Guesstimate Team • 30 seconds',
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
