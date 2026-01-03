import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fermi_frontend/utils/env.dart';

class AuthService {
  final FirebaseAuth _auth;
  final http.Client _httpClient;
  final String _apiBaseUrl;
  String? accessToken;
  String? firebaseUid;
  AuthUser? currentUser;
  String? locale; // 'US' or 'EU'
  LastRoundSettings? lastRoundSettings;
  bool shouldRefreshStats = false;

  /// Creates an AuthService instance.
  ///
  /// Parameters [auth], [httpClient], and [apiBaseUrl] are optional for testing purposes.
  /// By default, uses [FirebaseAuth.instance], a new [http.Client], and resolves the API URL from dart-define.
  AuthService({
    FirebaseAuth? auth,
    http.Client? httpClient,
    String? apiBaseUrl,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _httpClient = httpClient ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? resolveApiBaseUrlOrThrow();

  /// Returns true if the current user is signed in anonymously.
  bool get isAnonymous {
    return _auth.currentUser?.isAnonymous ?? false;
  }

  /// Signs in the user anonymously.
  ///
  /// Creates a temporary anonymous account that can later be upgraded
  /// to a permanent account by linking credentials.
  Future<bool> signInAnonymously() async {
    try {
      final userCredential = await _auth.signInAnonymously();
      if (userCredential.user != null) {
        // Exchange token after anonymous sign-in
        return await exchangeToken();
      }
      return false;
    } catch (e) {
      debugPrint("Anonymous sign-in error: $e");
      return false;
    }
  }

  /// Links the current anonymous account with a credential (email/password or OAuth).
  ///
  /// This upgrades the anonymous account to a permanent account while preserving
  /// the Firebase UID and all associated data.
  Future<bool> linkWithCredential(AuthCredential credential) async {
    try {
      final user = _auth.currentUser;
      if (user == null || !user.isAnonymous) {
        debugPrint("Cannot link: user is not anonymous");
        return false;
      }

      final userCredential = await user.linkWithCredential(credential);
      if (userCredential.user != null) {
        // Re-exchange token after linking to get updated user info
        return await exchangeToken();
      }
      return false;
    } on FirebaseAuthException catch (e) {
      debugPrint("Account linking error: ${e.code} - ${e.message}");
      rethrow;
    } catch (e) {
      debugPrint("Account linking error: $e");
      rethrow;
    }
  }

  Future<bool> exchangeToken() async {
    try {
      final user = _auth.currentUser;

      if (user != null) {
        // 1. Get Firebase ID token (works for both anonymous and regular users)
        final idToken = await user.getIdToken();

        // 2. Exchange for backend access token
        final response = await _httpClient.post(
          Uri.parse("$_apiBaseUrl/auth/token"),
          headers: {
            "Authorization": "Bearer $idToken",
            "Accept": "application/json",
          },
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          /* TODO: store returned user object as well - it will be needed
          for future requests to the backend and for displaying the user's
          avatar. */
          accessToken = data['access_token'];
          final Map<String, dynamic>? userJson =
              (data['user'] is Map<String, dynamic>) ? data['user'] : null;
          if (userJson != null) {
            currentUser = AuthUser.fromJson(userJson);
            firebaseUid = currentUser?.firebaseUid;
            // Persist locale if backend includes it (optional for backward compat)
            final String? loc = userJson['locale'] as String?;
            if (loc != null && loc.isNotEmpty) {
              locale = loc;
            }
          }
          return true;
        } else {
          // Log server response for debugging
          try {
            final data = jsonDecode(response.body);
            debugPrint("Token exchange failed: ${response.statusCode} $data");
          } catch (_) {
            debugPrint("Token exchange failed: ${response.statusCode}");
          }
        }
      }
    } catch (e) {
      debugPrint("Token exchange error: $e");
    }
    return false;
  }

  // Resolver centralized in utils/env.dart

  Future<bool> refreshAccessToken() async {
    final String? token = accessToken;
    if (token == null || token.isEmpty) return false;
    try {
      final response = await _httpClient.post(
        Uri.parse("$_apiBaseUrl/auth/refresh"),
        headers: {
          "Authorization": "Bearer $token",
          "Accept": "application/json",
        },
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        accessToken = data['access_token'] as String? ?? accessToken;
        final Map<String, dynamic>? userJson =
            (data['user'] is Map<String, dynamic>) ? data['user'] : null;
        if (userJson != null) {
          currentUser = AuthUser.fromJson(userJson);
          firebaseUid = currentUser?.firebaseUid;
          final String? loc = userJson['locale'] as String?;
          if (loc != null && loc.isNotEmpty) {
            locale = loc;
          }
        }
        return true;
      }

      if (response.statusCode == 401) {
        // Fallback to a fresh exchange using Firebase ID token
        return await exchangeToken();
      }

      try {
        final dynamic body = jsonDecode(response.body);
        debugPrint(
            "Token refresh failed: ${response.statusCode} ${body.toString()}");
      } catch (_) {
        debugPrint("Token refresh failed: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Token refresh error: $e");
    }
    return false;
  }

  Future<void> signOut() async {
    try {
      // 1. Call backend sign-out (skip for anonymous users as they may not have backend accounts)
      if (accessToken != null && !isAnonymous) {
        await _httpClient.post(
          Uri.parse("$_apiBaseUrl/auth/sign-out"),
          headers: {
            "Authorization": "Bearer $accessToken",
            "Accept": "application/json",
          },
        );
      }
    } catch (e) {
      debugPrint("Backend sign-out error: $e");
    } finally {
      // 2. Clear local state
      accessToken = null;
      currentUser = null;
      firebaseUid = null;
      // 3. Sign out from Firebase (works for both anonymous and regular users)
      await _auth.signOut();
    }
  }

  Future<void> deleteAccount() async {
    // Anonymous users cannot delete accounts (they don't have permanent accounts)
    if (isAnonymous) {
      throw Exception(
          'Anonymous users cannot delete accounts. Please create a permanent account first.');
    }

    try {
      if (accessToken != null) {
        final response = await _httpClient.post(
          Uri.parse("$_apiBaseUrl/user/delete"),
          headers: {
            "Authorization": "Bearer $accessToken",
            "Accept": "application/json",
          },
        );

        if (response.statusCode != 200) {
          throw Exception('Failed to delete account: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint("Account deletion error: $e");
      rethrow; // Propagate error so UI can show it
    } finally {
      // Always sign out locally after delete attempt (or if successful)
      // If the backend delete succeeded, the token is invalid anyway.
      // If it failed, we might want to keep the user logged in?
      // The requirement says "Deleting-account/sign-out should take the user to the auth screen when done."
      // I'll assume if it throws, we stay logged in (so user can retry).
      // But if it succeeds (no throw), we proceed to sign out.
    }
    // Only sign out if no error was thrown
    await signOut();
  }
}

class LastRoundSettings {
  /// List of selected category backend names (e.g. ['PLANET_EARTH', 'POP_CULTURE']),
  /// or null if none/all selected.
  final List<String>? categories;

  /// Difficulty setting: 'EASY' | 'MEDIUM' | 'HARD' | null
  final String? difficulty;

  const LastRoundSettings({
    required this.categories,
    required this.difficulty,
  });
}

class AuthUser {
  final String firebaseUid;
  final String? email;
  final String? displayName;
  final String? picture;
  final String subscriptionTier; // 'FREE' or 'PRO'

  const AuthUser({
    required this.firebaseUid,
    this.email,
    this.displayName,
    this.picture,
    this.subscriptionTier = 'FREE',
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      firebaseUid: json['firebase_uid'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      picture: json['picture'] as String?,
      subscriptionTier: json['subscription_tier'] as String? ?? 'FREE',
    );
  }
}
