import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart'
    hide EmailAuthProvider, AuthProvider;
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fermi_frontend/services/auth_service.dart';
import 'package:fermi_frontend/services/auth_state_notifier.dart';
import 'package:fermi_frontend/services/api_service.dart';
import 'package:fermi_frontend/services/preload_service.dart';
import 'package:fermi_frontend/services/daily_question_service.dart';
import 'package:fermi_frontend/services/subscription_service.dart';
import 'package:fermi_frontend/screens/main/main_screen.dart';
import 'package:fermi_frontend/screens/onboarding_screen.dart';
import 'package:fermi_frontend/screens/auth_screen.dart';
import 'package:fermi_frontend/screens/welcome_screen.dart';
import 'package:fermi_frontend/screens/daily_question/daily_question_screen.dart';
import 'package:fermi_frontend/screens/daily_question/pre_daily_question_screen.dart';
import 'package:fermi_frontend/screens/lobby/lobby_screen_controller.dart';
import 'package:fermi_frontend/screens/main/main_screen_controller.dart';
import 'package:fermi_frontend/screens/survival/survival_screen.dart';
import 'package:provider/provider.dart';
import 'package:fermi_frontend/controllers/daily_question_controller.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// Creates and configures the app's GoRouter instance.
///
/// This uses Navigator 2.0 to properly handle web URLs and avoid the
/// "Could not navigate to initial route" exception on hot-restart.
class AppRouter {
  final AuthService authService;
  final AuthStateNotifier authStateNotifier;
  final ApiService apiService;
  final PreloadService preloadService;
  final DailyQuestionService dailyQuestionService;
  final SubscriptionService subscriptionService;
  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;
  final VoidCallback Function()? onCheckPendingJoin;

  late final GoRouter router;

  AppRouter({
    required this.authService,
    required this.authStateNotifier,
    required this.apiService,
    required this.preloadService,
    required this.dailyQuestionService,
    required this.subscriptionService,
    required this.navigatorKey,
    required this.scaffoldMessengerKey,
    this.onCheckPendingJoin,
  }) {
    router = _createRouter();
  }

