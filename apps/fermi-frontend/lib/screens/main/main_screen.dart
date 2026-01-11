import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/screens/lobby/lobby_screen_controller.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/services/preload_service.dart';
import 'package:fermi_frontend/config/app_config.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/screens/main/widgets/settings_sheet.dart';
import 'package:fermi_frontend/widgets/styled_dialog.dart';
import 'package:fermi_frontend/widgets/avatar_widget.dart';
import 'package:fermi_frontend/screens/paywall_screen.dart';
import 'package:fermi_frontend/services/subscription_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:provider/provider.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/screens/main/widgets/me_tab.dart';
import 'package:fermi_frontend/screens/main/widgets/games_tab.dart';
import 'package:fermi_frontend/screens/main/widgets/party_bottom_sheet.dart';
import 'package:fermi_frontend/screens/main/widgets/profile_sheet.dart';
import 'package:fermi_frontend/screens/main/ranks/ranks_screen.dart';

import 'package:fermi_frontend/widgets/responsive_container.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.apiService,
    required this.authService,
    this.preloadService,
    required this.dailyQuestionService,
  });

  final ApiService apiService;
  final AuthService authService;
  final PreloadService? preloadService;
  final DailyQuestionService dailyQuestionService;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late final MainScreenController _controller;

  DateTime? _lastResumeTime;
  int _currentIndex = 0; // 0 = Games, 1 = Me
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MainScreenController(
      api: widget.apiService,
      auth: widget.authService,
    );
    _controller.initialize(
      preloadedConfig: widget.preloadService?.cachedConfig,
      preloadedUserLimits: widget.preloadService?.cachedUserLimits,
      preloadedStats: widget.preloadService?.cachedStats,
    );
    _pageController = PageController(initialPage: _currentIndex);

    // Check if we need to refresh stats (set by DQ or Party game screens)
    // This must be in a post-frame callback so the controller is fully initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.authService.shouldRefreshStats) {
        widget.authService.shouldRefreshStats = false;
        _controller.refreshInBackground();
        // Also refresh DQ data
        context.read<DailyQuestionController>().refreshArchiveAndSubscribe();
      } else if (mounted) {
        // Trigger DQ load after first frame if not refreshing
        context.read<DailyQuestionController>().refreshArchiveAndSubscribe();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      if (_lastResumeTime == null ||
          now.difference(_lastResumeTime!).inSeconds > 2) {
        _lastResumeTime = now;
        _controller.refreshInBackground();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // Navigation Handlers
  // --------------------------------------------------------------------------

  void _onBottomNavTapped(int index) {
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
  }

  // --------------------------------------------------------------------------
  // Game Action Handlers
  // --------------------------------------------------------------------------

  Future<void> _onPrimaryAction() async {
    try {
      await _createGame();
    } catch (_) {
      // errors surfaced elsewhere
    }
  }

  Future<void> _createGame() async {
    try {
      final String gameId = await _controller.createGame(
          nQuestions: AppConfig.defaultQuestionCount);
      if (!mounted) return;
      Navigator.of(context)
          .push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LobbyScreenController(
            gameId: gameId,
            realtime: _controller.buildRealtimeAdapter(),
            api: widget.apiService,
            initialPlayers: [
              PlayerState(
                isHost: true,
                status: PlayerStatus.none,
                avatarUrl: widget.authService.currentUser?.picture,
                displayName: widget.authService.currentUser?.displayName,
              ),
            ],
          ),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: child,
            );
          },
        ),
      )
          .then((_) {
        // Refresh user limits when returning from Party game
        // (hosting count may have changed)
        if (mounted) {
          _controller.refreshUserLimits();
          context.read<DailyQuestionController>().refreshArchiveAndSubscribe();
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  // --------------------------------------------------------------------------
  // Settings Handlers
  // --------------------------------------------------------------------------

  void _toggleSettings() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SettingsSheet(
        onSignOut: _handleSignOut,
        onDeleteAccount: _handleDeleteAccount,
        isAnonymous: widget.authService.isAnonymous,
        onCreateAccount: _handleCreateAccount,
        email: widget.authService.currentUser?.email,
        currentLocale: widget.authService.locale,
        onLocaleChanged: _handleLocaleChanged,
        subscriptionTier:
            widget.authService.currentUser?.subscriptionTier ?? 'FREE',
        onUpgradeSubscription: _handleUpgradeSubscription,
      ),
    );
  }

  void _handleUpgradeSubscription() {
    final subscriptionService = context.read<SubscriptionService>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          subscriptionService: subscriptionService,
          isAnonymous: widget.authService.isAnonymous,
          onAuthRequired: () {
            Navigator.of(context).pop(); // Close paywall
            context.push('/upgrade-account');
          },
        ),
      ),
    );
  }

  Future<void> _handleLocaleChanged(String newLocale) async {
    try {
      await widget.apiService.setUserLocale(locale: newLocale);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update locale: $e')),
        );
      }
    }
  }

  Future<void> _handleSignOut() async {
    // Clear preload cache to prevent stale stats for next user
    widget.preloadService?.clearCache();
    await widget.authService.signOut();
    if (!mounted) return;
    context.go('/sign-in');
  }

  void _handleCreateAccount() {
    context.push('/upgrade-account');
  }

  Future<void> _handleDeleteAccount() async {
    if (widget.authService.isAnonymous) return;

    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => StyledDialog(
        message: 'Delete Account?',
        secondaryMessage: 'This action cannot be undone.',
        primaryButtonLabel: 'Delete',
        primaryButtonColor: appTheme.danger,
        onPrimaryPressed: () => Navigator.of(context).pop(true),
        secondaryButtonLabel: 'Cancel',
        onSecondaryPressed: () => Navigator.of(context).pop(false),
        showAsDialog: true,
      ),
    );

    if (confirm == true) {
      try {
        // Clear preload cache to prevent stale stats for next user
        widget.preloadService?.clearCache();
        await widget.authService.deleteAccount();
        if (!mounted) return;
        context.go('/sign-in');
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting account: $e')),
        );
      }
    }
  }

  void _handleEditProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileSheet(
        apiService: widget.apiService,
        currentDisplayName: widget.authService.currentUser?.displayName,
        currentAvatarUrl: widget.authService.currentUser?.picture,
        onSave: (displayName, avatarUrl) async {
          // Refresh user data to update the UI
          await widget.authService.refreshAccessToken();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Build Helpers
  // --------------------------------------------------------------------------

  Widget _buildMeIcon(AppTheme appTheme) {
    final user = widget.authService.currentUser;
    if (user?.picture == null) {
      return const Icon(Icons.person);
    }

    return AvatarWidget(
      imageUrl: user!.picture,
      size: 24,
    );
  }

  // --------------------------------------------------------------------------
  // Build Method
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _controller),
      ],
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final AppTheme appTheme = Theme.of(context).extension<AppTheme>() ??
              AppTheme.defaultTheme();

          final ThemeData themed = Theme.of(context).copyWith(
            scaffoldBackgroundColor: appTheme.bgDark,
            appBarTheme: AppBarTheme(
              backgroundColor: appTheme.bgDark,
              foregroundColor: appTheme.text,
              elevation: 0,
            ),
            extensions: <ThemeExtension<dynamic>>[
              const AppFont(),
              appTheme,
            ],
          );

          if (_controller.isLoading) {
            return Theme(
              data: themed,
              child: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (_controller.errorMessage != null) {
            return Theme(
              data: themed,
              child: Scaffold(
                body: Center(child: Text(_controller.errorMessage!)),
              ),
            );
          }

          return AnimatedTheme(
            data: themed,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOutCubic,
            child: ResponsiveContainer(
              backgroundColor: appTheme.bgDark,
              safeAreaBottom:
                  false, // BottomNavigationBar handles bottom safe area
              child: Scaffold(
                body: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            onPageChanged: _onPageChanged,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              ClipRect(
                                child: GamesTab(
                                  displayName: widget
                                      .authService.currentUser?.displayName,
                                  onPartyCardTapped: () => showPartyBottomSheet(
                                    context: context,
                                    controller: _controller,
                                    onPrimaryAction: _onPrimaryAction,
                                    isAnonymous: widget.authService.isAnonymous,
                                    onAuthRequired: () {
                                      Navigator.of(context)
                                          .pop(); // Close paywall
                                      Navigator.of(context)
                                          .pop(); // Close party sheet
                                      context.push('/upgrade-account');
                                    },
                                  ),
                                ),
                              ),
                              ClipRect(
                                child: MeTab(
                                  avatarUrl:
                                      widget.authService.currentUser?.picture,
                                  displayName: widget
                                      .authService.currentUser?.displayName,
                                  isAnonymous: widget.authService.isAnonymous,
                                  onCreateAccount: _handleCreateAccount,
                                  onEditProfile: _handleEditProfile,
                                  playerStats:
                                      _controller.playerStatsDto?.stats,
                                  onStatsTapped: () {
                                    final stats =
                                        _controller.playerStatsDto?.stats;
                                    final ranks =
                                        _controller.configDto?.ranks ?? [];
                                    if (stats != null && ranks.isNotEmpty) {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => RanksScreen(
                                            playerStats: stats,
                                            ranks: ranks,
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Settings FAB
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          onPressed: _toggleSettings,
                          splashColor: Colors.transparent,
                          highlightColor: appTheme.borderMuted,
                          icon: SvgPicture.asset(
                            'assets/icons/gear.svg',
                            colorFilter: ColorFilter.mode(
                                appTheme.border, BlendMode.srcIn),
                            width: 36,
                            height: 36,
                          ),
                        ),
                      ),
                    ),
                    // Tutorial button
                    Positioned(
                      top: 8,
                      right: 8,
                      child: SafeArea(
                        child: Opacity(
                          opacity: 0.5,
                          child: IconButton(
                            icon: Icon(Icons.help_outline, color: appTheme.bg),
                            tooltip: 'Launch Onboarding Tutorial',
                            onPressed: () {
                              context.push('/onboarding');
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                bottomNavigationBar: BottomNavigationBar(
                  currentIndex: _currentIndex,
                  onTap: _onBottomNavTapped,
                  backgroundColor: appTheme.bg,
                  selectedItemColor: appTheme.text,
                  unselectedItemColor: appTheme.textMuted,
                  showSelectedLabels: true,
                  showUnselectedLabels: true,
                  items: [
                    const BottomNavigationBarItem(
                      icon: Icon(Icons.home_filled),
                      label: 'Games',
                    ),
                    BottomNavigationBarItem(
                      icon: _buildMeIcon(appTheme),
                      label: 'Me',
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
