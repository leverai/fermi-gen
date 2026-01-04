import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:http/http.dart' as http;

class SubscriptionService {
  static const String _entitlementId = 'Guesstimate Pro';
  static const String _debugEndpoint = 'http://10.0.2.2:7242/ingest/fe179d7c-61d9-4203-845a-3c82594547fd';

  bool _isInitialized = false;
  CustomerInfo? _customerInfo;

  // #region agent log
  void _debugLog(String location, String message, Map<String, dynamic> data, String hypothesisId) {
    final payload = {'location': location, 'message': message, 'data': data, 'timestamp': DateTime.now().millisecondsSinceEpoch, 'sessionId': 'debug-session', 'hypothesisId': hypothesisId};
    http.post(Uri.parse(_debugEndpoint), headers: {'Content-Type': 'application/json'}, body: jsonEncode(payload)).catchError((_) => http.Response('', 500));
  }
  // #endregion

  /// Initialize RevenueCat SDK with platform-specific API keys
  Future<void> initialize() async {
    // #region agent log
    _debugLog('subscription_service.dart:initialize:entry', 'initialize() called', {'_isInitialized': _isInitialized, 'kIsWeb': kIsWeb}, 'C,D');
    // #endregion
    if (_isInitialized) return;

    late String apiKey;
    if (kIsWeb) {
      // #region agent log
      _debugLog('subscription_service.dart:initialize:web', 'Exiting: web platform not supported', {}, 'C');
      // #endregion
      // Web not supported in Phase 1
      return;
    } else if (Platform.isIOS) {
      apiKey = const String.fromEnvironment('REVENUECAT_IOS_API_KEY');
    } else if (Platform.isAndroid) {
      apiKey = const String.fromEnvironment('REVENUECAT_ANDROID_API_KEY');
    } else {
      // #region agent log
      _debugLog('subscription_service.dart:initialize:unsupported', 'Exiting: unsupported platform', {}, 'C');
      // #endregion
      return; // Unsupported platform
    }

    // #region agent log
    _debugLog('subscription_service.dart:initialize:apikey', 'API key check', {'apiKeyEmpty': apiKey.isEmpty, 'apiKeyLength': apiKey.length}, 'D');
    // #endregion

    if (apiKey.isEmpty) {
      debugPrint('RevenueCat API key not configured');
      // #region agent log
      _debugLog('subscription_service.dart:initialize:nokey', 'Exiting: API key empty', {}, 'D');
      // #endregion
      return;
    }

    await Purchases.configure(PurchasesConfiguration(apiKey));
    _isInitialized = true;
    // #region agent log
    _debugLog('subscription_service.dart:initialize:success', 'RevenueCat SDK initialized', {'_isInitialized': _isInitialized}, 'C,D');
    // #endregion
  }

  /// Login user to RevenueCat (call after Firebase auth)
  Future<void> login(String firebaseUid) async {
    // #region agent log
    _debugLog('subscription_service.dart:login:entry', 'login() called', {'firebaseUid': firebaseUid, '_isInitialized': _isInitialized}, 'A,B');
    // #endregion
    if (!_isInitialized) {
      // #region agent log
      _debugLog('subscription_service.dart:login:skip', 'SKIPPING login - not initialized!', {'firebaseUid': firebaseUid}, 'A');
      // #endregion
      return;
    }
    final result = await Purchases.logIn(firebaseUid);
    _customerInfo = result.customerInfo;
    // #region agent log
    _debugLog('subscription_service.dart:login:success', 'RevenueCat login success', {'firebaseUid': firebaseUid, 'rcAppUserId': result.customerInfo.originalAppUserId}, 'A,B');
    // #endregion
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
    if (!_isInitialized) {
      debugPrint('RevenueCat: getOfferings called but SDK not initialized');
      return null;
    }
    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('RevenueCat: offerings fetched successfully');
      debugPrint(
          'RevenueCat: current offering = ${offerings.current?.identifier}');
      debugPrint('RevenueCat: all offerings = ${offerings.all.keys.toList()}');
      if (offerings.current != null) {
        debugPrint(
            'RevenueCat: packages in current = ${offerings.current!.availablePackages.map((p) => p.identifier).toList()}');
      }
      return offerings;
    } on PlatformException catch (e) {
      debugPrint('Error fetching offerings: ${e.message}');
      return null;
    }
  }

  /// Purchase a package (returns true if successful)
  Future<bool> purchasePackage(Package package) async {
    if (!_isInitialized) return false;
    try {
      // #region agent log
      final preInfo = await Purchases.getCustomerInfo();
      _debugLog('subscription_service.dart:purchasePackage:pre', 'About to purchase - current RC state', {'appUserId': preInfo.originalAppUserId, 'packageId': package.identifier}, 'B,E');
      // #endregion
      _customerInfo = await Purchases.purchasePackage(package);
      // #region agent log
      _debugLog('subscription_service.dart:purchasePackage:post', 'Purchase completed', {'appUserId': _customerInfo?.originalAppUserId}, 'B,E');
      // #endregion
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
