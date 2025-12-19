import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/screens/lobby/lobby_screen_controller.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/services/preload_service.dart';
import 'package:fermi_frontend/config/app_config.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/settings_menu.dart';
import 'package:fermi_frontend/widgets/styled_dialog.dart';
import 'package:fermi_frontend/widgets/avatar_widget.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:provider/provider.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/screens/main/widgets/me_tab.dart';
import 'package:fermi_frontend/screens/main/widgets/games_tab.dart';
import 'package:fermi_frontend/screens/main/widgets/party_bottom_sheet.dart';
import 'package:fermi_frontend/screens/main/widgets/profile_sheet.dart';

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
  bool _isSettingsOpen = false;
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
      preloadedStats: widget.preloadService?.cachedStats,
    );
    _pageController = PageController(initialPage: _currentIndex);

    // Trigger DQ load after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.authService.shouldRefreshStats) {
      widget.authService.shouldRefreshStats = false;
      _controller.refreshInBackground();
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
      if (_controller.isLocked) {
        await _createGame();
      } else {
        await _joinRandomGame();
      }
    } catch (_) {
      // errors surfaced elsewhere
    }
  }

  Future<void> _createGame() async {
    try {
      final String gameId = await _controller.createGame(
          nQuestions: AppConfig.defaultQuestionCount);
      if (!mounted) return;
      Navigator.of(context).push(
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
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _joinRandomGame() async {
    try {
      final String gameId = await _controller.joinRandomGame(
          nQuestions: AppConfig.defaultQuestionCount);
      if (!mounted) return;
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LobbyScreenController(
            gameId: gameId,
            realtime: _controller.buildRealtimeAdapter(),
            api: widget.apiService,
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
      );
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
    setState(() {
      _isSettingsOpen = !_isSettingsOpen;
    });
  }

  Future<void> _handleSignOut() async {
    _toggleSettings();
    await widget.authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/sign-in');
  }

  void _handleCreateAccount() {
    _toggleSettings();
    Navigator.of(context).pushNamed('/upgrade-account');
  }

  Future<void> _handleDeleteAccount() async {
    if (widget.authService.isAnonymous) return;

    _toggleSettings();
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
        await widget.authService.deleteAccount();
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/sign-in');
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
            child: Scaffold(
              body: Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        child: SafeArea(
                          bottom: false,
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
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Settings FAB
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: FloatingActionButton(
                      onPressed: _toggleSettings,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      shape: const CircleBorder(),
                      child: SvgPicture.asset(
                        'assets/icons/gear.svg',
                        colorFilter:
                            ColorFilter.mode(appTheme.text, BlendMode.srcIn),
                        width: 36,
                        height: 36,
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
                          icon: Icon(Icons.help_outline,
                              color: appTheme.borderMuted),
                          tooltip: 'Launch Onboarding Tutorial',
                          onPressed: () {
                            Navigator.of(context).pushNamed('/onboarding');
                          },
                        ),
                      ),
                    ),
                  ),
                  // Settings menu overlay
                  if (_isSettingsOpen)
                    Positioned.fill(
                      child: SettingsMenu(
                        onSignOut: _handleSignOut,
                        onDeleteAccount: _handleDeleteAccount,
                        onClose: _toggleSettings,
                        isAnonymous: widget.authService.isAnonymous,
                        onCreateAccount: _handleCreateAccount,
                      ),
                    ),
                ],
              ),
              bottomNavigationBar: BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _onBottomNavTapped,
                backgroundColor: appTheme.bg,
                selectedItemColor: appTheme.text,
                unselectedItemColor: appTheme.borderMuted,
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
          );
        },
      ),
    );
  }
}
