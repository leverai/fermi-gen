import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  static const String _entitlementId = 'pro';

  bool _isInitialized = false;
  CustomerInfo? _customerInfo;

  /// Initialize RevenueCat SDK with platform-specific API keys
  Future<void> initialize() async {
    if (_isInitialized) return;

    late String apiKey;
    if (kIsWeb) {
      // Web not supported in Phase 1
      return;
    } else if (Platform.isIOS) {
      apiKey = const String.fromEnvironment('REVENUECAT_IOS_API_KEY');
    } else if (Platform.isAndroid) {
      apiKey = const String.fromEnvironment('REVENUECAT_ANDROID_API_KEY');
    } else {
      return; // Unsupported platform
    }

    if (apiKey.isEmpty) {
      debugPrint('RevenueCat API key not configured');
      return;
    }

    await Purchases.configure(PurchasesConfiguration(apiKey));
    _isInitialized = true;
  }

  /// Login user to RevenueCat (call after Firebase auth)
  Future<void> login(String firebaseUid) async {
    if (!_isInitialized) return;
    final result = await Purchases.logIn(firebaseUid);
    _customerInfo = result.customerInfo;
  }

  /// Logout user from RevenueCat
  Future<void> logout() async {
    if (!_isInitialized) return;
    await Purchases.logOut();
    _customerInfo = null;
  }

  /// Check if user has active Pro entitlement
  Future<bool> get isPro async {
    if (!_isInitialized) return false;
    _customerInfo ??= await Purchases.getCustomerInfo();
    return _customerInfo?.entitlements.active.containsKey(_entitlementId) ??
        false;
  }

  /// Fetch available offerings for custom paywall
  Future<Offerings?> getOfferings() async {
    if (!_isInitialized) return null;
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (e) {
      debugPrint('Error fetching offerings: ${e.message}');
      return null;
    }
  }

  /// Purchase a package (returns true if successful)
  Future<bool> purchasePackage(Package package) async {
    if (!_isInitialized) return false;
    try {
      _customerInfo = await Purchases.purchasePackage(package);
      return _customerInfo?.entitlements.active.containsKey(_entitlementId) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('Purchase error: ${e.message}');
      return false;
    }
  }

  /// Restore previous purchases
  Future<bool> restorePurchases() async {
    if (!_isInitialized) return false;
    try {
      _customerInfo = await Purchases.restorePurchases();
      return _customerInfo?.entitlements.active.containsKey(_entitlementId) ??
          false;
    } on PlatformException catch (e) {
      debugPrint('Restore error: ${e.message}');
      return false;
    }
  }
}
