import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fermi_frontend/firebase_options.dart';

/// Default emulator host configuration.
///
/// On Android emulators, use '10.0.2.2' to access localhost.
/// On other platforms, use 'localhost' or '127.0.0.1'.
const String defaultEmulatorHost = 'localhost';

/// Default Firestore emulator port.
const int defaultFirestorePort = 8080;

/// Default Auth emulator port.
const int defaultAuthPort = 9099;

/// Configures Firebase services to use local emulators.
///
/// This function should be called in `setUpAll()` for integration tests.
/// It configures both FirebaseAuth and FirebaseFirestore to connect to
/// the local emulators.
///
/// The emulator host is automatically detected based on the platform:
/// - Android: '10.0.2.2' (to access host machine's localhost)
/// - Other platforms: 'localhost'
///
/// Ports can be customized via parameters, but default to:
/// - Firestore: 8080
/// - Auth: 9099
///
/// Example:
/// ```dart
/// void main() {
///   setUpAll(() async {
///     await setupFirebaseEmulators();
///   });
///   // ... tests
/// }
/// ```
Future<void> setupFirebaseEmulators({
  String? host,
  int? firestorePort,
  int? authPort,
}) async {
  // Initialize Firebase if not already initialized
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase may already be initialized, which is fine
    if (e.toString().contains('already been initialized')) {
      // Ignore
    } else {
      rethrow;
    }
  }

  // Determine emulator host based on platform
  final String emulatorHost = host ??
      (Platform.isAndroid ? '10.0.2.2' : defaultEmulatorHost);
  final int fsPort = firestorePort ?? defaultFirestorePort;
  final int authPortValue = authPort ?? defaultAuthPort;

  // Configure Firestore emulator
  FirebaseFirestore.instance.useFirestoreEmulator(
    emulatorHost,
    fsPort,
    sslEnabled: false,
  );

  // Configure Auth emulator
  await FirebaseAuth.instance.useAuthEmulator(
    emulatorHost,
    authPortValue,
  );
}

/// Cleans up Firebase emulator data between tests.
///
/// This function can be called in `tearDown()` or `setUp()` to ensure
/// test isolation. Note that the Firebase emulator suite provides a
/// REST API for clearing data, but for simplicity, this function
/// signs out any authenticated users.
///
/// For more thorough cleanup, you may need to call the emulator's
/// REST API directly or use the Firebase Admin SDK.
///
/// Example:
/// ```dart
/// tearDown(() async {
///   await cleanupFirebaseEmulator();
/// });
/// ```
Future<void> cleanupFirebaseEmulator() async {
  // Sign out any authenticated users
  await FirebaseAuth.instance.signOut();

  // Note: Firestore data cleanup would require calling the emulator's
  // REST API or using Firebase Admin SDK. For now, we rely on test
  // isolation through unique game IDs and user IDs.
}

/// Helper to create a test user in the Auth emulator.
///
/// This is useful for integration tests that need an authenticated user.
/// The user is created with email/password and automatically signed in.
///
/// Example:
/// ```dart
/// final user = await createTestUser(
///   email: 'test@example.com',
///   password: 'password123',
/// );
/// ```
Future<UserCredential> createTestUser({
  required String email,
  required String password,
  String? displayName,
}) async {
  // Create user
  final credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
    email: email,
    password: password,
  );

  // Update display name if provided
  if (displayName != null && credential.user != null) {
    await credential.user!.updateDisplayName(displayName);
    await credential.user!.reload();
  }

  return credential;
}

/// Helper to sign in a test user in the Auth emulator.
///
/// This is useful for integration tests that need to authenticate
/// an existing user.
///
/// Example:
/// ```dart
/// await signInTestUser(
///   email: 'test@example.com',
///   password: 'password123',
/// );
/// ```
Future<UserCredential> signInTestUser({
  required String email,
  required String password,
}) async {
  return await FirebaseAuth.instance.signInWithEmailAndPassword(
    email: email,
    password: password,
  );
}
