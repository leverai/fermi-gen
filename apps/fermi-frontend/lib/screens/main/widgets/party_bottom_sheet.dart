import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/screens/main/widgets/primary_cta.dart';
import 'package:fermi_frontend/widgets/selector_widget.dart';
import 'package:fermi_frontend/widgets/categories/category_chip_selector.dart'
    show CategoryChipItem, CategoryChipSelector, AllChip;

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
    backgroundColor: Colors.transparent,
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
                  padding: EdgeInsets.fromLTRB(
                      16.0, 0, 16.0, MediaQuery.of(context).viewPadding.bottom),
                  decoration: BoxDecoration(
                    color: appTheme.bg,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                    boxShadow: [
                      BoxShadow(
                        color: appTheme.shadowColor,
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: appTheme.border,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(
                                width:
                                    48), // Spacer to balance the close button
                            Text(
                              'Party Settings',
                              style: AppFont.primaryTextStyle(
                                context,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: appTheme.text,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.keyboard_arrow_down,
                                  color: appTheme.border, size: 32),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                      ),
                      // Category chip selector
                      const SizedBox(height: 8),
                      CategoryChipSelector(
                        categories: items,
                        initialSelectedIndices:
                            controller.selectedCategoryIndices,
                        onSelectionChanged: controller.selectCategoryIndices,
                        startColor: HSLColor.fromColor(appTheme.primary),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Choose difficulty:',
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: appTheme.text,
                            ),
                          ),
                          AllChip(
                            isSelected: controller.selectedDifficulty == null,
                            onTap: () => controller.selectDifficulty(null),
                          ),
                        ],
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
                      const SizedBox(height: 24),
                      PrimaryCta(
                        isLoading: controller.isSubmitting,
                        onPressed: onPrimaryAction,
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

List<CategoryChipItem> _buildCategories(MainScreenController controller) {
  final cfg = controller.configDto;
  if (cfg == null) return const <CategoryChipItem>[];
  return cfg.categories
      .map((c) => CategoryChipItem(
            id: c.index.toString(),
            title: c.slug,
          ))
      .toList(growable: false);
}
