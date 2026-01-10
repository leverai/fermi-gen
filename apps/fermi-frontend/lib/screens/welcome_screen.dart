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

  late final Animation<double> _carouselFadeAnimation;
  late final Animation<double> _buttonFadeAnimation;

  final PageController _pageController = PageController();

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

    // 1. Logo Animation (0ms - 800ms)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOutBack,
    ));

    _logoFadeAnimation = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeIn,
    );

    // 2. Carousel Animation (Starts after logo, ~800ms - 1600ms)
    _carouselController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _carouselFadeAnimation = CurvedAnimation(
      parent: _carouselController,
      curve: Curves.easeIn,
    );

    // 3. Button Animation (Starts after carousel, ~1600ms - 2000ms)
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _buttonFadeAnimation = CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeIn,
    );

    // Start Sequence
    _startAnimationSequence();
  }

  void _startAnimationSequence() async {
    await _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    await _carouselController.forward();
    await Future.delayed(const Duration(milliseconds: 200));
    _buttonController.forward();
  }

  @override
  void dispose() {
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),

                // -- Phase 1: Logo & Title --
                FadeTransition(
                  opacity: _logoFadeAnimation,
                  child: SlideTransition(
                    position: _logoSlideAnimation,
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: appTheme.bgLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.all(20),
                          child: SvgPicture.asset(
                            'assets/icons/logo-fg.svg',
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Welcome to Guesstimate!',
                          textAlign: TextAlign.center,
                          style: AppFont.primaryTextStyle(
                            context,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: appTheme.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 1),

                // -- Phase 2: Carousel --
                FadeTransition(
                  opacity: _carouselFadeAnimation,
                  child: Container(
                    height: 280, // Fixed height for carousel
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: appTheme.bgLight,
                      borderRadius:
                          BorderRadius.circular(appTheme.borderRadius),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: PageView(
                            controller: _pageController,
                            children: [
                              // Slide 1: Fermi's estimation
                              _buildCarouselSlide(
                                context: context,
                                appTheme: appTheme,
                                imageAsset: 'assets/icons/fermi.png',
                                lottieAsset: 'assets/lotties/Windblow.json',
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
                              _buildCarouselSlide(
                                context: context,
                                appTheme: appTheme,
                                imageAsset: 'assets/icons/Colombus.png',
                                lottieAsset:
                                    'assets/lotties/boat steering.json',
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
                                    const TextSpan(
                                        text: ', On the other hand, '),
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
                              // Slide 3: Call to action
                              _buildCarouselSlide(
                                context: context,
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
                                    const TextSpan(text: 'How do '),
                                    TextSpan(
                                      text: 'you',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: appTheme.primary,
                                      ),
                                    ),
                                    const TextSpan(text: ' compare?'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
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
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // -- Phase 3: Button --
                FadeTransition(
                  opacity: _buttonFadeAnimation,
                  child: SizedBox(
                    width: 200,
                    child: MainButton(
                      onPressed: () => _getStarted(context),
                      label: MainButtonLabel.start,
                      customLabel: 'Get Started',
                    ),
                  ),
                ),

                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselSlide({
    required BuildContext context,
    required AppTheme appTheme,
    required TextSpan textSpan,
    String? imageAsset,
    String? lottieAsset,
    IconData? icon,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (imageAsset != null || lottieAsset != null)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (imageAsset != null)
                Container(
                  height: 80,
                  width: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage(imageAsset),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (imageAsset != null && lottieAsset != null)
                const SizedBox(width: 16),
              if (lottieAsset != null)
                ClipOval(
                  child: SizedBox(
                    height: 80,
                    width: 80,
                    child: Lottie.asset(
                      lottieAsset,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          )
        else if (icon != null)
          Icon(icon, size: 64, color: appTheme.primary),
        const SizedBox(height: 24),
        RichText(
          textAlign: TextAlign.center,
          text: textSpan,
        ),
      ],
    );
  }
}
