// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:ui' show PlatformDispatcher;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart'
    show ErrorText, localizedErrorText;
import 'package:firebase_ui_localizations/firebase_ui_localizations.dart';
import 'dart:io' show Platform;
import 'package:fermi_frontend/firebase_options.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/auth_state_notifier.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/services/dq_firestore.dart';
import 'package:fermi_frontend/services/deep_link_service.dart';
import 'package:fermi_frontend/services/preload_service.dart';
import 'package:fermi_frontend/services/subscription_service.dart';
import 'package:fermi_frontend/services/local_settings_service.dart';
import 'package:fermi_frontend/services/feedback_service.dart';
import 'package:fermi_frontend/services/notification_service.dart';
import 'package:fermi_frontend/services/ad_service.dart';
import 'package:fermi_frontend/services/rate_app_service.dart';
import 'package:fermi_frontend/providers/subscription_provider.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/routing/app_router.dart';

const bool useEmulators =
    bool.fromEnvironment('USE_EMULATORS', defaultValue: false);

final GlobalKey<ScaffoldMessengerState> _appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  // Catch configuration errors and display them to the user
  try {
    WidgetsFlutterBinding.ensureInitialized();

    // Global error handlers to prevent uncaught exceptions from crashing
    // the app (especially during cold start on Android).
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      debugPrint('FlutterError: ${details.exception}');
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('PlatformDispatcher error: $error');
      debugPrint('$stack');
      return true; // Prevent crash
    };

    // Customize firebase_ui_auth error messages.
    // iOS wraps password-does-not-meet-requirements in a generic
    // "internal error" message, so we intercept that code here.
    ErrorText.localizeError = (context, e) {
      if (e.code == 'password-does-not-meet-requirements') {
        return 'Password must contain at least: an uppercase letter, '
            'a lowercase letter, a number, and a special character. '
            'Minimum length: 8 characters.';
      }
      final labels = FirebaseUILocalizations.labelsOf(context);
      return localizedErrorText(e.code, labels) ??
          e.message ??
          labels.unknownError;
    };

    final FirebaseOptions base = DefaultFirebaseOptions.currentPlatform;
    final FirebaseOptions initOptions = useEmulators
        ? FirebaseOptions(
            apiKey: base.apiKey,
            appId: base.appId,
            messagingSenderId: base.messagingSenderId,
            projectId: 'fermi-local',
            storageBucket: base.storageBucket,
          )
        : base;
    await Firebase.initializeApp(options: initOptions);

    // Initialize local settings early
    await LocalSettingsService.instance.initialize();

    // Initialize feedback service (audio pool)
    await FeedbackService.instance.initialize();

    // Initialize rate-the-app service (session tracking)
    await RateAppService.instance.initialize();

    // Initialize push notifications (Android only)
    await NotificationService.instance.initialize();

    // Initialize Unity Ads (non-blocking)
    AdService.instance.init();

    if (useEmulators) {
      const String configuredAuthHost =
          String.fromEnvironment('FIREBASE_AUTH_EMULATOR_HOST');
      const String configuredFsHost =
          String.fromEnvironment('FIRESTORE_EMULATOR_HOST');
      if (configuredAuthHost.isEmpty || configuredFsHost.isEmpty) {
        throw StateError(
            'Missing required dart-defines: FIREBASE_AUTH_EMULATOR_HOST and/or FIRESTORE_EMULATOR_HOST');
      }
      // On web, Platform.isAndroid is not available, so check kIsWeb first
      final String emulatorHost =
          (!kIsWeb && Platform.isAndroid) ? '10.0.2.2' : 'localhost';
      final int fsPort = int.tryParse(configuredFsHost.split(':').last) ?? 8080;
      final int authPort =
          int.tryParse(configuredAuthHost.split(':').last) ?? 9099;
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, fsPort);
      FirebaseAuth.instance.useAuthEmulator(emulatorHost, authPort);
    }

    runApp(const MyApp());
  } catch (e, stackTrace) {
    // Log error for debugging (works in release builds)
    print('❌ Fatal error during app initialization:');
    print(e);
    print(stackTrace);

    // Show error UI instead of blank screen
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.red.shade900,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.white, size: 64),
                  const SizedBox(height: 24),
                  const Text(
                    'App Configuration Error',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    e.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Please contact support or check the app logs for more details.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final DeepLinkService _deepLinkService;
  late final Future<void> _deepLinkInitialization;
  late final AuthService _authService;
  late final AuthStateNotifier _authStateNotifier;
  late final SubscriptionService _subscriptionService;
  late final SubscriptionProvider _subscriptionProvider;
  late final ApiService _apiService;
  late final PreloadService _preloadService;
  late final DailyQuestionService _dailyQuestionService;
  late final DQFirestoreService _dqFirestoreService;
  late final DailyQuestionController _dailyQuestionController;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  late final AppRouter _appRouter;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _authStateNotifier = AuthStateNotifier();

    // Restore persisted auth state (access token, user info) from disk
    // so cold starts don't require a network call.
    _authService.restorePersistedState().then((_) {
      _finishInit();
    });
  }

  /// Complete initialization after persisted auth state is restored.
  void _finishInit() {
    _subscriptionService = SubscriptionService();
    _subscriptionService.initialize(); // Initialize RevenueCat early
    _subscriptionProvider = SubscriptionProvider(_subscriptionService);
    _apiService = ApiService(authService: _authService);
    _dailyQuestionService = DailyQuestionService(api: _apiService);
    _dqFirestoreService = DQFirestoreService();
    _dailyQuestionController = DailyQuestionController(
      service: _dailyQuestionService,
      firestoreService: _dqFirestoreService,
    );
    _dailyQuestionController.initialize();
    _preloadService = PreloadService(api: _apiService, auth: _authService);
    _deepLinkService = DeepLinkService();
    _appRouter = AppRouter(
      authService: _authService,
      authStateNotifier: _authStateNotifier,
      apiService: _apiService,
      preloadService: _preloadService,
      dailyQuestionService: _dailyQuestionService,
      subscriptionService: _subscriptionService,
      navigatorKey: _navigatorKey,
      scaffoldMessengerKey: _appScaffoldMessengerKey,
      onCheckPendingJoin: () => _checkPendingJoin,
      canShowFeatureAnnouncements: _canShowFeatureAnnouncements,
    );
    _deepLinkInitialization = _deepLinkService.init(
      onJoinGame: _handleJoinGame,
      onJoinDQ: _handleJoinDQ,
    );

    // Sign in anonymously early if no user exists
    _ensureAuthenticated();

    // Mark as initialized and trigger rebuild
    _initialized = true;
    if (mounted) setState(() {});
  }

  Future<bool> _canShowFeatureAnnouncements() async {
    await _deepLinkInitialization;
    return _deepLinkService.pendingGameId == null &&
        _deepLinkService.pendingDQDate == null;
  }

  /// Ensures user is authenticated (anonymous or regular).
  /// Syncs RevenueCat with the Firebase UID and starts preloading data.
  Future<void> _ensureAuthenticated() async {
    try {
      await _ensureAuthenticatedInner();
    } catch (e) {
      debugPrint('_ensureAuthenticated failed (non-fatal): $e');
    }
  }

  Future<void> _ensureAuthenticatedInner() async {
    final currentUser = await FirebaseAuth.instance.authStateChanges().first;
    if (currentUser == null) {
      // Sign in anonymously as early as possible
      final success = await _authService.signInAnonymously();
      if (success) {
        // signInAnonymously already calls exchangeToken internally,
        // so accessToken should be available now
        // Sync user ID with RevenueCat
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _subscriptionService.login(user.uid);
          await _subscriptionProvider.refresh();
        }
        // Start preloading data in the background
        _preloadService.preload();
      } else {
        // Check if user was created despite token exchange failure
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Anonymous sign-in succeeded but token exchange failed
          // User can still use the app, so preload data
          debugPrint(
              'Anonymous sign-in succeeded but token exchange failed. User can still use the app.');
          await _subscriptionService.login(user.uid);
          await _subscriptionProvider.refresh();
          _preloadService.preload();
        } else {
          // Actual sign-in failure
          debugPrint('Failed to sign in anonymously during app initialization');
        }
      }
    } else {
      // User already exists, ensure we have a token
      if (_authService.accessToken == null) {
        await _authService.exchangeToken();
      }
      // Sync user ID with RevenueCat
      await _subscriptionService.login(currentUser.uid);
      await _subscriptionProvider.refresh();
      // Start preloading immediately
      _preloadService.preload();
    }
  }

  @override
  void dispose() {
    _deepLinkService.dispose();
    super.dispose();
  }

  Future<void> _handleJoinGame(String gameId) async {
    debugPrint('MyApp: Handling join game request for $gameId');

    // If not authenticated, we can't join yet.
    // The DeepLinkService stores the pending ID, and we'll check it after sign-in.
    if (_authService.currentUser == null) {
      debugPrint('MyApp: User not authenticated, redirecting to sign-in');
      _appRouter.router.go('/sign-in');
      return;
    }

    // If authenticated, try to join immediately
    try {
      // Ensure we have a valid token first
      if (_authService.accessToken == null) {
        await _authService.exchangeToken();
      }

      // Show loading indicator (optional, but good UX)
      _appScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Joining game...')),
      );

      await _apiService.joinGame(gameId: gameId);

      // Clear pending ID since we succeeded
      _deepLinkService.clearPendingGameId();

      // Navigate to lobby using go_router
      _appRouter.router.go('/lobby/$gameId');
    } catch (e) {
      debugPrint('MyApp: Failed to join game: $e');
      // Provide friendly error messages for common join failures
      String message;
      final errorStr = e.toString();
      if (errorStr.contains('Game is full')) {
        message = 'This game is full. Ask the host for a new invite!';
      } else if (errorStr.contains('not found') || errorStr.contains('404')) {
        message = 'Game not found. The invite link may have expired.';
      } else if (errorStr.contains('already started') ||
          errorStr.contains('Game has already')) {
        message = 'This game has already started.';
      } else {
        message = 'Failed to join game. Please try again.';
      }
      _appScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _checkPendingJoin() async {
    final pendingId = _deepLinkService.pendingGameId;
    if (pendingId != null) {
      debugPrint('MyApp: Found pending game join: $pendingId');
      await _handleJoinGame(pendingId);
    }

    // Also check for pending DQ join
    final pendingDQDate = _deepLinkService.pendingDQDate;
    if (pendingDQDate != null) {
      debugPrint('MyApp: Found pending DQ join: $pendingDQDate');
      await _handleJoinDQ(pendingDQDate);
    }
  }

  /// Handle DQ invite deep links.
  /// Navigates to the DailyQuestionScreen with the specified date.
  Future<void> _handleJoinDQ(String questionDate) async {
    debugPrint('MyApp: Handling join DQ request for $questionDate');

    // If not authenticated, we can't navigate yet.
    // The DeepLinkService stores the pending date for after auth.
    if (_authService.currentUser == null) {
      debugPrint('MyApp: User not authenticated, redirecting to sign-in');
      _appRouter.router.go('/sign-in');
      return;
    }

    // Ensure we have a valid token first
    if (_authService.accessToken == null) {
      await _authService.exchangeToken();
    }

    // Clear pending DQ date since we're handling it
    _deepLinkService.clearPendingDQDate();

    // Navigate to DailyQuestionScreen using go_router
    _appRouter.router.go('/dq/$questionDate');
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while persisted auth state is being restored
    if (!_initialized) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: _authService),
        Provider<ApiService>.value(value: _apiService),
        Provider<PreloadService>.value(value: _preloadService),
        Provider<SubscriptionService>.value(value: _subscriptionService),
        ChangeNotifierProvider.value(value: _subscriptionProvider),
        ChangeNotifierProvider.value(value: _dailyQuestionController),
        Provider<DailyQuestionService>.value(value: _dailyQuestionService),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: LocalSettingsService.instance.themeMode,
        builder: (context, themeMode, _) {
          return MaterialApp.router(
            debugShowCheckedModeBanner: false,
            scaffoldMessengerKey: _appScaffoldMessengerKey,
            themeMode: themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              extensions: <ThemeExtension<dynamic>>[
                AppTheme.lightTheme(),
                const AppFont(),
              ],
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              extensions: <ThemeExtension<dynamic>>[
                AppTheme.defaultTheme(),
                const AppFont(),
              ],
            ),
            routerConfig: _appRouter.router,
          );
        },
      ),
    );
  }
}
