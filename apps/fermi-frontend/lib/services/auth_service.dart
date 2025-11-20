import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fermi_frontend/utils/env.dart';

class AuthService {
  final FirebaseAuth _auth;
  final http.Client _httpClient;
  late final String _apiBaseUrl = resolveApiBaseUrlOrThrow();
  String? accessToken;
  String? firebaseUid;
  AuthUser? currentUser;
  String? locale; // 'US' or 'EU'
  LastRoundSettings? lastRoundSettings;
  bool shouldRefreshStats = false;

  /// Creates an AuthService instance.
  ///
  /// Parameters [auth] and [httpClient] are optional for testing purposes.
  /// By default, uses [FirebaseAuth.instance] and a new [http.Client].
  AuthService({
    FirebaseAuth? auth,
    http.Client? httpClient,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _httpClient = httpClient ?? http.Client();

  Future<bool> exchangeToken() async {
    try {
      final user = _auth.currentUser;

      if (user != null) {
        // 1. Get Firebase ID token
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
}

class LastRoundSettings {
  final String? category; // Backend enum name, e.g. 'PLANET_EARTH' or 'GENERAL'
  final String? difficulty; // 'EASY' | 'MEDIUM' | 'HARD' | null
  final bool
      isPrivate; // true for private (create), false for public (join random)

  const LastRoundSettings({
    required this.category,
    required this.difficulty,
    required this.isPrivate,
  });
}

class AuthUser {
  final String firebaseUid;
  final String? email;
  final String? displayName;
  final String? picture;

  const AuthUser({
    required this.firebaseUid,
    this.email,
    this.displayName,
    this.picture,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      firebaseUid: json['firebase_uid'] as String,
      email: json['email'] as String?,
      displayName: json['display_name'] as String?,
      picture: json['picture'] as String?,
    );
  }
}
