import 'package:flutter/widgets.dart';

/// Provides the actual keyboard height to descendants, even when MediaQuery is overridden
class KeyboardHeightProvider extends InheritedWidget {
  final double keyboardHeight;

  const KeyboardHeightProvider({
    super.key,
    required this.keyboardHeight,
    required super.child,
  });

  static double of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<KeyboardHeightProvider>();
    return provider?.keyboardHeight ?? 0.0;
  }

  @override
  bool updateShouldNotify(KeyboardHeightProvider oldWidget) {
    return oldWidget.keyboardHeight != keyboardHeight;
  }
}
