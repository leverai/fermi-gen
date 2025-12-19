import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/screens/lobby/lobby_screen_controller.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/services/preload_service.dart';
import 'package:fermi_frontend/screens/main/widgets/primary_cta.dart';
import 'package:fermi_frontend/config/app_config.dart';
import 'package:fermi_frontend/widgets/player_widget.dart';
import 'package:fermi_frontend/widgets/selector_widget.dart';
import 'package:fermi_frontend/widgets/lock_toggle_chip.dart';
import 'package:fermi_frontend/widgets/categories/category_carousel_m3.dart';
import 'package:fermi_frontend/widgets/settings_menu.dart';
import 'package:fermi_frontend/widgets/styled_dialog.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:provider/provider.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/screens/main/widgets/daily_question_carousel.dart';

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
  // We keep _controller here for lifecycle management, but we will also provide it.

  // ... (existing state) ...

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

  void _showPartyBottomSheet(BuildContext context, AppTheme appTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: appTheme.bgLight,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            // Rebuild sheet when controller notifies
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final items = _categories();
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Party Settings',
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: appTheme.text,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        CategoryCarouselM3(
                          categories: items,
                          initialIndex: _controller.selectedCategoryIndex,
                          onCategorySelected: _controller.selectCategoryIndex,
                          onCenteredIndexChanged:
                              _controller.selectCategoryIndex,
                          startColor: HSLColor.fromColor(appTheme.primary),
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
                          selected: _controller.selectedDifficulty,
                          onChanged: (value) {
                            if (value == null ||
                                value == _controller.selectedDifficulty) {
                              _controller.selectDifficulty(null);
                            } else {
                              _controller.selectDifficulty(value);
                            }
                          },
                          allowNoSelection: true,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            LockToggleChip(
                              isLocked: _controller.isLocked,
                              onToggle: _controller.toggleLock,
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: PrimaryCta(
                                isLoading: _controller.isSubmitting,
                                onPressed: _onPrimaryAction,
                                isLocked: _controller.isLocked,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTopBar(AppTheme appTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            'assets/icons/llc_logo.svg',
            height: 24,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              width: 1,
              height: 24,
              color: appTheme.borderMuted,
            ),
          ),
          SvgPicture.asset(
            'assets/icons/logo-fg.svg',
            height: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildMeTab(AppTheme appTheme) {
    final user = widget.authService.currentUser;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: appTheme.bgLight,
                  border: Border.all(
                    color: appTheme.border,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: user?.picture != null
                      ? (user!.picture!.toLowerCase().endsWith('.svg')
                          ? Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: SvgPicture.network(
                                user.picture!,
                                fit: BoxFit.contain,
                                placeholderBuilder: (context) => Container(
                                  color: appTheme.bgLight,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              ),
                            )
                          : Image.network(
                              user.picture!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.person,
                                size: 64,
                                color: appTheme.borderMuted,
                              ),
                            ))
                      : Icon(
                          Icons.person,
                          size: 64,
                          color: appTheme.borderMuted,
                        ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            user?.displayName ?? 'Guest',
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              color: appTheme.text,
            ),
          ),
          const SizedBox(height: 8),
          if (widget.authService.isAnonymous)
            TextButton(
              onPressed: _handleCreateAccount,
              child: Text(
                'Create Account',
                style: TextStyle(color: appTheme.primary, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGamesTab(AppTheme appTheme) {
    return Column(
      children: [
        _buildTopBar(appTheme),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                vertical:
                    16.0), // Remove horizontal padding for carousel full width
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Hello, ${widget.authService.currentUser?.displayName ?? "Guest"}.',
                    textAlign: TextAlign.center,
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: appTheme.text,
                      height: 1.2,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Ready to Guesstimate?',
                    textAlign: TextAlign.center,
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: appTheme.borderMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Daily Question Carousel
                const DailyQuestionCarousel(),

                const SizedBox(height: 32),

                // Party Card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: InkWell(
                    onTap: () => _showPartyBottomSheet(context, appTheme),
                    borderRadius: BorderRadius.circular(appTheme.borderRadius),
                    child: Container(
                      decoration: BoxDecoration(
                        color: appTheme.bgLight,
                        borderRadius:
                            BorderRadius.circular(appTheme.borderRadius),
                        border: Border.all(
                          color: appTheme.border,
                          width: appTheme.borderWidth,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: appTheme.shadowColor,
                            offset: appTheme.shadowOffset,
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Party',
                                  style: AppFont.primaryTextStyle(
                                    context,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: appTheme.text,
                                  ),
                                ),
                                Text(
                                  'Play a 5-question round with friends.',
                                  style: AppFont.primaryTextStyle(
                                    context,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: appTheme.borderMuted,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Tap to play',
                                  style: AppFont.primaryTextStyle(
                                    context,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: appTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.grid_view_rounded,
                            size: 48,
                            color: appTheme.text,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Provide controllers here
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _controller),
      ],
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final AppTheme appTheme = Theme.of(context).extension<AppTheme>() ??
              AppTheme.defaultTheme();
          // ... rest of build logic
          // Note: using _controller directly inside AnimatedBuilder is fine as we also provided it.
          // BUT the rest of the build method uses _controller.
          // So we wrap the ENTIRE logic in MultiProvider.

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
            // ...
            return Theme(
              data: themed,
              child: const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (_controller.errorMessage != null) {
            // ...
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
                              ClipRect(child: _buildGamesTab(appTheme)),
                              ClipRect(child: _buildMeTab(appTheme)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // ... overlays ...
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
                  // Tutorial
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
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_filled),
                    label: 'Games',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person),
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
