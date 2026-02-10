import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:fermi_frontend/services/subscription_service.dart';
import 'package:fermi_frontend/utils/env.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// Model for a benefit tier (free or pro) configuration.
class BenefitTier {
  final bool exists;
  final bool full;
  final String info;

  const BenefitTier({
    required this.exists,
    required this.full,
    required this.info,
  });

  factory BenefitTier.fromJson(Map<String, dynamic> json) {
    return BenefitTier(
      exists: json['exists'] as bool? ?? false,
      full: json['full'] as bool? ?? false,
      info: json['info'] as String? ?? '',
    );
  }

  /// Default tier when benefit doesn't exist.
  static const BenefitTier notAvailable = BenefitTier(
    exists: false,
    full: false,
    info: '',
  );

  /// Default tier when benefit fully exists.
  static const BenefitTier fullAccess = BenefitTier(
    exists: true,
    full: true,
    info: '',
  );
}

/// Model for a benefit comparison between free and pro tiers.
class Benefit {
  final String name;
  final BenefitTier free;
  final BenefitTier pro;

  const Benefit({
    required this.name,
    required this.free,
    required this.pro,
  });

  factory Benefit.fromJson(Map<String, dynamic> json) {
    final freeData = json['free'];
    final proData = json['pro'];
    return Benefit(
      name: json['name'] as String? ?? '',
      free: freeData is Map
          ? BenefitTier.fromJson(Map<String, dynamic>.from(freeData))
          : BenefitTier.notAvailable,
      pro: proData is Map
          ? BenefitTier.fromJson(Map<String, dynamic>.from(proData))
          : BenefitTier.fullAccess,
    );
  }
}

/// Paywall screen for displaying subscription options.
///
/// This screen fetches offerings from RevenueCat and displays them
/// in a custom UI matching the app's Neubrutalist design system.
///
/// Features:
/// - Dynamically pulls benefits from RevenueCat Offering metadata
/// - Shows FREE vs PRO comparison table
/// - Displays pricing, savings, and promotional badges
/// - Supports introductory offers (free trials) when configured
class PaywallScreen extends StatefulWidget {
  final SubscriptionService subscriptionService;

  /// Whether the current user is anonymous (not registered).
  /// Used only for display purposes (e.g. showing account creation suggestion).
  /// Does NOT gate purchases — anonymous users can purchase freely.
  final bool isAnonymous;

  const PaywallScreen({
    super.key,
    required this.subscriptionService,
    this.isAnonymous = false,
  });

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _errorMessage;
  String? _selectedPackageId;

  // Metadata from RevenueCat Offering
  List<Benefit> _benefits = [];
  String? _promoText;
  String? _popularPackageId;

  final ScrollController _scrollController = ScrollController();
  bool _showBottomBorder = true; // Show by default

