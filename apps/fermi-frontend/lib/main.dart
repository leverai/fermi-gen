// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'dart:io' show Platform;
import 'package:fermi_frontend/firebase_options.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/services/dq_firestore.dart';
import 'package:fermi_frontend/services/deep_link_service.dart';
import 'package:fermi_frontend/services/preload_service.dart';
import 'package:fermi_frontend/screens/main/main_screen.dart';
import 'package:fermi_frontend/screens/lobby/lobby_screen_controller.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/screens/onboarding_screen.dart';
import 'package:fermi_frontend/screens/auth_screen.dart';
import 'package:fermi_frontend/screens/startup_auth_screen.dart';
import 'package:fermi_frontend/screens/daily_question/daily_question_screen.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/state/theme_config_service.dart';
import 'package:fermi_frontend/state/theme_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';

const bool useEmulators =
    bool.fromEnvironment('USE_EMULATORS', defaultValue: false);

final GlobalKey<ScaffoldMessengerState> _appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  // Catch configuration errors and display them to the user
  try {
    WidgetsFlutterBinding.ensureInitialized();
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
      final String emulatorHost = (!kIsWeb && Platform.isAndroid) ? '10.0.2.2' : 'localhost';
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
  late final ThemeConfigService _themeConfigService;
  late final DeepLinkService _deepLinkService;
  final AuthService _authService = AuthService();
  late final ApiService _apiService;
  late final PreloadService _preloadService;
  late final DailyQuestionService _dailyQuestionService;
  late final DQFirestoreService _dqFirestoreService;
  late final DailyQuestionController _dailyQuestionController;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _themeConfigService = ThemeConfigService();
    _themeConfigService.addListener(_onThemeChanged);
    _apiService = ApiService(authService: _authService);
    _dailyQuestionService = DailyQuestionService(api: _apiService);
    _dqFirestoreService = DQFirestoreService();
    _dailyQuestionController = DailyQuestionController(
      service: _dailyQuestionService,
      firestoreService: _dqFirestoreService,
    );
    _preloadService = PreloadService(api: _apiService, auth: _authService);
    _deepLinkService = DeepLinkService();
    _deepLinkService.init(
      onJoinGame: _handleJoinGame,
      onJoinDQ: _handleJoinDQ,
    );

    // Sign in anonymously early if no user exists
    _ensureAuthenticated();
  }

  /// Ensures user is authenticated (anonymous or regular).
  /// Starts preloading data once authentication is ready.
  Future<void> _ensureAuthenticated() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Sign in anonymously as early as possible
      final success = await _authService.signInAnonymously();
      if (success) {
        // signInAnonymously already calls exchangeToken internally,
        // so accessToken should be available now
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
      // Start preloading immediately
      _preloadService.preload();
    }
  }

  @override
  void dispose() {
    _themeConfigService.removeListener(_onThemeChanged);
    _themeConfigService.dispose();
    _deepLinkService.dispose();
    super.dispose();
  }

  Future<void> _handleJoinGame(String gameId) async {
    debugPrint('MyApp: Handling join game request for $gameId');

    // If not authenticated, we can't join yet.
    // The DeepLinkService stores the pending ID, and we'll check it after sign-in.
    if (_authService.currentUser == null) {
      debugPrint('MyApp: User not authenticated, redirecting to sign-in');
      _navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/sign-in', (route) => false);
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

      // Navigate to lobby
      if (!mounted) return;

      // We need a MainScreenController to build the realtime adapter.
      // Since we are at the app root, we might not have one handy.
      // However, LobbyScreenController expects one.
      // Ideally, we should navigate to MainScreen first, then push Lobby.
      // But for deep links, we want to go straight there if possible.
      // For now, let's instantiate a temporary controller just for the adapter factory
      // or refactor LobbyScreenController to not strictly need it if possible.
      // Actually, MainScreenController is just used for `buildRealtimeAdapter`.
      // We can replicate that logic here or make it static/shared.

      // Replicating logic for now to keep it simple:
      final realtime =
          MainScreenController(api: _apiService, auth: _authService)
              .buildRealtimeAdapter();

      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => LobbyScreenController(
            gameId: gameId,
            realtime: realtime,
            api: _apiService,
          ),
        ),
      );
    } catch (e) {
      debugPrint('MyApp: Failed to join game: $e');
      _appScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text('Failed to join game: $e')),
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
      _navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/sign-in', (route) => false);
      return;
    }

    // Ensure we have a valid token first
    if (_authService.accessToken == null) {
      await _authService.exchangeToken();
    }

    // Clear pending DQ date since we're handling it
    _deepLinkService.clearPendingDQDate();

    // Navigate to DailyQuestionScreen with the date
    // The screen itself handles edge cases (expired, not started, already participated)
    if (!mounted) return;

    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => DailyQuestionScreen(questionDate: questionDate),
      ),
    );
  }

  void _onThemeChanged() {
    setState(() {});
  }

  /// Determines the initial route based on onboarding status and auth state.
  /// Note: Anonymous authentication happens in initState, so user should exist by now.
  Future<String> _getInitialRoute() async {
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getBool('onboarding_seen') ?? false;

    // If onboarding hasn't been seen, show onboarding first
    if (!seen) {
      return '/onboarding';
    }

    // Check if user exists (anonymous or regular)
    // If not, fall back to sign-in screen (shouldn't happen if _ensureAuthenticated worked)
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      return '/main';
    }

    // Fallback: if anonymous sign-in failed in initState, show sign-in screen
    debugPrint('No user found, showing sign-in screen');
    return '/sign-in';
  }

  @override
  Widget build(BuildContext context) {
    final List<AuthProvider> providers = [
      EmailAuthProvider(),
      GoogleProvider(clientId: ''),
    ];
    final AppTheme appTheme = _themeConfigService.computeTheme();

    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: _authService),
        Provider<ApiService>.value(value: _apiService),
        ChangeNotifierProvider.value(value: _dailyQuestionController),
        Provider<DailyQuestionService>.value(value: _dailyQuestionService),
      ],
      child: ThemeConfigProvider(
        service: _themeConfigService,
        child: FutureBuilder<String>(
          future: _getInitialRoute(),
          builder: (context, snapshot) {
            // Show loading while determining initial route
            if (!snapshot.hasData) {
              return const MaterialApp(
                debugShowCheckedModeBanner: false,
                home: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final app = MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: _navigatorKey,
              scaffoldMessengerKey: _appScaffoldMessengerKey,
              theme: ThemeData(
                extensions: <ThemeExtension<dynamic>>[
                  appTheme,
                  const AppFont(),
                ],
              ),
              initialRoute: snapshot.data!,
              routes: {
                '/sign-in': (context) {
                  return AuthScreen(
                    providers: providers,
                    actions: [
                      AuthStateChangeAction<UserCreated>(
                          (context, state) async {
                        final ok = await _authService.exchangeToken();
                        if (!context.mounted) return;
                        if (ok) {
                          // Onboarding is shown before auth, so user has already seen it
                          // Ensure we mark it as seen now that they have signed in
                          SharedPreferences.getInstance().then((prefs) =>
                              prefs.setBool('onboarding_seen', true));
                          Navigator.pushReplacementNamed(context, '/main');
                          // Check for deep link join
                          _checkPendingJoin();
                        } else {
                          _appScaffoldMessengerKey.currentState?.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Sign-in succeeded but token exchange failed.'),
                            ),
                          );
                        }
                      }),
                      AuthStateChangeAction<SignedIn>((context, state) async {
                        // Check if user was anonymous and is now signing in with a provider
                        // Firebase UI Auth should handle linking automatically
                        final ok = await _authService.exchangeToken();
                        if (!context.mounted) return;
                        if (ok) {
                          SharedPreferences.getInstance().then((prefs) =>
                              prefs.setBool('onboarding_seen', true));
                          Navigator.pushReplacementNamed(context, '/main');
                          // Check for pending deep link join
                          _checkPendingJoin();
                        } else {
                          _appScaffoldMessengerKey.currentState?.showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Sign-in succeeded but token exchange failed.'),
                            ),
                          );
                        }
                      }),
                      // Handle credential linking when anonymous user signs in from sign-in screen
                      AuthStateChangeAction<CredentialLinked>(
                        (context, state) async {
                          final ok = await _authService.exchangeToken();
                          if (!context.mounted) return;
                          if (ok) {
                            _appScaffoldMessengerKey.currentState?.showSnackBar(
                              const SnackBar(
                                content: Text('Account created successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );

                            SharedPreferences.getInstance().then((prefs) =>
                                prefs.setBool('onboarding_seen', true));
                            Navigator.pushReplacementNamed(context, '/main');
                            _checkPendingJoin();
                          } else {
                            _appScaffoldMessengerKey.currentState?.showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Account linking succeeded but token exchange failed.'),
                              ),
                            );
                          }
                        },
                      ),
                      AuthStateChangeAction<AuthFailed>((context, state) {
                        debugPrint('Auth error: ${state.exception}');
                      }),
                    ],
                  );
                },
                '/startup-auth': (context) => const StartupAuthScreen(),
                '/onboarding': (context) => OnboardingScreen(
                      preloadService: _preloadService,
                    ),
                '/onboarding-test': (context) {
                  // Quick and dirty bypass for testing - clears the flag on entry
                  // and uses testMode to prevent setting it on exit
                  SharedPreferences.getInstance().then((prefs) {
                    prefs.setBool('onboarding_seen', false);
                  });
                  return OnboardingScreen(
                    testMode: true,
                    preloadService: _preloadService,
                  );
                },
                '/profile': (context) {
                  return ProfileScreen(
                    providers: providers,
                    actions: [
                      SignedOutAction((context) {
                        Navigator.pushReplacementNamed(context, '/sign-in');
                      }),
                    ],
                  );
                },
                '/upgrade-account': (context) {
                  return AuthScreen(
                    providers: providers,
                    actions: [
                      // Handle credential linking when anonymous user signs in
                      AuthStateChangeAction<CredentialLinked>(
                        (context, state) async {
                          // Credential has been linked, exchange token to get updated user info
                          final ok = await _authService.exchangeToken();
                          if (!context.mounted) return;
                          if (ok) {
                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account created successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                            // Navigate back to main screen
                            Navigator.of(context).pop();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Account linking succeeded but token exchange failed.'),
                              ),
                            );
                          }
                        },
                      ),
                      // Also handle regular sign-in (in case user already has account)
                      AuthStateChangeAction<SignedIn>(
                        (context, state) async {
                          // If user signs in with existing account, try to link
                          // This handles the case where anonymous user signs in with email/Google
                          final user = FirebaseAuth.instance.currentUser;
                          if (user != null && user.isAnonymous) {
                            // This shouldn't happen if linking worked, but handle gracefully
                            debugPrint('User is still anonymous after sign-in');
                          } else {
                            // User signed in successfully, exchange token
                            final ok = await _authService.exchangeToken();
                            if (!context.mounted) return;
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Account created successfully!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              Navigator.of(context).pop();
                            }
                          }
                        },
                      ),
                      AuthStateChangeAction<AuthFailed>(
                        (context, state) {
                          final exception = state.exception;
                          String errorMessage = 'Failed to create account.';

                          if (exception is FirebaseAuthException) {
                            switch (exception.code) {
                              case 'email-already-in-use':
                                errorMessage =
                                    'This email is already associated with another account.';
                                break;
                              case 'account-exists-with-different-credential':
                                errorMessage =
                                    'An account already exists with this email but different sign-in method.';
                                break;
                              case 'invalid-credential':
                                errorMessage =
                                    'Invalid credentials. Please try again.';
                                break;
                              default:
                                errorMessage =
                                    'Error: ${exception.message ?? exception.code}';
                            }
                          }

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(errorMessage),
                              backgroundColor: Colors.red,
                            ),
                          );
                        },
                      ),
                    ],
                    onLeave: () => Navigator.of(context).pop(),
                  );
                },
                '/main': (context) {
                  return FutureBuilder<bool>(
                    future: _authService.accessToken != null
                        ? Future<bool>.value(true)
                        : _authService.exchangeToken(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (snapshot.data == true) {
                        return MainScreen(
                          apiService: _apiService,
                          authService: _authService,
                          preloadService: _preloadService,
                          dailyQuestionService: _dailyQuestionService,
                        );
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _appScaffoldMessengerKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Authentication required. Please sign in again.'),
                          ),
                        );
                        Navigator.pushReplacementNamed(context, '/sign-in');
                      });
                      return const SizedBox.shrink();
                    },
                  );
                },
              },
            );
            return app;
          },
        ),
      ),
    );
  }
}
