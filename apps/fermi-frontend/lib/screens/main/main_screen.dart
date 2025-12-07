import 'package:fermi_frontend/widgets/percentile_widget.dart';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/screens/lobby/lobby_screen_controller.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/services/preload_service.dart';
import 'package:fermi_frontend/screens/main/widgets/top_bar_lock_avatar.dart';
import 'package:fermi_frontend/screens/main/widgets/primary_cta.dart';
import 'package:fermi_frontend/config/app_config.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/selector_widget.dart';
import 'package:fermi_frontend/widgets/lock_toggle_chip.dart';
import 'package:fermi_frontend/widgets/categories/category_carousel_m3.dart';
import 'package:fermi_frontend/widgets/settings_menu.dart';
import 'package:fermi_frontend/widgets/styled_dialog.dart';
import 'package:flutter_svg/flutter_svg.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    required this.apiService,
    required this.authService,
    this.preloadService,
  });

  final ApiService apiService;
  final AuthService authService;
  final PreloadService? preloadService;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late final MainScreenController _controller;
  DateTime? _lastResumeTime;
  bool _isSettingsOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = MainScreenController(
      api: widget.apiService,
      auth: widget.authService,
    );
    // Initialize with preloaded data if available
    _controller.initialize(
      preloadedConfig: widget.preloadService?.cachedConfig,
      preloadedStats: widget.preloadService?.cachedStats,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Debounce: only refresh if it's been more than 2 seconds since last resume
      final now = DateTime.now();
      if (_lastResumeTime == null ||
          now.difference(_lastResumeTime!).inSeconds > 2) {
        _lastResumeTime = now;
        // Refresh data in background without blocking UI
        _controller.refreshInBackground();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.authService.shouldRefreshStats) {
      widget.authService.shouldRefreshStats = false;
      // Use non-blocking refresh instead of initialize
      _controller.refreshInBackground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  List<CategoryItemM3> _categories() {
    final cfg = _controller.configDto;
    if (cfg == null) return const <CategoryItemM3>[];
    return cfg.categories
        .map((c) => CategoryItemM3(
              id: c.index.toString(),
              title: c.slug,
              svgPath: c.picture,
            ))
        .toList(growable: false);
  }

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

  void _toggleSettings() {
    setState(() {
      _isSettingsOpen = !_isSettingsOpen;
    });
  }

  Future<void> _handleSignOut() async {
    _toggleSettings();
    await widget.authService.signOut();
    if (!mounted) return;
    // After sign out, app will automatically sign in anonymously on next launch
    Navigator.of(context).pushReplacementNamed('/sign-in');
  }

  void _handleCreateAccount() {
    _toggleSettings();
    Navigator.of(context).pushNamed('/upgrade-account');
  }

  Future<void> _handleDeleteAccount() async {
    // Anonymous users cannot delete accounts (handled by service, but check here too)
    if (widget.authService.isAnonymous) {
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final items = _categories();
        final AppTheme appTheme =
            Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

        final ThemeData themed = Theme.of(context).copyWith(
          scaffoldBackgroundColor: appTheme.bgDark,
          appBarTheme: AppBarTheme(
            backgroundColor: appTheme.bgDark,
            foregroundColor: appTheme.text,
            elevation: 0,
          ),
          extensions: <ThemeExtension<dynamic>>[
            const AppFont(), // Use default fonts (Barlow & Jura)
            appTheme,
          ],
        );

        if (_controller.isLoading) {
          return Theme(
            data: themed,
            child: const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (_controller.errorMessage != null) {
          return Theme(
            data: themed,
            child: Scaffold(
              body: Center(
                child: Text(_controller.errorMessage!),
              ),
            ),
          );
        }

        return AnimatedTheme(
          data: themed,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          child: Scaffold(
            body: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [appTheme.bg, appTheme.bg, appTheme.bgDark],
                  stops: const [0.0, 0.8, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(
                          left: 12, right: 12, top: 0, bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TopBarLockAvatar(
                            avatarUrl: widget.authService.currentUser?.picture,
                            displayName:
                                widget.authService.currentUser?.displayName,
                          ),
                          const Spacer(),
                          Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: appTheme.bgLight,
                                  border: Border.all(
                                    color: appTheme.border,
                                    width: appTheme.borderWidth,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                      appTheme.borderRadius),
                                  boxShadow: [
                                    BoxShadow(
                                      color: appTheme.shadowColor,
                                      offset: appTheme.shadowOffset,
                                      blurRadius: 0,
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 24.0,
                                      right: 24.0,
                                      top: 12.0,
                                      bottom: 24.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Party',
                                            style: AppFont.primaryTextStyle(
                                              context,
                                              fontSize: 48,
                                              fontWeight: FontWeight.w600,
                                              color: appTheme.text,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Multiplayer round of 5 questions.',
                                            style: AppFont.primaryTextStyle(
                                              context,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w300,
                                              color: appTheme.border,
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: appTheme.border
                                                // ignore: deprecated_member_use
                                                .withOpacity(0.3),
                                          ),
                                        ],
                                      ),
                                      CategoryCarouselM3(
                                        categories: items,
                                        initialIndex:
                                            _controller.selectedCategoryIndex,
                                        onCategorySelected:
                                            _controller.selectCategoryIndex,
                                        onCenteredIndexChanged:
                                            _controller.selectCategoryIndex,
                                        startColor: HSLColor.fromColor(
                                            appTheme.primary),
                                      ),
                                      const SizedBox(height: 0),
                                      SelectorWidget(
                                        options: _controller.difficulties
                                            .map((d) => SelectorOption(
                                                  label: d.slug,
                                                  value: d.name,
                                                  iconUrl: d.picture,
                                                ))
                                            .toList(),
                                        selected:
                                            _controller.selectedDifficulty,
                                        onChanged: (value) {
                                          if (value == null ||
                                              value ==
                                                  _controller
                                                      .selectedDifficulty) {
                                            _controller.selectDifficulty(null);
                                          } else {
                                            _controller.selectDifficulty(value);
                                          }
                                        },
                                        allowNoSelection: true,
                                      ),
                                      const SizedBox(height: 24),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          LockToggleChip(
                                            isLocked: _controller.isLocked,
                                            onToggle: _controller.toggleLock,
                                          ),
                                          const SizedBox(width: 24),
                                          Expanded(
                                            child: PrimaryCta(
                                              isLoading:
                                                  _controller.isSubmitting,
                                              onPressed: _onPrimaryAction,
                                              isLocked: _controller.isLocked,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 20,
                                right: 24,
                                child: PercentileWidget(
                                  percentile:
                                      _controller.resolvedPercentile == 0
                                          ? null
                                          : _controller.resolvedPercentile,
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: FloatingActionButton(
                                  onPressed: _toggleSettings,
                                  backgroundColor: Colors.transparent,
                                  elevation: 0,
                                  hoverElevation: 0,
                                  focusElevation: 0,
                                  highlightElevation: 0,
                                  shape: const CircleBorder(),
                                  child: SvgPicture.asset(
                                    'assets/icons/gear.svg',
                                    colorFilter: ColorFilter.mode(
                                        appTheme.border, BlendMode.srcIn),
                                    width: 72,
                                    height: 72,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Debug button to launch onboarding tutorial
                  Positioned(
                    top: 8,
                    right: 8,
                    child: SafeArea(
                      child: Opacity(
                        opacity: 0.2,
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
                  // Settings Menu Overlay
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
            ),
          ),
        );
      },
    );
  }
}
