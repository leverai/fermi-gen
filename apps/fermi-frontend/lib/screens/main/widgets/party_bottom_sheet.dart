import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/models/user_limits.dart';
import 'package:fermi_frontend/screens/paywall_screen.dart';
import 'package:fermi_frontend/services/subscription_service.dart';
import 'package:fermi_frontend/services/feedback_service.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:provider/provider.dart';
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
  bool isAnonymous = false,
}) {
  final AppTheme appTheme =
      Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

  void showPaywall() {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => PaywallScreen(
          subscriptionService:
              Provider.of<SubscriptionService>(context, listen: false),
          isAnonymous: isAnonymous,
        ),
      ),
    )
        .then((purchased) {
      if (purchased == true) {
        // Refresh user limits to update "N free hostings left" message
        controller.refreshUserLimits();
      }
    });
  }

  // Search box controller is owned here so its text survives sheet rebuilds
  // and can be set programmatically (recent-search chips). Seeded from any
  // restored/in-progress query.
  final TextEditingController searchController =
      TextEditingController(text: controller.searchQuery ?? '');

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
              final UserLimits? userLimits = controller.userLimitsDto;
              final bool canHost = userLimits?.canHost ?? true;
              // Keep the text field in sync if the controller cleared the
              // query externally (e.g. a chip tap cleared the search).
              final String desiredText = controller.searchQuery ?? '';
              if (searchController.text != desiredText &&
                  !controller.isSearching) {
                searchController.text = desiredText;
              }
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
                              onPressed: () {
                                FeedbackService.instance.secondaryClick();
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        ),
                      ),
                      // Category chip selector (with optional smart search)
                      const SizedBox(height: 8),
                      CategoryChipSelector(
                        categories: items,
                        initialSelectedIndices:
                            controller.selectedCategoryIndices,
                        onSelectionChanged: controller.selectCategoryIndices,
                        startColor: HSLColor.fromColor(appTheme.primary),
                        searchEnabled: controller.smartSearchEnabled,
                        searchController: searchController,
                        onSearchChanged: controller.setSearchQuery,
                        searchError: controller.searchError,
                        isSearching: controller.isSearching,
                      ),
                      // Recent searches (tappable chips), only when smart
                      // search is on and the user has any.
                      if (controller.smartSearchEnabled &&
                          controller.recentSearches.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _RecentSearches(
                          recents: controller.recentSearches,
                          onTap: (q) {
                            searchController.text = q;
                            searchController.selection =
                                TextSelection.collapsed(offset: q.length);
                            controller.setSearchQuery(q);
                          },
                        ),
                      ],
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
                      Center(
                        child: MainButton(
                          isLoading: controller.isSubmitting,
                          onPressed: canHost ? onPrimaryAction : showPaywall,
                          label: canHost ? MainButtonLabel.create : null,
                          customLabel: canHost ? null : 'Get Unlimited',
                          iconAssetPath:
                              canHost ? 'assets/icons/spacebar.svg' : null,
                        ),
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
  ).whenComplete(searchController.dispose);
}

/// Horizontally-scrolling row of tappable recent-search chips.
class _RecentSearches extends StatelessWidget {
  final List<String> recents;
  final ValueChanged<String> onTap;

  const _RecentSearches({required this.recents, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Recent searches:',
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: appTheme.text,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recents
              .map((q) => _RecentSearchChip(label: q, onTap: () => onTap(q)))
              .toList(growable: false),
        ),
      ],
    );
  }
}

/// A single tappable recent-search chip.
class _RecentSearchChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RecentSearchChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          FeedbackService.instance.secondaryClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: appTheme.bgDark,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: appTheme.borderMuted, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 14, color: appTheme.textMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: appTheme.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