  @override
  void initState() {
    super.initState();
    _loadOfferings();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // Hide border only when at the very bottom (no more content to scroll up into view)
    final showBorder = _scrollController.position.extentAfter > 0;
    if (showBorder != _showBottomBorder) {
      setState(() {
        _showBottomBorder = showBorder;
      });
    }
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final offerings = await widget.subscriptionService.getOfferings();
      if (offerings != null && offerings.current != null) {
        // Extract metadata from offering
        final metadata = offerings.current!.metadata;
        _benefits = _extractBenefits(metadata);
        _promoText = metadata['promo_text'] as String?;
        _popularPackageId = metadata['popular_package'] as String?;

        // Default to yearly as selected if no popular_package specified
        _selectedPackageId =
            _popularPackageId ?? offerings.current!.annual?.identifier;
      }

      setState(() {
        _offerings = offerings;
        _isLoading = false;
      });

      // Check scroll state after the next frame to see if we reached the bottom or content is small
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load subscription options';
        _isLoading = false;
      });
    }
  }

  /// Extract benefits from metadata, supporting both new and legacy formats.
  List<Benefit> _extractBenefits(Map<String, dynamic> metadata) {
    // Try new format first: "benefits" array
    final benefitsRaw = metadata['benefits'];
    if (benefitsRaw is List) {
      final List<Benefit> benefits = [];
      for (final item in benefitsRaw) {
        if (item is Map) {
          benefits.add(Benefit.fromJson(Map<String, dynamic>.from(item)));
        }
      }
      return benefits;
    }

    // Fallback to legacy format: "free_benefits" and "pro_benefits" arrays
    final freeBenefits = _extractStringList(metadata, 'free_benefits');
    final proBenefits = _extractStringList(metadata, 'pro_benefits');

    if (proBenefits.isEmpty && freeBenefits.isEmpty) {
      return [];
    }

    // Convert legacy format: assume benefits at same index correspond
    final maxLen = proBenefits.length > freeBenefits.length
        ? proBenefits.length
        : freeBenefits.length;
    final List<Benefit> benefits = [];

    for (var i = 0; i < maxLen; i++) {
      final freeBenefit = i < freeBenefits.length ? freeBenefits[i] : null;
      final proBenefit = i < proBenefits.length ? proBenefits[i] : null;

      // Use pro benefit name as the primary name, fall back to free
      final name = proBenefit ?? freeBenefit ?? '';

      benefits.add(Benefit(
        name: name,
        free: freeBenefit != null
            ? BenefitTier(exists: true, full: true, info: freeBenefit)
            : BenefitTier.notAvailable,
        pro: proBenefit != null
            ? BenefitTier(exists: true, full: true, info: proBenefit)
            : BenefitTier.fullAccess,
      ));
    }

    return benefits;
  }

  List<String> _extractStringList(Map<String, dynamic> metadata, String key) {
    final value = metadata[key];
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }

  Future<void> _purchasePackage(Package package) async {

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.subscriptionService.purchasePackage(package);
      if (success && mounted) {
        Navigator.of(context).pop(true); // Return success
      } else {
        setState(() {
          _errorMessage = 'Purchase was not completed';
          _isPurchasing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Purchase error: $e';
        _isPurchasing = false;
      });
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.subscriptionService.restorePurchases();
      if (success && mounted) {
        Navigator.of(context).pop(true); // Return success
      } else {
        setState(() {
          _errorMessage = 'No purchases found to restore';
          _isPurchasing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Restore error: $e';
        _isPurchasing = false;
      });
    }
  }

  /// Calculate savings percentage for annual vs monthly
  int? _calculateSavingsPercent() {
    final monthly = _offerings?.current?.monthly;
    final annual = _offerings?.current?.annual;
    if (monthly == null || annual == null) return null;

    final monthlyPrice = monthly.storeProduct.price;
    final annualPrice = annual.storeProduct.price;
    final yearlyIfMonthly = monthlyPrice * 12;
    if (yearlyIfMonthly <= 0) return null;

    final savings = yearlyIfMonthly - annualPrice;
    return ((savings / yearlyIfMonthly) * 100).round();
  }

  Package? _getSelectedPackage() {
    if (_offerings?.current == null || _selectedPackageId == null) return null;
    return _offerings!.current!.availablePackages.firstWhere(
      (p) => p.identifier == _selectedPackageId,
      orElse: () => _offerings!.current!.availablePackages.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Scaffold(
      backgroundColor: appTheme.bgDark,
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(color: appTheme.primary),
              )
            : _errorMessage != null && _offerings == null
                ? _buildErrorState(appTheme)
                : _offerings?.current == null
                    ? _buildNoOfferingsState(appTheme)
                    : _buildPaywallContent(appTheme),
      ),
    );
  }

  Widget _buildErrorState(AppTheme appTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: appTheme.danger),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 16,
                color: appTheme.text,
              ),
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              appTheme: appTheme,
              label: 'Retry',
              onPressed: _loadOfferings,
              isPrimary: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoOfferingsState(AppTheme appTheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 48, color: appTheme.textMuted),
          const SizedBox(height: 16),
          Text(
            'No subscription options available',
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 16,
              color: appTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaywallContent(AppTheme appTheme) {
    final savingsPercent = _calculateSavingsPercent();
    final selectedPackage = _getSelectedPackage();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom header with close button
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Transform.translate(
                        offset: const Offset(-8, 0),
                        child: IconButton(
                          icon: Icon(Icons.close, color: appTheme.border),
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                ),
                // Logo and title
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: appTheme.bg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: SvgPicture.asset(
                          'assets/icons/logo-fg.svg',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Upgrade to PRO',
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: appTheme.text,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),

                // Promo text banner
                if (_promoText != null) ...[
                  _buildPromoBanner(appTheme),
                  const SizedBox(height: 16),
                ],

                // Account creation suggestion for anonymous users
                if (widget.isAnonymous) ...[
                  _buildAccountSuggestion(appTheme),
                  const SizedBox(height: 16),
                ],

                // Benefits comparison
                _buildBenefitsComparison(appTheme),
                const SizedBox(height: 16),

                // Product cards
                _buildProductCards(appTheme, savingsPercent),
                const SizedBox(height: 24),

                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _errorMessage!,
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 14,
                        color: appTheme.danger,
                      ),
                    ),
                  ),

                // Restore purchases link
                Center(
                  child: TextButton(
                    onPressed: _isPurchasing ? null : _restorePurchases,
                    child: Text(
                      'Restore Purchases',
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: appTheme.textMuted,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Legal text
                _buildLegalText(appTheme),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Fixed bottom CTA
        _buildBottomCTA(appTheme, selectedPackage),
      ],
    );
  }

  Widget _buildPromoBanner(AppTheme appTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: appTheme.secondary,
        borderRadius: BorderRadius.circular(appTheme.borderRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_offer, size: 20, color: appTheme.text),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _promoText!,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: appTheme.text,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsComparison(AppTheme appTheme) {
    // Only show benefits from RC metadata - no fallback
    if (_benefits.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.bg,
        borderRadius: BorderRadius.circular(appTheme.borderRadius),
      ),
      child: Column(
        children: [
          // Header row: (empty for names) | FREE | PRO
          Row(
            children: [
              const Expanded(flex: 3, child: SizedBox()),
              Expanded(
                flex: 2,
                child: Text(
                  'FREE',
                  textAlign: TextAlign.center,
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: appTheme.textMuted,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: appTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'PRO',
                    textAlign: TextAlign.center,
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: appTheme.bgLight,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Benefits rows
          ..._benefits.map((benefit) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Left column - benefit name
                  Expanded(
                    flex: 3,
                    child: Text(
                      benefit.name,
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: appTheme.text,
                      ),
                    ),
                  ),
                  // FREE column - icon and info
                  Expanded(
                    flex: 2,
                    child: _buildBenefitCell(appTheme, benefit.free),
                  ),
                  // PRO column - icon and info
                  Expanded(
                    flex: 2,
                    child: _buildBenefitCell(appTheme, benefit.pro),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Build a benefit cell with icon and optional info text.
  Widget _buildBenefitCell(AppTheme appTheme, BenefitTier tier) {
    // Determine icon and color based on exists/full
    IconData icon;
    Color color;

    if (!tier.exists) {
      // Benefit doesn't exist for this tier
      icon = Icons.close;
      color = appTheme.danger;
    } else if (tier.full) {
      // Full access
      icon = Icons.check_circle_rounded;
      color = appTheme.primary;
    } else {
      // Partial/limited access
      icon = Icons.do_disturb_on_rounded;
      color = appTheme.textMuted;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: color),
        if (tier.info.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            tier.info,
            textAlign: TextAlign.center,
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 11,
              color: color,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildProductCards(AppTheme appTheme, int? savingsPercent) {
    // Create a mutable copy since availablePackages is unmodifiable
    final packages = _offerings!.current!.availablePackages.toList();

    // Sort packages: monthly, annual, lifetime
    packages.sort((a, b) {
      final order = {
        PackageType.monthly: 0,
        PackageType.annual: 1,
        PackageType.lifetime: 2,
      };
      return (order[a.packageType] ?? 99).compareTo(order[b.packageType] ?? 99);
    });

    return Column(
      children: packages.map((package) {
        final isSelected = package.identifier == _selectedPackageId;
        final isPopular = package.identifier == _popularPackageId ||
            (package.packageType == PackageType.annual &&
                _popularPackageId == null);
        final showSavings = package.packageType == PackageType.annual &&
            savingsPercent != null &&
            savingsPercent > 0;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildProductCard(
            appTheme: appTheme,
            package: package,
            isSelected: isSelected,
            isPopular: isPopular,
            savingsPercent: showSavings ? savingsPercent : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProductCard({
    required AppTheme appTheme,
    required Package package,
    required bool isSelected,
    required bool isPopular,
    int? savingsPercent,
  }) {
    final product = package.storeProduct;
    final packageLabel = _getPackageLabel(package.packageType);
    final billingPeriod = _getBillingPeriod(package.packageType);

    // Check for free trial (Android subscriptionOptions)
    String? freeTrialText;
    if (product.subscriptionOptions != null) {
      for (final option in product.subscriptionOptions!) {
        final freePhase = option.freePhase;
        if (freePhase != null) {
          final period = freePhase.billingPeriod;
          if (period != null) {
            final periodValue = period.value;
            final periodUnit = period.unit;
            freeTrialText =
                '$periodValue ${_periodUnitText(periodUnit)} free trial';
          }
          break;
        }
      }
    }

    return GestureDetector(
      onTap: _isPurchasing
          ? null
          : () {
              setState(() {
                _selectedPackageId = package.identifier;
              });
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? appTheme.primary : appTheme.bg,
          borderRadius: BorderRadius.circular(appTheme.borderRadius),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: appTheme.primaryMuted,
                    offset: appTheme.shadowOffset,
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? appTheme.text : appTheme.borderMuted,
                  width: 2,
                ),
                color: isSelected ? appTheme.text : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.check, size: 16, color: appTheme.bg)
                  : null,
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        packageLabel,
                        style: AppFont.primaryTextStyle(
                          context,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: appTheme.text,
                        ),
                      ),
                      if (isPopular) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: appTheme.secondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'BEST VALUE',
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: appTheme.text,
                            ),
                          ),
                        ),
                      ],
                      if (savingsPercent != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: appTheme.warning,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'SAVE $savingsPercent%',
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: appTheme.bgLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (freeTrialText != null)
                    Text(
                      freeTrialText,
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: appTheme.success,
                      ),
                    )
                  else if (product.description.isNotEmpty)
                    Text(
                      product.description,
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 12,
                        color: appTheme.text.withAlpha(150),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

            // Price
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product.priceString,
                  style: AppFont.secondaryTextStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: appTheme.text,
                  ),
                ),
                if (billingPeriod != null)
                  Text(
                    billingPeriod,
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 12,
                      color: appTheme.text.withAlpha(150),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getPackageLabel(PackageType type) {
    switch (type) {
      case PackageType.monthly:
        return 'Monthly';
      case PackageType.annual:
        return 'Yearly';
      case PackageType.lifetime:
        return 'Lifetime';
      case PackageType.weekly:
        return 'Weekly';
      case PackageType.sixMonth:
        return '6 Months';
      case PackageType.threeMonth:
        return '3 Months';
      case PackageType.twoMonth:
        return '2 Months';
      default:
        return 'Pro';
    }
  }

  String? _getBillingPeriod(PackageType type) {
    switch (type) {
      case PackageType.monthly:
        return '/month';
      case PackageType.annual:
        return '/year';
      case PackageType.lifetime:
        return 'one-time';
      case PackageType.weekly:
        return '/week';
      case PackageType.sixMonth:
        return '/6 months';
      case PackageType.threeMonth:
        return '/3 months';
      case PackageType.twoMonth:
        return '/2 months';
      default:
        return null;
    }
  }

  String _periodUnitText(PeriodUnit unit) {
    switch (unit) {
      case PeriodUnit.day:
        return 'day';
      case PeriodUnit.week:
        return 'week';
      case PeriodUnit.month:
        return 'month';
      case PeriodUnit.year:
        return 'year';
      default:
        return 'day';
    }
  }

  Widget _buildAccountSuggestion(AppTheme appTheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: appTheme.bgLight,
        borderRadius: BorderRadius.circular(appTheme.borderRadius),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: appTheme.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Create an account to access your purchases across all your devices.',
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 12,
                color: appTheme.textMuted,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegalText(AppTheme appTheme) {
    final privacyPolicyUrl = '${resolveApiBaseUrlOrThrow().replaceFirst('/api/v1', '')}/api/v1/privacy-policy';
    final termsUrl = Platform.isIOS
        ? 'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'
        : 'https://play.google.com/intl/en_us/about/play-terms/';

    final linkStyle = AppFont.primaryTextStyle(
      context,
      fontSize: 12,
      color: appTheme.textMuted,
      decoration: TextDecoration.underline,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(privacyPolicyUrl),
                mode: LaunchMode.externalApplication),
            child: Text('Privacy Policy', style: linkStyle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '•',
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 12,
                color: appTheme.borderMuted,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => launchUrl(Uri.parse(termsUrl),
                mode: LaunchMode.externalApplication),
            child: Text('Terms of Use', style: linkStyle),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCTA(AppTheme appTheme, Package? selectedPackage) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: appTheme.bg,
        border: _showBottomBorder
            ? Border(
                top: BorderSide(color: appTheme.borderMuted, width: 0.2),
              )
            : null,
      ),
      child: _buildActionButton(
        appTheme: appTheme,
        label: _isPurchasing
            ? 'Processing...'
            : selectedPackage != null
                ? 'Continue with ${_getPackageLabel(selectedPackage.packageType)}'
                : 'Select a Plan',
        onPressed: selectedPackage != null && !_isPurchasing
            ? () => _purchasePackage(selectedPackage)
            : null,
        isPrimary: true,
        isLoading: _isPurchasing,
      ),
    );
  }

  Widget _buildActionButton({
    required AppTheme appTheme,
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: isPrimary
              ? (onPressed != null ? appTheme.primary : appTheme.primaryMuted)
              : appTheme.bgLight,
          borderRadius: BorderRadius.circular(appTheme.borderRadius),
        ),
        child: Center(
          child: isLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isPrimary ? appTheme.bgLight : appTheme.text,
                  ),
                )
              : Text(
                  label,
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isPrimary
                        ? appTheme.text
                        : appTheme.text.withAlpha(150),
                  ),
                ),
        ),
      ),
    );
  }
}
