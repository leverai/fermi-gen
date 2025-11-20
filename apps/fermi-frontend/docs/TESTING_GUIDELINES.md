Flutter Testing Guidelines for LLM Agents
Project: Multiplayer Trivia Game Stack: Flutter, Firebase (Auth, Firestore), Stripe Goal: This document provides the rules and best practices you MUST follow when writing unit, widget, golden, and integration tests for this project. Your objective is to create a robust, maintainable, and production-grade test suite.

📜 Core Principles: The Testing Pyramid
We will follow the Flutter Testing Pyramid. This dictates our testing strategy:

Unit Tests (Many): The base of the pyramid. These are fast, small, and test a single function or class's logic (e.g., a ViewModel or Repository). They have no UI or external dependencies.

Widget Tests (Fewer): The middle layer. These test a single widget, verifying its UI and interactions. Dependencies are mocked.

Golden Tests (As-needed): A special type of widget test that checks for visual regressions.

Integration Tests (Few): The top of the pyramid. These test a complete user flow or the entire app on a real device or emulator. They are slow but provide the highest confidence.

✅ General Guidelines (Must-Follow Rules)
These rules apply to ALL test types.

1. File Structure
All test files MUST be in the test/ directory.

The test file path MUST mirror the lib/ directory path.

Example: Code in lib/src/features/game/game_screen.dart

Test: test/src/features/game/game_screen_test.dart

2. Naming Conventions
Files: Use the _test.dart suffix.

Tests: Descriptions MUST be clear, human-readable strings starting with "should".

Good: test('should return true when score is above 100')

Bad: test('score test')

3. Test Structure: Arrange-Act-Assert (AAA)
Every test MUST follow the AAA pattern.

Dart

test('should increment counter by one', () {
  // 1. Arrange
  // Set up the test conditions.
  final counter = Counter();

  // 2. Act
  // Call the function or method being tested.
  counter.increment();

  // 3. Assert
  // Check if the result is what you expect.
  expect(counter.value, 1);
});
4. Grouping
You MUST use group() to organize related tests within a file.

Example: group('AuthenticationRepository', () { ... });

5. Finders
When finding widgets in tests, you MUST use Keys. This is more robust than finding by Type or text.

In-App Code: ElevatedButton(key: const ValueKey('login_button'), ...)

Test Code: find.byKey(const ValueKey('login_button'))

6. Dependencies
You MUST ensure these packages are in dev_dependencies in pubspec.yaml:

flutter_test (part of SDK)

integration_test (part of SDK)

mocktail: For creating mock objects. (Do NOT use mockito.)

firebase_auth_mocks: For mocking FirebaseAuth in unit/widget tests.

fake_cloud_firestore: For mocking FirebaseFirestore in unit/widget tests.

golden_toolkit: For advanced golden testing.

🧪 Section 1: Unit Tests (test)
Guiding Principle: Test the logic, not the UI. These tests must be FAST and have ZERO external dependencies (no Firebase, no HTTP, no disk).

What to test:

Business logic (e.g., calculateScore(), parseQuestion()).

ViewModel / BloC / ChangeNotifier logic.

Repository methods (with their dependencies mocked).

Key Tool: mocktail

How to Mock:

Define a mock class: class MockAuthRepository extends Mock implements AuthRepository {}

Register a fallback: registerFallbackValue(SomeType()); if needed for any().

Stub the mock in the Arrange block:

Dart

// ARRANGE
final mockRepo = MockAuthRepository();
when(() => mockRepo.signIn(any())).thenAnswer((_) async => true);

final viewModel = AuthViewModel(mockRepo);

// ACT
await viewModel.login('test@test.com', 'password');

// ASSERT
verify(() => mockRepo.signIn(any())).called(1);
expect(viewModel.isLoggedIn, true);
📱 Section 2: Widget Tests (testWidgets)
Guiding Principle: Test a single widget in isolation. Verify that given a certain state, the UI is correct, and that tapping/interacting changes the state as expected.

What to test:

QuestionCard, PlayerAvatar, Scoreboard, LoginScreen.

Verify that "Loading" state shows a CircularProgressIndicator.

Verify that "Error" state shows a Text widget with the error message.

Verify that tapping a button calls the correct method on a mocked dependency.

Key Tool: WidgetTester (the tester object).

Example:

Dart

testWidgets('LoginScreen should show error when login fails', (WidgetTester tester) async {
  // ARRANGE
  // 1. Create mocks
  final mockAuthRepo = MockAuthRepository();
  when(() => mockAuthRepo.signIn(any(), any())).thenThrow(Exception('Login failed'));

  // 2. Pump the widget, providing the MOCK dependency.
  //    (This assumes you use a dependency injection system like Provider or Riverpod)
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
      ],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );

  // ACT
  await tester.tap(find.byKey(const ValueKey('login_button')));
  await tester.pumpAndSettle(); // Wait for animations/futures to complete

  // ASSERT
  expect(find.text('Login failed'), findsOneWidget);
  expect(find.byType(CircularProgressIndicator), findsNothing);
});
🖼️ Section 3: Golden Tests (matchesGoldenFile)
Guiding Principle: Prevent visual regressions. A golden test takes a "screenshot" of a widget and fails if the UI changes pixel-for-pixel.

