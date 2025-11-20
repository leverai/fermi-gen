import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  // Store a pending game ID if the user needs to sign in first
  String? _pendingGameId;

  String? get pendingGameId => _pendingGameId;

  void clearPendingGameId() {
    _pendingGameId = null;
  }

  // Initialize and listen for deep links
  void init({required Function(String gameId) onJoinGame}) {
    // Check initial link (if app was launched via link)
    _checkInitialLink(onJoinGame);

    // Listen for subsequent links (while app is running)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri, onJoinGame);
    }, onError: (err) {
      debugPrint('DeepLinkService: Error processing link: $err');
    });
  }

  Future<void> _checkInitialLink(Function(String gameId) onJoinGame) async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        _handleLink(uri, onJoinGame);
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error getting initial link: $e');
    }
  }

  void _handleLink(Uri uri, Function(String gameId) onJoinGame) {
    debugPrint('DeepLinkService: Received link: $uri');

    // Expected format: guesstimate://invite/<game_id>
    if (uri.scheme == 'guesstimate' && uri.host == 'invite') {
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
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