  GoRouter _createRouter() {
    return GoRouter(
      navigatorKey: navigatorKey,
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: authStateNotifier,
      redirect: _handleRedirect,
      routes: [
        // Root route - redirects based on auth/onboarding state
        GoRoute(
          path: '/',
          redirect: (context, state) async {
            // This redirect handles the initial "/" route
            // The global redirect handles auth/onboarding logic
            return null;
          },
          builder: (context, state) => _buildMainScreen(context),
        ),
        // Onboarding
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => OnboardingScreen(
            preloadService: preloadService,
          ),
        ),
        // Onboarding test mode
        GoRoute(
          path: '/onboarding-test',
          builder: (context, state) {
            SharedPreferences.getInstance().then((prefs) {
              prefs.setBool('onboarding_seen', false);
            });
            return OnboardingScreen(
              testMode: true,
              preloadService: preloadService,
            );
          },
        ),
        // Sign-in
        GoRoute(
          path: '/sign-in',
          builder: (context, state) => _buildSignInScreen(context),
        ),
        // Welcome screen (first-time users)
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        // Main screen
        GoRoute(
          path: '/main',
          builder: (context, state) => _buildMainScreen(context),
        ),
        // Profile
        GoRoute(
          path: '/profile',
          builder: (context, state) => _buildProfileScreen(context),
        ),
        // Upgrade account
        GoRoute(
          path: '/upgrade-account',
          builder: (context, state) => _buildUpgradeAccountScreen(context),
        ),
        // Daily Question with date parameter
        GoRoute(
          path: '/dq/:date',
          builder: (context, state) {
            final date = state.pathParameters['date'] ?? '';
            return _DQRouterWidget(questionDate: date);
          },
        ),
        // Game invite link
        GoRoute(
          path: '/invite/game/:id',
          redirect: (context, state) async {
            final gameId = state.pathParameters['id'];
            if (gameId != null) {
              // Navigate to lobby after joining game
              // The actual join logic will be handled by the screen
              return '/lobby/$gameId';
            }
            return '/main';
          },
        ),
        // Lobby screen (for game invites)
        GoRoute(
          path: '/lobby/:gameId',
          builder: (context, state) {
            final gameId = state.pathParameters['gameId'] ?? '';
            final realtime =
                MainScreenController(api: apiService, auth: authService)
                    .buildRealtimeAdapter();
            return LobbyScreenController(
              gameId: gameId,
              realtime: realtime,
              api: apiService,
            );
          },
        ),
        // Survival mode
        GoRoute(
          path: '/survival',
          builder: (context, state) => const SurvivalScreen(),
        ),
      ],
      errorBuilder: (context, state) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Route not found: ${state.uri}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/main'),
                child: const Text('Go to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Global redirect logic for auth and onboarding state.
  Future<String?> _handleRedirect(
      BuildContext context, GoRouterState state) async {
    final location = state.uri.path;

    // Allow onboarding and sign-in routes without auth
    if (location == '/onboarding' ||
        location == '/onboarding-test' ||
        location == '/sign-in' ||
        location == '/welcome') {
      return null;
    }

    // Wait for auth state to settle before making routing decisions
    // This prevents redirecting to sign-in on hot-restart before Firebase
    // Auth has restored persisted state
    if (!authStateNotifier.isSettled) {
      // If already on welcome, stay there; otherwise redirect to it
      return location == '/welcome' ? null : '/welcome';
    }

    // Always read fresh from SharedPreferences to ensure refresh() picks up changes
    final prefs = await SharedPreferences.getInstance();
    final welcomeSeen = prefs.getBool('welcome_seen') ?? false;
    final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;

    if (!welcomeSeen) {
      return '/welcome';
    }

    if (!onboardingSeen) {
      return '/onboarding';
    }

    // Check auth - anonymous auth is sufficient
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return '/sign-in';
    }

    return null;
  }

  Widget _buildMainScreen(BuildContext context) {
    return FutureBuilder<bool>(
      future: authService.accessToken != null
          ? Future<bool>.value(true)
          : authService.exchangeToken(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == true) {
          return MainScreen(
            apiService: apiService,
            authService: authService,
            preloadService: preloadService,
            dailyQuestionService: dailyQuestionService,
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            const SnackBar(
              content: Text('Authentication required. Please sign in again.'),
            ),
          );
          context.go('/sign-in');
        });
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSignInScreen(BuildContext context) {
    final List<AuthProvider> providers = [
      EmailAuthProvider(),
      GoogleProvider(clientId: ''),
    ];
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    return AuthScreen(
      providers: providers,
      actions: [
        AuthStateChangeAction<UserCreated>((context, state) async {
          final user = FirebaseAuth.instance.currentUser;
          final ok = await authService.exchangeToken();
          // Sync RevenueCat with the current Firebase user
          if (user != null) {
            await subscriptionService.login(user.uid);
          }
          if (!context.mounted) return;
          if (ok) {
            SharedPreferences.getInstance()
                .then((prefs) => prefs.setBool('onboarding_seen', true));
            context.go('/main');
            onCheckPendingJoin?.call();
          } else {
            scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Sign-in succeeded but token exchange failed.'),
              ),
            );
          }
        }),
        AuthStateChangeAction<SignedIn>((context, state) async {
          final user = FirebaseAuth.instance.currentUser;
          final ok = await authService.exchangeToken();
          // Sync RevenueCat with the current Firebase user
          if (user != null) {
            await subscriptionService.login(user.uid);
          }
          if (!context.mounted) return;
          if (ok) {
            SharedPreferences.getInstance()
                .then((prefs) => prefs.setBool('onboarding_seen', true));
            context.go('/main');
            onCheckPendingJoin?.call();
          } else {
            scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text('Sign-in succeeded but token exchange failed.'),
              ),
            );
          }
        }),
        AuthStateChangeAction<CredentialLinked>((context, state) async {
          final user = FirebaseAuth.instance.currentUser;
          final ok = await authService.exchangeToken();
          // Sync RevenueCat with the current Firebase user
          if (user != null) {
            await subscriptionService.login(user.uid);
          }
          if (!context.mounted) return;
          if (ok) {
            scaffoldMessengerKey.currentState?.showSnackBar(
              SnackBar(
                content: const Text('Account created successfully!'),
                backgroundColor: appTheme.success,
              ),
            );
            SharedPreferences.getInstance()
                .then((prefs) => prefs.setBool('onboarding_seen', true));
            context.go('/main');
            onCheckPendingJoin?.call();
          } else {
            scaffoldMessengerKey.currentState?.showSnackBar(
              const SnackBar(
                content: Text(
                    'Account linking succeeded but token exchange failed.'),
              ),
            );
          }
        }),
        AuthStateChangeAction<AuthFailed>((context, state) {
          debugPrint('Auth error: ${state.exception}');
        }),
      ],
    );
  }

  Widget _buildProfileScreen(BuildContext context) {
    final List<AuthProvider> providers = [
      EmailAuthProvider(),
      GoogleProvider(clientId: ''),
    ];

    return ProfileScreen(
      providers: providers,
      actions: [
        SignedOutAction((context) {
          context.go('/sign-in');
        }),
      ],
    );
  }

  Widget _buildUpgradeAccountScreen(BuildContext context) {
    final List<AuthProvider> providers = [
      EmailAuthProvider(),
      GoogleProvider(clientId: ''),
    ];

    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    return AuthScreen(
      providers: providers,
      actions: [
        AuthStateChangeAction<CredentialLinked>((context, state) async {
          final user = FirebaseAuth.instance.currentUser;
          final ok = await authService.exchangeToken();
          // Sync RevenueCat with the current Firebase user
          if (user != null) {
            await subscriptionService.login(user.uid);
          }
          if (!context.mounted) return;
          if (ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Account created successfully!'),
                backgroundColor: appTheme.success,
              ),
            );
            context.pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Account linking succeeded but token exchange failed.'),
              ),
            );
          }
        }),
        AuthStateChangeAction<SignedIn>((context, state) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && user.isAnonymous) {
            debugPrint('User is still anonymous after sign-in');
          } else {
            final ok = await authService.exchangeToken();
            // Sync RevenueCat with the current Firebase user
            if (user != null) {
              await subscriptionService.login(user.uid);
            }
            if (!context.mounted) return;
            if (ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account created successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              context.pop();
            }
          }
        }),
        AuthStateChangeAction<AuthFailed>((context, state) {
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
                errorMessage = 'Invalid credentials. Please try again.';
                break;
              default:
                errorMessage = 'Error: ${exception.message ?? exception.code}';
            }
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        }),
      ],
      onLeave: () => context.pop(),
    );
  }
}

/// Router widget that decides whether to show PreDailyQuestionScreen or DailyQuestionScreen
/// based on DQ status and user participation.
class _DQRouterWidget extends StatelessWidget {
  final String questionDate;

  const _DQRouterWidget({required this.questionDate});

  @override
  Widget build(BuildContext context) {
    // Try to access the controller - it may not be available if we're coming from a deep link
    // In that case, we'll need to check the state differently
    final controller = context.read<DailyQuestionController>();
    final todayDate = controller.todayDate;
    final todayDocument = controller.todayDocument;
    final isToday = questionDate == todayDate;
    final hasParticipated = controller.weeklyItems[questionDate] ?? false;

    // Check if this is scenario A2: ACTIVE + not participated
    if (isToday) {
      final status = todayDocument?.status ?? 'NOT_STARTED';
      if (status == 'ACTIVE' && !hasParticipated) {
        // Show pre-screen for invite links
        return PreDailyQuestionScreen(
          questionDate: questionDate,
          fromInvite: true,
        );
      }
    }

    // All other cases: show the regular DQ screen
    return DailyQuestionScreen(questionDate: questionDate);
  }
}
