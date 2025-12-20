import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/screens/main/widgets/primary_cta.dart';
import 'package:fermi_frontend/widgets/selector_widget.dart';
import 'package:fermi_frontend/widgets/lock_toggle_chip.dart';
import 'package:fermi_frontend/widgets/categories/category_carousel_m3.dart';

/// Shows a modal bottom sheet for configuring party game settings.
///
/// Displays category selection, difficulty selection, lock toggle, and primary CTA.
void showPartyBottomSheet({
  required BuildContext context,
  required MainScreenController controller,
  required VoidCallback onPrimaryAction,
}) {
  final AppTheme appTheme =
      Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

  showModalBottomSheet(
    context: context,
    backgroundColor: appTheme.bgLight,
    isScrollControlled: true,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return AnimatedBuilder(
            animation: controller,
            builder: (context, _) {
              final items = _buildCategories(controller);
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
                      Text(
                        'Select Category:',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: appTheme.textMuted,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      CategoryCarouselM3(
                        categories: items,
                        initialIndex: controller.selectedCategoryIndex,
                        onCategorySelected: controller.selectCategoryIndex,
                        onCenteredIndexChanged: controller.selectCategoryIndex,
                        startColor: HSLColor.fromColor(appTheme.primary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Select Difficulty:',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: appTheme.textMuted,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 16),
                      SelectorWidget(
                        options: controller.difficulties
                            .map((d) => SelectorOption(
                                  label: d.slug,
                                  value: d.name,
                                  iconUrl: d.picture,
                                ))
                            .toList(),
                        selected: controller.selectedDifficulty,
                        onChanged: (value) {
                          if (value == null ||
                              value == controller.selectedDifficulty) {
                            controller.selectDifficulty(null);
                          } else {
                            controller.selectDifficulty(value);
                          }
                        },
                        allowNoSelection: true,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          LockToggleChip(
                            isLocked: controller.isLocked,
                            onToggle: controller.toggleLock,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: PrimaryCta(
                              isLoading: controller.isSubmitting,
                              onPressed: onPrimaryAction,
                              isLocked: controller.isLocked,
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

List<CategoryItemM3> _buildCategories(MainScreenController controller) {
  final cfg = controller.configDto;
  if (cfg == null) return const <CategoryItemM3>[];
  return cfg.categories
      .map((c) => CategoryItemM3(
            id: c.index.toString(),
            title: c.slug,
            svgPath: c.picture,
          ))
      .toList(growable: false);
}
