import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'dart:io' show Platform;
import 'package:fermi_frontend/firebase_options.dart';
import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/deep_link_service.dart';
import 'package:fermi_frontend/screens/main/main_screen.dart';
import 'package:fermi_frontend/screens/lobby/lobby_screen_controller.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/screens/onboarding_screen.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/state/theme_config_service.dart';
import 'package:fermi_frontend/state/theme_config_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const bool useEmulators =
    bool.fromEnvironment('USE_EMULATORS', defaultValue: false);

final GlobalKey<ScaffoldMessengerState> _appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
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
    final String emulatorHost = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    final int fsPort = int.tryParse(configuredFsHost.split(':').last) ?? 8080;
    final int authPort =
        int.tryParse(configuredAuthHost.split(':').last) ?? 9099;
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, fsPort);
    FirebaseAuth.instance.useAuthEmulator(emulatorHost, authPort);
  }

  runApp(const MyApp());
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
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _themeConfigService = ThemeConfigService();
    _themeConfigService.addListener(_onThemeChanged);
    _apiService = ApiService(authService: _authService);
    _deepLinkService = DeepLinkService();
    _deepLinkService.init(onJoinGame: _handleJoinGame);
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
      _navigatorKey.currentState?.pushNamedAndRemoveUntil('/sign-in', (route) => false);
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
      final realtime = MainScreenController(api: _apiService, auth: _authService).buildRealtimeAdapter();

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
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final providers = [EmailAuthProvider()];
    final AppTheme appTheme = _themeConfigService.computeTheme();

    return ThemeConfigProvider(
      service: _themeConfigService,
      child: MaterialApp(
        navigatorKey: _navigatorKey,
        scaffoldMessengerKey: _appScaffoldMessengerKey,
        theme: ThemeData(
          extensions: <ThemeExtension<dynamic>>[
            appTheme,
            const AppFont(),
          ],
        ),
      initialRoute:
          FirebaseAuth.instance.currentUser == null ? '/sign-in' : '/main',
      routes: {
        '/sign-in': (context) {
          return SignInScreen(
            providers: providers,
            actions: [
              AuthStateChangeAction<UserCreated>((context, state) async {
                final ok = await _authService.exchangeToken();
                if (!context.mounted) return;
                if (ok) {
                  // Check if user has seen onboarding
                  final prefs = await SharedPreferences.getInstance();
                  final seen = prefs.getBool('onboarding_seen') ?? false;
                  if (!context.mounted) return;
                  if (!seen) {
                    Navigator.pushReplacementNamed(context, '/onboarding');
                  } else {
                    Navigator.pushReplacementNamed(context, '/main');
                    // Check for pending deep link join
                    _checkPendingJoin();
                  }
                } else {
                  _appScaffoldMessengerKey.currentState?.showSnackBar(
                    const SnackBar(
                      content:
                          Text('Sign-in succeeded but token exchange failed.'),
                    ),
                  );
                }
              }),
              AuthStateChangeAction<SignedIn>((context, state) async {
                final ok = await _authService.exchangeToken();
                if (!context.mounted) return;
                if (ok) {
                  Navigator.pushReplacementNamed(context, '/main');
                  // Check for pending deep link join
                  _checkPendingJoin();
                } else {
                  _appScaffoldMessengerKey.currentState?.showSnackBar(
                    const SnackBar(
                      content:
                          Text('Sign-in succeeded but token exchange failed.'),
                    ),
                  );
                }
              }),
              AuthStateChangeAction<AuthFailed>((context, state) {
                debugPrint('Auth error: ${state.exception}');
              }),
            ],
          );
        },
        '/onboarding': (context) => const OnboardingScreen(),
        '/onboarding-test': (context) {
          // Quick and dirty bypass for testing - clears the flag on entry
          // and uses testMode to prevent setting it on exit
          SharedPreferences.getInstance().then((prefs) {
            prefs.setBool('onboarding_seen', false);
          });
          return const OnboardingScreen(testMode: true);
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
                    apiService: _apiService, authService: _authService);
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _appScaffoldMessengerKey.currentState?.showSnackBar(
                  const SnackBar(
                    content:
                        Text('Authentication required. Please sign in again.'),
                  ),
                );
                Navigator.pushReplacementNamed(context, '/sign-in');
              });
              return const SizedBox.shrink();
            },
          );
        }
      },
      ),
    );
  }
}
