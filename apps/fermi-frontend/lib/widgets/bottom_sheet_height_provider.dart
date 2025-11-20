import 'package:flutter/widgets.dart';

/// Provides the height of custom bottom sheets to ancestors
/// Used to slide screen content up when OM/Unit selectors are shown
class BottomSheetHeightProvider extends InheritedWidget {
  final ValueNotifier<double> heightNotifier;

  const BottomSheetHeightProvider({
    super.key,
    required this.heightNotifier,
    required super.child,
  });

  static ValueNotifier<double>? maybeOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<BottomSheetHeightProvider>();
    return provider?.heightNotifier;
  }

  static ValueNotifier<double> of(BuildContext context) {
    final notifier = maybeOf(context);
    assert(notifier != null, 'BottomSheetHeightProvider not found in context');
    return notifier!;
  }

  @override
  bool updateShouldNotify(BottomSheetHeightProvider oldWidget) {
    return oldWidget.heightNotifier != heightNotifier;
  }
}
