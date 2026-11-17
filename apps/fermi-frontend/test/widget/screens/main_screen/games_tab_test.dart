import 'package:fermi_frontend/screens/main/widgets/games_tab.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'Clubhouse renders live actions in ${brightness.name} mode',
      (tester) async {
        var partyTaps = 0;
        var survivalTaps = 0;
        var precisionTaps = 0;
        var dailyTaps = 0;
        var archiveTaps = 0;

        await _pumpGamesTab(
          tester,
          brightness: brightness,
          onParty: () => partyTaps++,
          onSurvival: () => survivalTaps++,
          onPrecisionRush: () => precisionTaps++,
          onDaily: () => dailyTaps++,
          onArchive: () => archiveTaps++,
        );

        expect(find.text('THE CLUBHOUSE'), findsOneWidget);
        expect(find.text('Hey Ada 👋'), findsOneWidget);
        expect(find.text('Bring the\nsmart friends.'), findsOneWidget);
        expect(find.text('2 free this week'), findsOneWidget);
        expect(find.text('1 run today'), findsNWidgets(2));
        expect(find.text('Daily question archive'), findsOneWidget);
        expect(find.text('Browse your question archive'), findsNothing);
        expect(tester.takeException(), isNull);

        await tester.tap(find.text('Start a party'));
        await tester.ensureVisible(find.text('Survival'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Survival'));
        await tester.tap(find.text('Precision\nRush'));
        await tester.ensureVisible(find.text('Daily question'));
        await tester.tap(find.text('Daily question'));
        await tester.ensureVisible(find.text('Daily question archive'));
        await tester.tap(find.text('Daily question archive'));

        expect(partyTaps, 1);
        expect(survivalTaps, 1);
        expect(precisionTaps, 1);
        expect(dailyTaps, 1);
        expect(archiveTaps, 1);
      },
    );
  }

  testWidgets('Party hero text remains readable in light mode', (tester) async {
    await _pumpGamesTab(
      tester,
      brightness: Brightness.light,
      onParty: () {},
      onSurvival: () {},
      onPrecisionRush: () {},
      onDaily: () {},
      onArchive: () {},
    );

    final theme = AppTheme.lightTheme();
    final headline = tester.widget<Text>(
      find.text('Bring the\nsmart friends.'),
    );
    final allowance = tester.widget<Text>(find.text('2 free this week'));
    final pill = tester.widget<Text>(find.text('HOST A ROOM'));

    expect(
      _contrast(headline.style!.color!, theme.secondaryMuted),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(allowance.style!.color!, theme.secondaryMuted),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(pill.style!.color!, theme.secondaryMuted),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('Party hero keeps its dark-mode color treatment', (tester) async {
    await _pumpGamesTab(
      tester,
      brightness: Brightness.dark,
      onParty: () {},
      onSurvival: () {},
      onPrecisionRush: () {},
      onDaily: () {},
      onArchive: () {},
    );

    final theme = AppTheme.defaultTheme();
    final headline = tester.widget<Text>(
      find.text('Bring the\nsmart friends.'),
    );
    final allowance = tester.widget<Text>(find.text('2 free this week'));
    final pill = tester.widget<Text>(find.text('HOST A ROOM'));

    expect(headline.style!.color, theme.text);
    expect(allowance.style!.color, theme.textMuted);
    expect(pill.style!.color, theme.secondary);
  });
}

Future<void> _pumpGamesTab(
  WidgetTester tester, {
  required Brightness brightness,
  required VoidCallback onParty,
  required VoidCallback onSurvival,
  required VoidCallback onPrecisionRush,
  required VoidCallback onDaily,
  required VoidCallback onArchive,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final appTheme = brightness == Brightness.light
      ? AppTheme.lightTheme()
      : AppTheme.defaultTheme();

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(
        brightness: brightness,
        extensions: <ThemeExtension<dynamic>>[
          appTheme,
          const AppFont(),
        ],
      ),
      home: Scaffold(
        backgroundColor: appTheme.bgDark,
        body: GamesTab(
          displayName: 'Ada Lovelace',
          partyMetadata: '2 free this week',
          survivalMetadata: '1 run today',
          precisionRushMetadata: '1 run today',
          dailyAction: GamesTabDailyAction(
            shortLabel: 'Play',
            detail: 'Live now · compare your intuition with everyone else',
            onTap: onDaily,
          ),
          onPartyCardTapped: onParty,
          onSurvivalCardTapped: onSurvival,
          onPrecisionRushCardTapped: onPrecisionRush,
          onArchiveTapped: onArchive,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _contrast(Color foreground, Color background) {
  final lighter = foreground.computeLuminance() > background.computeLuminance()
      ? foreground.computeLuminance()
      : background.computeLuminance();
  final darker = foreground.computeLuminance() > background.computeLuminance()
      ? background.computeLuminance()
      : foreground.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
