import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('UnitTape - Bug: Wrong Unit at Reveal Time', () {
    // This test reproduces the bug described in BUG_UNIT_TAPE_WRONG_UNIT.md
    //
    // Bug condition:
    // 1. User selects a unit that is NOT the first in the list
    // 2. Widget transitions from editable=true to editable=false (reveal time)
    // 3. The parent passes a NEW units list instance (same content, different reference)
    // 4. BUG: The unit changes to the first unit in the list
    // 5. EXPECTED: The unit should remain unchanged

    testWidgets(
      'should retain unit when units list reference changes and editable becomes false',
      (WidgetTester tester) async {
        // This test uses a stateful harness to trigger didUpdateWidget
        // with a new units list instance (same content)

        String? lastChangedUnit;
        int changeCount = 0;
        final controller = UnitTapeController();

        await pumpWithMaterialApp(
          tester,
          _StatefulTestHarness(
            key: const Key('harness'),
            initialUnits: ['L', 'm³', 'km³'],
            unitOptions: {
              'Liter': 'L',
              'Meter³': 'm³',
              'Kilometer³': 'km³',
            },
            initialValue: 'km³', // Last unit - NOT the first
            controller: controller,
            onUnitChanged: (unit) {
              lastChangedUnit = unit;
              changeCount++;
            },
          ),
        );

        // Verify initial state - should show 'km³'
        expect(find.text('km³'), findsOneWidget);
        final initialChangeCount = changeCount;

        // Act: Trigger rebuild with NEW list instance + editable=false
        // This is what happens during reveal: parent rebuilds, passes new list reference
        await tester.tap(find.byKey(const Key('rebuild_button')));
        await tester.pumpAndSettle();

        // Assert: Unit should still be 'km³'
        expect(find.text('km³'), findsOneWidget,
            reason: 'Unit should remain km³ after reveal (new list instance)');

        // Assert: onUnitChanged should NOT have been called with 'L' (first unit)
        // The bug would cause _onPageChanged to fire with index 0 when PageController
        // is recreated, which then calls onUnitChanged('L')
        if (changeCount > initialChangeCount) {
          expect(lastChangedUnit, isNot(equals('L')),
              reason: 'BUG: onUnitChanged was called with first unit "L"');
        }
      },
    );

    testWidgets(
      'should NOT call onUnitChanged when PageController is recreated with same current unit',
      (WidgetTester tester) async {
        // More explicit test: verify onUnitChanged is NOT called at all during reveal

        final List<String> changedUnits = [];
        final controller = UnitTapeController();

        await pumpWithMaterialApp(
          tester,
          _StatefulTestHarness(
            key: const Key('harness'),
            initialUnits: ['qt', 'gal', 'foot³', 'meter³'],
            unitOptions: {
              'Quart': 'qt',
              'Gallon': 'gal',
              'Foot³': 'foot³',
              'Meter³': 'meter³',
            },
            initialValue: 'foot³',
            controller: controller,
            onUnitChanged: (unit) {
              changedUnits.add(unit);
            },
          ),
        );

        expect(find.text('foot³'), findsOneWidget);
        changedUnits.clear(); // Clear any init callbacks

        // Trigger rebuild (simulates reveal)
        await tester.tap(find.byKey(const Key('rebuild_button')));
        await tester.pumpAndSettle();

        // Expected: no calls to onUnitChanged during reveal
        // Bug would add 'qt' to the list (first unit)
        expect(changedUnits.where((u) => u == 'qt'), isEmpty,
            reason:
                'BUG: onUnitChanged was called with first unit "qt" during reveal');
      },
    );

    testWidgets(
      'PageController recreation should NOT trigger onPageChanged for same index',
      (WidgetTester tester) async {
        // This test specifically verifies that when PageController is recreated
        // with the correct initial page, onPageChanged should NOT fire

        final List<String> allChanges = [];
        final controller = UnitTapeController();

        await pumpWithMaterialApp(
          tester,
          _StatefulTestHarness(
            key: const Key('harness'),
            initialUnits: ['A', 'B', 'C', 'D'],
            unitOptions: {'A': 'A', 'B': 'B', 'C': 'C', 'D': 'D'},
            initialValue: 'C', // Index 2 - middle of list
            controller: controller,
            onUnitChanged: (unit) {
              allChanges.add(unit);
            },
          ),
        );

        expect(find.text('C'), findsOneWidget);
        allChanges.clear();

        // Multiple rebuilds with new list instances
        for (int i = 0; i < 3; i++) {
          await tester.tap(find.byKey(const Key('rebuild_button')));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.pumpAndSettle();

        // Should still show 'C'
        expect(find.text('C'), findsOneWidget);

        // Should NOT have called onUnitChanged with 'A' (first unit)
        expect(allChanges.contains('A'), isFalse,
            reason: 'BUG: Unit changed to first unit during rebuild');
      },
    );
  });
}

/// Stateful test harness that can trigger rebuilds with new list instances
/// This properly tests didUpdateWidget behavior
class _StatefulTestHarness extends StatefulWidget {
  const _StatefulTestHarness({
    super.key,
    required this.initialUnits,
    required this.unitOptions,
    required this.initialValue,
    required this.controller,
    required this.onUnitChanged,
  });

  final List<String> initialUnits;
  final Map<String, String> unitOptions;
  final String initialValue;
  final UnitTapeController controller;
  final ValueChanged<String> onUnitChanged;

  @override
  State<_StatefulTestHarness> createState() => _StatefulTestHarnessState();
}

class _StatefulTestHarnessState extends State<_StatefulTestHarness> {
  late List<String> _units;
  bool _editable = true;
  int _rebuildCount = 0;

  @override
  void initState() {
    super.initState();
    _units = widget.initialUnits;
  }

  void _triggerRebuild() {
    setState(() {
      // Create NEW list instance with same content
      // This triggers: oldWidget.units != widget.units (reference inequality)
      // which causes PageController recreation in didUpdateWidget
      _units = List<String>.from(widget.initialUnits);
      _editable = false; // Transition to non-editable (reveal time)
      _rebuildCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        UnitTape(
          units: _units,
          unitOptions: widget.unitOptions,
          initialValue: widget.initialValue,
          currentLocale: 'EU',
          onUnitChanged: widget.onUnitChanged,
          onLocaleChanged: (_) {},
          editable: _editable,
          controller: widget.controller,
        ),
        ElevatedButton(
          key: const Key('rebuild_button'),
          onPressed: _triggerRebuild,
          child: Text('Rebuild ($_rebuildCount)'),
        ),
      ],
    );
  }
}
