import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/models/survival_models.dart';
import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// Pre-Survival screen shown before starting or resuming a survival run.
///
/// Displays the user's current streak and provides a button to proceed.
class PreSurvivalScreen extends StatefulWidget {
  const PreSurvivalScreen({super.key});

  @override
  State<PreSurvivalScreen> createState() => _PreSurvivalScreenState();
}

class _PreSurvivalScreenState extends State<PreSurvivalScreen> {
  bool _isLoading = true;
  String? _error;
  StreakInfo? _streakInfo;

  @override
  void initState() {
    super.initState();
    _fetchStreaks();
  }

  Future<void> _fetchStreaks() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final result = await apiService.survivalGetStreakStats();
      if (mounted) {
        setState(() {
          _streakInfo = StreakInfo.fromJson(result);
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

  void _handleStart() {
    final currentStreak = _streakInfo?.currentStreak ?? 0;
    final bestStreak = _streakInfo?.bestStreak ?? 0;
    context.pushReplacement(
      '/survival?currentStreak=$currentStreak&bestStreak=$bestStreak',
    );
  }

  void _handleLeave() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/main');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    if (_isLoading) {
      return ResponsiveContainer(
        backgroundColor: appTheme.bg,
        child: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
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
                  onPressed: _fetchStreaks,
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
                          const SizedBox(height: 12),

                          // Subtitle / Streak Info
                          Text(
                            isResume
                                ? 'Current Streak: $streak\nReady to keep going?'
                                : 'How long can you survive?\nBuild your streak.',
                            textAlign: TextAlign.center,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 20,
                              fontWeight: FontWeight.w400,
                              color: appTheme.textMuted,
                              height: 1.4,
                            ),
                          ),
                          if (bestStreak > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Best Streak: $bestStreak',
                              style: AppFont.primaryTextStyle(
                                context,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: appTheme.warning,
                              ),
                            ),
                          ],
                          const SizedBox(height: 48),

                          // Action Button
                          SizedBox(
                            width: 200,
                            child: MainButton(
                              onPressed: _handleStart,
                              label: isResume
                                  ? MainButtonLabel.resume
                                  : MainButtonLabel.start,
                            ),
                          ),
                          const SizedBox(height: 40),

                          // Descriptive Footer
                          Text(
                            'One mistake and it\'s over.',
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: appTheme.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Timed questions • Precision counts',
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
