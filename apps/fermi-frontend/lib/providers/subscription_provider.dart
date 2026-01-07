import 'package:flutter/foundation.dart';
import 'package:fermi_frontend/services/subscription_service.dart';

/// Provider for subscription state that caches Pro status.
///
/// Use this provider to check if the current user has Pro subscription.
/// Call [refresh] after app launch and after successful purchases to
/// sync the cached state with RevenueCat.
class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService;
  bool _isPro = false;
  bool _isLoading = true;

  SubscriptionProvider(this._subscriptionService);

  /// Whether the current user has Pro subscription.
  bool get isPro => _isPro;

  /// Whether subscription status is still loading.
  bool get isLoading => _isLoading;

  /// Refresh subscription status from RevenueCat.
  ///
  /// Call this after:
  /// - App launch (after auth)
  /// - Successful purchase
  /// - Returning from paywall (even if no purchase, user might have restored)
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      _isPro = await _subscriptionService.isPro;
    } catch (e) {
      debugPrint('SubscriptionProvider: Failed to check Pro status: $e');
      // On error, assume free tier to avoid blocking features incorrectly
      _isPro = false;
    }

    _isLoading = false;
    notifyListeners();
  }
}