What to test:

Visually complex components: QuestionCard, Scoreboard.

All states of a widget (e.g., PlayerAvatar with/without image, with/without "winner" badge).

Key Tool: golden_toolkit package.

Setup:

Create test/flutter_test_config.dart to load app fonts (this is CRITICAL for CIs):

Dart

// test/flutter_test_config.dart
import 'dart:async';
import 'package:golden_toolkit/golden_toolkit.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  return GoldenToolkit.runWithConfiguration(
    () async {
      await loadAppFonts(); // Loads fonts from pubspec.yaml
      await testMain();
    },
    config: GoldenToolkitConfiguration(
      // Your config here
    ),
  );
}
Example:

Dart

testGoldens('QuestionCard should render correctly in all states', (tester) async {
  final builder = DeviceBuilder()
    ..addScenario(
      widget: const QuestionCard(question: 'Question 1', state: 'unanswered'),
      name: 'unanswered',
    )
    ..addScenario(
      widget: const QuestionCard(question: 'Question 2', state: 'correct'),
      name: 'correct_answer',
    );

  await tester.pumpDeviceBuilder(builder);
  await screenMatchesGolden(tester, 'question_card_states');
});
How to Update:

Run flutter test --update-goldens to create/update the golden images.

Manually inspect the changed images.

Commit the new *.png files to Git.

🚀 Section 4: Integration Tests (integration_test)
Guiding Principle: Test a full user flow on a real device/emulator. This is where we use the Firebase Emulator Suite. We will NOT mock Firebase here; we will use the real (local) thing.

What to test:

Auth Flow: (1) User opens app, (2) taps login, (3) enters credentials, (4) sees game lobby.

Game Flow: (1) User joins game, (2) sees "Waiting" screen, (3) Test simulates backend reveal, (4) User sees question, (5) User taps answer, (6) Test simulates backend reveal, (7) User sees result.

File Location: integration_test/app_flow_test.dart

Setup:

Initialize the test: IntegrationTestWidgetsFlutterBinding.ensureInitialized();

In setUpAll(), connect the app to the running emulators.

CRITICAL STACK-SPECIFIC RULE: Using Firebase Emulators

You MUST use the Firebase Emulators for all integration tests.

Run Emulators: Before running the test, you must run this command in your terminal: firebase emulators:start --only auth,firestore

Configure App: In your test file, configure the app to use them.

Example Test (integration_test/auth_flow_test.dart):

Dart

import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:my_app/main.dart' as app; // Import your app's main file

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Point Firebase services to the local emulators
    const host = '127.0.0.1';

    // Auth Emulator
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);

    // Firestore Emulator
    FirebaseFirestore.instance.settings = const Settings(
      host: '$host:8080',
      sslEnabled: false,
      persistenceEnabled: false,
    );
  });

  testWidgets('Full Login Flow', (WidgetTester tester) async {
    // ARRANGE
    app.main(); // Start the app
    await tester.pumpAndSettle();

    // ACT
    await tester.tap(find.byKey(const ValueKey('login_email_field')));
    await tester.enterText(find.byKey(const ValueKey('login_email_field')), 'test@user.com');

    await tester.tap(find.byKey(const ValueKey('login_password_field')));
    await tester.enterText(find.byKey(const ValueKey('login_password_field')), 'password123');

    await tester.tap(find.byKey(const ValueKey('login_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3)); // Wait for login

    // ASSERT
    // We should be on the Game Lobby screen
    expect(find.text('Game Lobby'), findsOneWidget);
    expect(find.byKey(const ValueKey('login_button')), findsNothing);
  });
}
🎯 Test Strategy for the Trivia App (Key Insight)
For the trivia game, the most valuable integration test is the "Game Flow." You will need to simulate the backend's actions.

In your game_flow_test.dart:

Arrange: setUpAll and connect to emulators.

Act (Player): Pump the app, log in, and join a game (e.g., tap join_game_button).

Assert (Player): The UI shows find.text('Waiting for question...').

Act (Simulated Backend): The test itself can write to the Firestore emulator to simulate the backend revealing a question.

Dart

// This code is IN YOUR TEST, simulating the backend
await FirebaseFirestore.instance
    .collection('games')
    .doc('game_123')
    .collection('questions')
    .doc('q_1')
    .set({'text': 'What is Flutter?', 'revealed': true});
Assert (Player): await tester.pumpAndSettle(). Now, assert that the UI updated: expect(find.text('What is Flutter?'), findsOneWidget).

This approach allows you to test your app's entire real-time synchronization logic without a real backend.
