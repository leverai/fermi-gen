import 'package:flutter/material.dart';
import 'package:fermi_frontend/state/theme_config_service.dart';

/// InheritedWidget that provides ThemeConfigService to the widget tree.
class ThemeConfigProvider extends InheritedWidget {
  const ThemeConfigProvider({
    super.key,
    required this.service,
    required super.child,
  });

  final ThemeConfigService service;

  static ThemeConfigService of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<ThemeConfigProvider>();
    assert(provider != null, 'ThemeConfigProvider not found in context');
    return provider!.service;
  }

  static ThemeConfigService? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeConfigProvider>()?.service;
  }

  @override
  bool updateShouldNotify(ThemeConfigProvider oldWidget) {
    return service != oldWidget.service;
  }
}
