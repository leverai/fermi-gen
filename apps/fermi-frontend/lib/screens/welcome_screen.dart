import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import 'package:fermi_frontend/widgets/responsive_container.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// Welcome screen shown to first-time users before the onboarding tutorial.
///
/// Features a sequential reveal of the logo, a storytelling carousel about
/// Enrico Fermi, and a "Get Started" button.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _carouselController;
  late final AnimationController _buttonController;

  late final Animation<Offset> _logoSlideAnimation;
  late final Animation<double> _logoFadeAnimation;
  late final Animation<double> _ctaFadeAnimation;

  late final Animation<double> _carouselFadeAnimation;
  late final Animation<double> _buttonFadeAnimation;

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  Timer? _windblowTimer;
  bool _startWindblow = false;

  Future<void> _getStarted(BuildContext context) async {
    // Mark welcome as seen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('welcome_seen', true);

    if (context.mounted) {
      // Refresh router to pick up the preference change
      GoRouter.of(context).refresh();
      context.go('/onboarding');
    }
  }

  @override
  void initState() {
    super.initState();

    // 0. Initialize controllers first
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _carouselController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 1. Setup Animations
    _logoSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeOutBack,
    ));

    _logoFadeAnimation = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeIn,
    );

    _ctaFadeAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    );

    _carouselFadeAnimation = CurvedAnimation(
      parent: _carouselController,
      curve: Curves.easeIn,
    );

    _buttonFadeAnimation = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeIn,
    );

    // Start Carousel
    _carouselController.forward();

    // Start windblow delay
    _startWindblowDelay();
  }

  void _startWindblowDelay() {
    _windblowTimer?.cancel();
    setState(() => _startWindblow = false);
    _windblowTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _startWindblow = true);
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Handle windblow animation delay for first slide
    if (index == 0) {
      _startWindblowDelay();
    } else {
      _windblowTimer?.cancel();
      setState(() => _startWindblow = false);
    }

    if (index == 2) {
      _startLateAnimationSequence();
    } else {
      // Reset animations when scrolling away so they play again when coming back
      _logoController.reset();
      _buttonController.reset();
    }
  }

  void _startLateAnimationSequence() async {
    // Only start if not already playing or completed
    if (_logoController.isAnimating || _logoController.isCompleted) return;

    // 1. Show "What about YOU?" + Icon first
    await _logoController.forward();

    // 2. Short delay before everything else
    await Future.delayed(const Duration(milliseconds: 400));

    // 3. Show Logo, Welcome Title, and Button together
    _buttonController.forward();
  }

  @override
  void dispose() {
    _windblowTimer?.cancel();
    _logoController.dispose();
    _carouselController.dispose();
    _buttonController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return ResponsiveContainer(
      backgroundColor: appTheme.bg,
      child: Scaffold(
        backgroundColor: appTheme.bg,
        body: SafeArea(
          child: Column(
            children: [
              // -- Phase 1: Full-screen Carousel --
              Expanded(
                child: FadeTransition(
                  opacity: _carouselFadeAnimation,
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    children: [
                      // Slide 1: Fermi's estimation
                      _buildFermiSlide(
                        appTheme: appTheme,
                        textSpan: TextSpan(
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: appTheme.text,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: 'Enrico Fermi',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: appTheme.primary,
                              ),
                            ),
                            const TextSpan(text: ' famously '),
                            TextSpan(
                              text: 'estimated',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: appTheme.primary,
                              ),
                            ),
                            const TextSpan(
                                text:
                                    " an explosion's power by observing flying pieces of paper!"),
                          ],
                        ),
                      ),
                      // Slide 2: Columbus comparison
                      _buildColumbusSlide(
                        appTheme: appTheme,
                        textSpan: TextSpan(
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: appTheme.text,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              text: 'Christopher Columbus',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: appTheme.primary,
                              ),
                            ),
                            const TextSpan(text: ', On the other hand, '),
                            TextSpan(
                              text: 'estimated',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: appTheme.primary,
                              ),
                            ),
                            const TextSpan(
                                text:
                                    ' that Asia was right around the corner!'),
                          ],
                        ),
                      ),
                      // Slide 3: Call to action with Logo
                      _buildWelcomeSlide(
                        appTheme: appTheme,
                        icon: Icons.psychology,
                        textSpan: TextSpan(
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: appTheme.text,
                            height: 1.4,
                          ),
                          children: [
                            const TextSpan(text: 'What about '),
                            TextSpan(
                              text: 'YOU',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: appTheme.primary,
                              ),
                            ),
                            const TextSpan(text: ' ?'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // -- Phase 2: Page Indicator --
              SmoothPageIndicator(
                controller: _pageController,
                count: 3,
                effect: WormEffect(
                  dotColor: appTheme.textMuted.withOpacity(0.3),
                  activeDotColor: appTheme.primary,
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 12,
                ),
              ),

              const SizedBox(height: 32),

              // -- Phase 3: Button (Only on last slide) --
              AnimatedOpacity(
                opacity: _currentIndex == 2 ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: IgnorePointer(
                  ignoring: _currentIndex != 2,
                  child: FadeTransition(
                    opacity: _buttonFadeAnimation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: SizedBox(
                        width: double.infinity,
                        child: MainButton(
                          onPressed: () => _getStarted(context),
                          label: MainButtonLabel.start,
                          customLabel: 'Get Started',
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the top section with consistent sizing for animations/logo.
  Widget _buildTopSection({required Widget child}) {
    return SizedBox(
      height: 200,
      width: double.infinity,
      child: Center(child: child),
    );
  }

  /// Builds slide 1: Fermi with top Windblow animation.
  Widget _buildFermiSlide({
    required AppTheme appTheme,
    required TextSpan textSpan,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _buildTopSection(
            child: Lottie.asset(
              'assets/lotties/Windblow.json',
              fit: BoxFit.contain,
              animate: _startWindblow,
            ),
          ),
          const Spacer(flex: 1),
          // Main content (avatar + text)
          Container(
            height: 100,
            width: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage('assets/icons/fermi.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),
          RichText(
            textAlign: TextAlign.center,
            text: textSpan,
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  /// Builds slide 2: Columbus with top compass animation.
  Widget _buildColumbusSlide({
    required AppTheme appTheme,
    required TextSpan textSpan,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _buildTopSection(
            child: Lottie.asset(
              'assets/lotties/boat steering.json',
              fit: BoxFit.contain,
              delegates: LottieDelegates(
                values: [
                  // Background white elements -> bgLight
                  ValueDelegate.color(
                    const ['**', 'Fill 1'],
                    value: appTheme.bgLight,
                  ),
                  // North needle (green) -> primary
                  ValueDelegate.color(
                    const ['Layer 6 Outlines', 'Group 1', '**'],
                    value: appTheme.primary,
                  ),
                  // South needle (red) -> secondary
                  ValueDelegate.color(
                    const ['Layer 6 Outlines', 'Group 2', '**'],
                    value: appTheme.secondary,
                  ),
                ],
              ),
            ),
          ),
          const Spacer(flex: 1),
          // Main content (avatar + text)
          Container(
            height: 100,
            width: 100,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: AssetImage('assets/icons/Colombus.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 24),
          RichText(
            textAlign: TextAlign.center,
            text: textSpan,
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  /// Builds slide 3: Logo, Welcome Text, Icon + Text.
  Widget _buildWelcomeSlide({
    required AppTheme appTheme,
    required IconData icon,
    required TextSpan textSpan,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(flex: 2),
          _buildTopSection(
            child: FadeTransition(
              opacity: _logoFadeAnimation,
              child: SlideTransition(
                position: _logoSlideAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: appTheme.bgLight,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(20),
                      child: SvgPicture.asset(
                        'assets/icons/logo-fg.svg',
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Welcome to Guesstimate!',
                      textAlign: TextAlign.center,
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: appTheme.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(flex: 1),
          FadeTransition(
            opacity: _ctaFadeAnimation,
            child: Column(
              children: [
                Icon(icon, size: 80, color: appTheme.primary),
                const SizedBox(height: 24),
                RichText(
                  textAlign: TextAlign.center,
                  text: textSpan,
                ),
              ],
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
