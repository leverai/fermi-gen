import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Store pending IDs if the user needs to sign in first
  String? _pendingGameId;
  String? _pendingDQDate;

  String? get pendingGameId => _pendingGameId;
  String? get pendingDQDate => _pendingDQDate;

  void clearPendingGameId() {
    _pendingGameId = null;
  }

  void clearPendingDQDate() {
    _pendingDQDate = null;
  }

  /// Initialize and listen for deep links.
  ///
  /// - [onJoinGame]: Called when a game invite link is received (guesstimate://invite/{game_id})
  /// - [onJoinDQ]: Called when a DQ invite link is received (guesstimate://dq/{date})
  void init({
    required Function(String gameId) onJoinGame,
    required Function(String questionDate) onJoinDQ,
  }) {
    // On web, check the current URL path for deep links
    if (kIsWeb) {
      _checkWebInitialUrl(onJoinGame, onJoinDQ);
    } else {
      // Check initial link (if app was launched via link)
      _checkInitialLink(onJoinGame, onJoinDQ);
    }

    // Listen for subsequent links (while app is running)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      debugPrint('DeepLinkService: Stream received URI: $uri');
      // On web, filter out internal app routes from hash-based routing
      if (kIsWeb) {
        final pathToCheck = uri.fragment.isNotEmpty ? uri.fragment : uri.path;
        if (!pathToCheck.contains('/dq/') &&
            !pathToCheck.contains('/invite/')) {
          debugPrint(
              'DeepLinkService: Ignoring non-deep-link stream URL: $uri');
          return;
        }
        // If using hash routing, parse the fragment as a path
        if (uri.fragment.isNotEmpty && uri.fragment.startsWith('/')) {
          final fragmentUri = Uri.parse('http://${uri.host}${uri.fragment}');
          _handleLink(fragmentUri, onJoinGame, onJoinDQ);
          return;
        }
      }
      _handleLink(uri, onJoinGame, onJoinDQ);
    }, onError: (err) {
      debugPrint('DeepLinkService: Error processing link: $err');
    });
  }

  Future<void> _checkInitialLink(
    Function(String gameId) onJoinGame,
    Function(String questionDate) onJoinDQ,
  ) async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleLink(uri, onJoinGame, onJoinDQ);
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error getting initial link: $e');
    }
  }

  /// Check the current web URL for deep link patterns.
  /// This is called on web platform initialization to handle direct URL navigation.
  void _checkWebInitialUrl(
    Function(String gameId) onJoinGame,
    Function(String questionDate) onJoinDQ,
  ) {
    try {
      // On web, we can use Uri.base to get the current URL
      final uri = Uri.base;
      debugPrint('DeepLinkService: Checking web initial URL: $uri');

      // Only process if it's our domain
      if (uri.host == 'guesstimate.leverai.tech' ||
          uri.host == 'localhost' ||
          uri.host.isEmpty) {
        // Check if the URL contains deep link patterns before processing
        // For web, the path could be in the fragment (hash routing: /#/dq/2025-01-01)
        // or in the actual path (/dq/2025-01-01)
        final pathToCheck = uri.fragment.isNotEmpty ? uri.fragment : uri.path;

        // Only process if it looks like a deep link (contains /dq/ or /invite/)
        // This prevents treating internal app routes like #/main as deep links
        if (pathToCheck.contains('/dq/') || pathToCheck.contains('/invite/')) {
          // If using hash routing, parse the fragment as a path
          if (uri.fragment.isNotEmpty && uri.fragment.startsWith('/')) {
            final fragmentUri = Uri.parse('http://${uri.host}${uri.fragment}');
            _handleLink(fragmentUri, onJoinGame, onJoinDQ);
          } else {
            _handleLink(uri, onJoinGame, onJoinDQ);
          }
        } else {
          debugPrint('DeepLinkService: Ignoring non-deep-link URL: $uri');
        }
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error checking web initial URL: $e');
    }
  }

  void _handleLink(
    Uri uri,
    Function(String gameId) onJoinGame,
    Function(String questionDate) onJoinDQ,
  ) {
    debugPrint('DeepLinkService: Received link: $uri');

    // Handle custom scheme: guesstimate://invite/<game_id> or guesstimate://dq/<date>
    if (uri.scheme == 'guesstimate') {
      // Game invite: guesstimate://invite/<game_id>
      if (uri.host == 'invite') {
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final gameId = pathSegments.first;
          debugPrint('DeepLinkService: Extracted game ID: $gameId');

          // Store it just in case we need it later (e.g. after auth)
          _pendingGameId = gameId;

          // Trigger the callback
          onJoinGame(gameId);
        }
      }

      // DQ invite: guesstimate://dq/<date>
      if (uri.host == 'dq') {
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          final questionDate = pathSegments.first;
          debugPrint('DeepLinkService: Extracted DQ date: $questionDate');

          // Store it just in case we need it later (e.g. after auth)
          _pendingDQDate = questionDate;

          // Trigger the callback
          onJoinDQ(questionDate);
        }
      }
      return;
    }

    // Handle HTTPS URLs: https://guesstimate.leverai.tech/invite/game/<game_id>
    // or https://guesstimate.leverai.tech/dq/<date>
    if (uri.scheme == 'https' && uri.host == 'guesstimate.leverai.tech') {
      final pathSegments = uri.pathSegments;

      // Game invite: /invite/game/<game_id>
      if (pathSegments.length >= 2 &&
          pathSegments[0] == 'invite' &&
          pathSegments[1] == 'game') {
        if (pathSegments.length >= 3) {
          final gameId = pathSegments[2];
          debugPrint('DeepLinkService: Extracted game ID from HTTPS: $gameId');

          // Store it just in case we need it later (e.g. after auth)
          _pendingGameId = gameId;

          // Trigger the callback
          onJoinGame(gameId);
        }
      }

      // DQ invite: /dq/<date>
      if (pathSegments.length >= 2 && pathSegments[0] == 'dq') {
        final questionDate = pathSegments[1];
        debugPrint(
            'DeepLinkService: Extracted DQ date from HTTPS: $questionDate');

        // Store it just in case we need it later (e.g. after auth)
        _pendingDQDate = questionDate;

        // Trigger the callback
        onJoinDQ(questionDate);
      }
      return;
    }

    // Handle ChottuLink URLs: https://guesstimate.chottu.link/party?id=<game_id>
    // or https://guesstimate.chottu.link/dq?date=<date>
    if (uri.scheme == 'https' && uri.host == 'guesstimate.chottu.link') {
      final pathSegments = uri.pathSegments;
      final queryParams = uri.queryParameters;

      // Party invite: /party?id=<game_id>
      if (pathSegments.isNotEmpty && pathSegments[0] == 'party') {
        final gameId = queryParams['id'];
        if (gameId != null && gameId.isNotEmpty) {
          debugPrint(
              'DeepLinkService: Extracted game ID from ChottuLink: $gameId');
          _pendingGameId = gameId;
          onJoinGame(gameId);
        }
      }

      // DQ invite: /dq?date=<date>
      if (pathSegments.isNotEmpty && pathSegments[0] == 'dq') {
        final questionDate = queryParams['date'];
        if (questionDate != null && questionDate.isNotEmpty) {
          debugPrint(
              'DeepLinkService: Extracted DQ date from ChottuLink: $questionDate');
          _pendingDQDate = questionDate;
          onJoinDQ(questionDate);
        }
      }
      return;
    }

    // Handle HTTP URLs for local development: http://localhost/invite/game/<game_id>
    // or http://localhost/dq/<date>
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        (uri.host == 'localhost' || uri.host.isEmpty)) {
      final pathSegments = uri.pathSegments;

      // Game invite: /invite/game/<game_id>
      if (pathSegments.length >= 2 &&
          pathSegments[0] == 'invite' &&
          pathSegments[1] == 'game') {
        if (pathSegments.length >= 3) {
          final gameId = pathSegments[2];
          debugPrint(
              'DeepLinkService: Extracted game ID from localhost: $gameId');

          // Store it just in case we need it later (e.g. after auth)
          _pendingGameId = gameId;

          // Trigger the callback
          onJoinGame(gameId);
        }
      }

      // DQ invite: /dq/<date>
      if (pathSegments.isNotEmpty && pathSegments[0] == 'dq') {
        if (pathSegments.length >= 2) {
          final questionDate = pathSegments[1];
          debugPrint(
              'DeepLinkService: Extracted DQ date from localhost: $questionDate');

          // Store it just in case we need it later (e.g. after auth)
          _pendingDQDate = questionDate;

          // Trigger the callback
          onJoinDQ(questionDate);
        }
      }
    }
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
