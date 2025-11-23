import 'package:flutter/material.dart';
import 'package:dots_indicator/dots_indicator.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/screens/question_v2/widgets/carousel_page_wrapper.dart';

/// A horizontal carousel widget that displays game cards for each question.
/// Uses PageView for native Flutter state preservation.
/// Includes a dots indicator to show the current question index.
class GameCarousel extends StatelessWidget {
  const GameCarousel({
    super.key,
    required this.itemCount,
    required this.currentIndex,
    required this.pageController,
    required this.itemBuilder,
    required this.onPageChanged,
    required this.height,
    this.enableUserSwipe = false,
  });

  final int itemCount;
  final int currentIndex;
  final PageController pageController;
  final Widget Function(BuildContext, int, int) itemBuilder;
  final ValueChanged<int>? onPageChanged;
  final double height;
  final bool enableUserSwipe;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // PageView carousel with state preservation
          // Use OverflowBox to allow PageView to extend beyond constraints for spacing
          LayoutBuilder(
            builder: (context, constraints) {
              // Original card width (what it should be) - this is the PageView's available width
              // This accounts for the parent Column's 24px padding on each side
              final double originalCardWidth = constraints.maxWidth;
              // Spacing between cards (12px on each side = 24px total)
              const double spacing = 24.0;
              // Page width needs to be wider to accommodate spacing
              final double pageWidth = originalCardWidth + spacing;

              return OverflowBox(
                minWidth: pageWidth,
                maxWidth: pageWidth,
                alignment: Alignment.center,
                child: SizedBox(
                  height: height,
                  width: pageWidth,
                  child: PageView.builder(
                    controller: pageController,
                    itemCount: itemCount,
                    physics: enableUserSwipe
                        ? const ClampingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: onPageChanged,
                    itemBuilder: (context, index) {
                      // Each page has padding on sides, card maintains original width
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: SizedBox(
                          width: originalCardWidth,
                          child: CarouselPageWrapper(
                            index: index,
                            child: itemBuilder(context, index, index),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),
          // Dots indicator - positioned 24px below the question_answer card bottom
          Positioned(
            bottom: 24 +
                4, // 24px from question_answer card bottom (48px feedback row - 24px)
            left: 0,
            right: 0,
            child: Center(
              child: DotsIndicator(
                dotsCount: itemCount,
                position: currentIndex,
                decorator: DotsDecorator(
                  color: enableUserSwipe
                      ?
                      // ignore: deprecated_member_use
                      appTheme.primary.withOpacity(0.3)
                      :
                      // ignore: deprecated_member_use
                      appTheme.highlight.withOpacity(0.3),
                  activeColor:
                      enableUserSwipe ? appTheme.primary : appTheme.highlight,
                  size: const Size.square(6.0),
                  activeSize: const Size(10.0, 6.0),
                  spacing: const EdgeInsets.all(4.0),
                  activeShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
