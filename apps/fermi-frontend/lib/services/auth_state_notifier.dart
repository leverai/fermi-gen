import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Notifier that tracks Firebase Auth state changes and when auth has "settled".
///
/// On app startup/hot-restart, Firebase Auth restores persisted state asynchronously.
/// This notifier listens to auth state changes and tracks when the first emission
/// is received, indicating that auth state has been restored.
///
/// Used as GoRouter's refreshListenable to ensure routing decisions wait for
/// auth state to be available.
class AuthStateNotifier extends ChangeNotifier {
  bool _isSettled = false;

  /// Whether auth state has been restored (first emission received).
  bool get isSettled => _isSettled;

  AuthStateNotifier() {
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      // Mark as settled after first emission
      if (!_isSettled) {
        _isSettled = true;
      }
      // Notify listeners so GoRouter can re-evaluate routes
      notifyListeners();
    });
  }
}
