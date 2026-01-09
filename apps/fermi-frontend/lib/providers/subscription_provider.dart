import 'package:flutter/foundation.dart';
import 'package:fermi_frontend/services/subscription_service.dart';
import 'package:fermi_frontend/main.dart' show useEmulators;

/// Provider for subscription state that caches Pro status.
///
/// Use this provider to check if the current user has Pro subscription.
/// Call [refresh] after app launch and after successful purchases to
/// sync the cached state with RevenueCat.
///
/// In emulator mode (USE_EMULATORS=true), use [setDevOverride] to toggle
/// between Free and Pro for testing.
class SubscriptionProvider extends ChangeNotifier {
  final SubscriptionService _subscriptionService;
  bool _isPro = false;
  bool _isLoading = true;

  /// Dev-only override for testing in emulator mode.
  /// When non-null, this value is used instead of RevenueCat status.
  bool? _devOverridePro;

  SubscriptionProvider(this._subscriptionService);

  /// Whether the current user has Pro subscription.
  /// In emulator mode, returns the dev override if set.
  bool get isPro => _devOverridePro ?? _isPro;

  /// Whether subscription status is still loading.
  bool get isLoading => _isLoading;

  /// Whether dev override is currently active.
  bool get hasDevOverride => _devOverridePro != null;

  /// Set dev override for Pro status (emulator mode only).
  /// Pass null to clear the override and use RevenueCat.
  void setDevOverride(bool? isPro) {
    if (!useEmulators) {
      debugPrint(
          'SubscriptionProvider: Dev override only available in emulator mode');
      return;
    }
    _devOverridePro = isPro;
    notifyListeners();
  }

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
