import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service that manages theme configuration state for color palette testing.
///
/// Provides HSL values for bg, primary, secondary, and diff values for
/// computing derived colors. Also manages light/dark theme mode.
class ThemeConfigService extends ChangeNotifier {
  ThemeConfigService() {
    // Initialize with default theme values
    final defaultTheme = AppTheme.defaultTheme();
    final bgHsl = HSLColor.fromColor(defaultTheme.bg);
    final primaryHsl = HSLColor.fromColor(defaultTheme.primary);
    final secondaryHsl = HSLColor.fromColor(defaultTheme.secondary);
    final textHsl = HSLColor.fromColor(defaultTheme.text);
    final successHsl = HSLColor.fromColor(defaultTheme.success);
    final dangerHsl = HSLColor.fromColor(defaultTheme.danger);

    _bgH = bgHsl.hue;
    _bgS = bgHsl.saturation;
    _bgL = bgHsl.lightness;

    _primaryH = primaryHsl.hue;
    _primaryS = primaryHsl.saturation;
    _primaryL = primaryHsl.lightness;

    _secondaryH = secondaryHsl.hue;
    _secondaryS = secondaryHsl.saturation;
    _secondaryL = secondaryHsl.lightness;

    _textH = textHsl.hue;
    _textS = textHsl.saturation;
    _textL = textHsl.lightness;

    _successH = successHsl.hue;
    _successS = successHsl.saturation;
    _successL = successHsl.lightness;

    _dangerH = dangerHsl.hue;
    _dangerS = dangerHsl.saturation;
    _dangerL = dangerHsl.lightness;

    // Border HSL values
    final borderHsl = HSLColor.fromColor(defaultTheme.border);
    _borderH = borderHsl.hue;
    _borderS = borderHsl.saturation;
    _borderL = borderHsl.lightness;

    // Highlight HSL values
    final highlightHsl = HSLColor.fromColor(defaultTheme.highlight);
    _highlightH = highlightHsl.hue;
    _highlightS = highlightHsl.saturation;
    _highlightL = highlightHsl.lightness;

    // Calculate default diffs from default theme
    final bgLightHsl = HSLColor.fromColor(defaultTheme.bgLight);
    final bgDarkHsl = HSLColor.fromColor(defaultTheme.bgDark);
    final textMutedHsl = HSLColor.fromColor(defaultTheme.textMuted);
    final borderMutedHsl = HSLColor.fromColor(defaultTheme.borderMuted);

    _bgLightDiff = ((bgLightHsl.lightness - bgHsl.lightness) * 100).clamp(-100, 100);
    _bgDarkDiff = ((bgHsl.lightness - bgDarkHsl.lightness) * 100).clamp(-100, 100);
    _textMutedDiff = ((bgHsl.lightness - textMutedHsl.lightness) * 100).clamp(-100, 100);
    _borderMutedDiff = ((borderHsl.lightness - borderMutedHsl.lightness) * 100).clamp(-100, 100);
  }

  // HSL values for bg
  double _bgH = 300;
  double _bgS = 0.0;
  double _bgL = 0.04;

  // HSL values for primary
  double _primaryH = 41;
  double _primaryS = 0.52;
  double _primaryL = 0.60;

  // HSL values for secondary
  double _secondaryH = 221;
  double _secondaryS = 0.78;
  double _secondaryL = 0.76;

  // HSL values for text
  double _textH = 300;
  double _textS = 0.0;
  double _textL = 0.95;

  // HSL values for success
  double _successH = 146;
  double _successS = 0.17;
  double _successL = 0.59;

  // HSL values for danger
  double _dangerH = 9;
  double _dangerS = 0.26;
  double _dangerL = 0.64;

  // HSL values for border
  double _borderH = 0;
  double _borderS = 0.0;
  double _borderL = 0.28;

  // HSL values for highlight
  double _highlightH = 330;
  double _highlightS = 0.0;
  double _highlightL = 0.39;

  // Diff values (in percentage points)
  double _bgLightDiff = 5.0;
  double _bgDarkDiff = 3.0;
  double _textMutedDiff = 25.0;
  double _borderMutedDiff = 10.0;

  // Theme mode
  bool _isLightMode = false;

  // Getters
  double get bgH => _bgH;
  double get bgS => _bgS;
  double get bgL => _bgL;
  double get primaryH => _primaryH;
  double get primaryS => _primaryS;
  double get primaryL => _primaryL;
  double get secondaryH => _secondaryH;
  double get secondaryS => _secondaryS;
  double get secondaryL => _secondaryL;
  double get textH => _textH;
  double get textS => _textS;
  double get textL => _textL;
  double get successH => _successH;
  double get successS => _successS;
  double get successL => _successL;
  double get dangerH => _dangerH;
  double get dangerS => _dangerS;
  double get dangerL => _dangerL;
  double get borderH => _borderH;
  double get borderS => _borderS;
  double get borderL => _borderL;
  double get highlightH => _highlightH;
  double get highlightS => _highlightS;
  double get highlightL => _highlightL;
  double get bgLightDiff => _bgLightDiff;
  double get bgDarkDiff => _bgDarkDiff;
  double get textMutedDiff => _textMutedDiff;
  double get borderMutedDiff => _borderMutedDiff;
  bool get isLightMode => _isLightMode;

  // Setters
  void setBgH(double value) {
    _bgH = value;
    notifyListeners();
  }

  void setBgS(double value) {
    _bgS = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setBgL(double value) {
    _bgL = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setPrimaryH(double value) {
    _primaryH = value;
    notifyListeners();
  }

  void setPrimaryS(double value) {
    _primaryS = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setPrimaryL(double value) {
    _primaryL = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setSecondaryH(double value) {
    _secondaryH = value;
    notifyListeners();
  }

  void setSecondaryS(double value) {
    _secondaryS = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setSecondaryL(double value) {
    _secondaryL = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setTextH(double value) {
    _textH = value;
    notifyListeners();
  }

  void setTextS(double value) {
    _textS = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setTextL(double value) {
    _textL = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setSuccessH(double value) {
    _successH = value;
    notifyListeners();
  }

  void setSuccessS(double value) {
    _successS = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setSuccessL(double value) {
    _successL = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setDangerH(double value) {
    _dangerH = value;
    notifyListeners();
  }

  void setDangerS(double value) {
    _dangerS = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setDangerL(double value) {
    _dangerL = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setBorderH(double value) {
    _borderH = value;
    notifyListeners();
  }

  void setBorderS(double value) {
    _borderS = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setBorderL(double value) {
    _borderL = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setHighlightH(double value) {
    _highlightH = value;
    notifyListeners();
  }

  void setHighlightS(double value) {
    _highlightS = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setHighlightL(double value) {
    _highlightL = value.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setBgLightDiff(double value) {
    _bgLightDiff = value.clamp(-100, 100);
    notifyListeners();
  }

  void setBgDarkDiff(double value) {
    _bgDarkDiff = value.clamp(-100, 100);
    notifyListeners();
  }

  void setTextMutedDiff(double value) {
    _textMutedDiff = value.clamp(-100, 100);
    notifyListeners();
  }

  void setBorderMutedDiff(double value) {
    _borderMutedDiff = value.clamp(-100, 100);
    notifyListeners();
  }

  void toggleThemeMode() {
    _isLightMode = !_isLightMode;
    notifyListeners();
  }

  /// Resets all values to the current default theme
  void reset() {
    final defaultTheme = AppTheme.defaultTheme();
    final bgHsl = HSLColor.fromColor(defaultTheme.bg);
    final primaryHsl = HSLColor.fromColor(defaultTheme.primary);
    final secondaryHsl = HSLColor.fromColor(defaultTheme.secondary);

    _bgH = bgHsl.hue;
    _bgS = bgHsl.saturation;
    _bgL = bgHsl.lightness;

    _primaryH = primaryHsl.hue;
    _primaryS = primaryHsl.saturation;
    _primaryL = primaryHsl.lightness;

    _secondaryH = secondaryHsl.hue;
    _secondaryS = secondaryHsl.saturation;
    _secondaryL = secondaryHsl.lightness;

    final textHsl = HSLColor.fromColor(defaultTheme.text);
    _textH = textHsl.hue;
    _textS = textHsl.saturation;
    _textL = textHsl.lightness;

    final successHsl = HSLColor.fromColor(defaultTheme.success);
    _successH = successHsl.hue;
    _successS = successHsl.saturation;
    _successL = successHsl.lightness;

    final dangerHsl = HSLColor.fromColor(defaultTheme.danger);
    _dangerH = dangerHsl.hue;
    _dangerS = dangerHsl.saturation;
    _dangerL = dangerHsl.lightness;

    final borderHsl = HSLColor.fromColor(defaultTheme.border);
    _borderH = borderHsl.hue;
    _borderS = borderHsl.saturation;
    _borderL = borderHsl.lightness;

    final highlightHsl = HSLColor.fromColor(defaultTheme.highlight);
    _highlightH = highlightHsl.hue;
    _highlightS = highlightHsl.saturation;
    _highlightL = highlightHsl.lightness;

    final bgLightHsl = HSLColor.fromColor(defaultTheme.bgLight);
    final bgDarkHsl = HSLColor.fromColor(defaultTheme.bgDark);
    final textMutedHsl = HSLColor.fromColor(defaultTheme.textMuted);
    final borderMutedHsl = HSLColor.fromColor(defaultTheme.borderMuted);

    _bgLightDiff = ((bgLightHsl.lightness - bgHsl.lightness) * 100).clamp(-100, 100);
    _bgDarkDiff = ((bgHsl.lightness - bgDarkHsl.lightness) * 100).clamp(-100, 100);
    _textMutedDiff = ((bgHsl.lightness - textMutedHsl.lightness) * 100).clamp(-100, 100);
    _borderMutedDiff = ((borderHsl.lightness - borderMutedHsl.lightness) * 100).clamp(-100, 100);

    _isLightMode = false;
    notifyListeners();
  }

  /// Returns the current AppTheme - uses defaultTheme directly
  AppTheme computeTheme() {
    return AppTheme.defaultTheme();
  }

  /// Saves the current configuration with a given name
  Future<void> saveConfiguration(String name) async {
    if (name.trim().isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final configMap = {
      'bgH': _bgH,
      'bgS': _bgS,
      'bgL': _bgL,
      'primaryH': _primaryH,
      'primaryS': _primaryS,
      'primaryL': _primaryL,
      'secondaryH': _secondaryH,
      'secondaryS': _secondaryS,
      'secondaryL': _secondaryL,
      'textH': _textH,
      'textS': _textS,
      'textL': _textL,
      'successH': _successH,
      'successS': _successS,
      'successL': _successL,
      'dangerH': _dangerH,
      'dangerS': _dangerS,
      'dangerL': _dangerL,
      'borderH': _borderH,
      'borderS': _borderS,
      'borderL': _borderL,
      'highlightH': _highlightH,
      'highlightS': _highlightS,
      'highlightL': _highlightL,
      'bgLightDiff': _bgLightDiff,
      'bgDarkDiff': _bgDarkDiff,
      'textMutedDiff': _textMutedDiff,
      'borderMutedDiff': _borderMutedDiff,
      'isLightMode': _isLightMode,
    };

    final configJson = jsonEncode(configMap);
    await prefs.setString('theme_config_$name', configJson);

    // Update the list of saved configuration names
    await refreshSavedConfigurationNames();
    if (!_savedNames.contains(name)) {
      _savedNames.add(name);
      await prefs.setStringList('theme_config_names', _savedNames);
    }

    notifyListeners();
  }

  /// Loads a configuration by name
  Future<bool> loadConfiguration(String name) async {
    if (name.trim().isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final configJson = prefs.getString('theme_config_$name');

    if (configJson == null) return false;

    try {
      final configMap = jsonDecode(configJson) as Map<String, dynamic>;

      _bgH = (configMap['bgH'] as num).toDouble();
      _bgS = (configMap['bgS'] as num).toDouble();
      _bgL = (configMap['bgL'] as num).toDouble();
      _primaryH = (configMap['primaryH'] as num).toDouble();
      _primaryS = (configMap['primaryS'] as num).toDouble();
      _primaryL = (configMap['primaryL'] as num).toDouble();
      _secondaryH = (configMap['secondaryH'] as num).toDouble();
      _secondaryS = (configMap['secondaryS'] as num).toDouble();
      _secondaryL = (configMap['secondaryL'] as num).toDouble();
      _textH = (configMap['textH'] as num).toDouble();
      _textS = (configMap['textS'] as num).toDouble();
      _textL = (configMap['textL'] as num).toDouble();
      _successH = (configMap['successH'] as num?)?.toDouble() ?? 146.0;
      _successS = (configMap['successS'] as num?)?.toDouble() ?? 0.17;
      _successL = (configMap['successL'] as num?)?.toDouble() ?? 0.59;
      _dangerH = (configMap['dangerH'] as num?)?.toDouble() ?? 9.0;
      _dangerS = (configMap['dangerS'] as num?)?.toDouble() ?? 0.26;
      _dangerL = (configMap['dangerL'] as num?)?.toDouble() ?? 0.64;
      // Support both old (borderDiff) and new (borderH/S/L) formats for backward compatibility
      if (configMap.containsKey('borderH')) {
        _borderH = (configMap['borderH'] as num).toDouble();
        _borderS = (configMap['borderS'] as num).toDouble();
        _borderL = (configMap['borderL'] as num).toDouble();
      } else {
        // Fallback: compute from default theme if old format is used
        final defaultTheme = AppTheme.defaultTheme();
        final borderHsl = HSLColor.fromColor(defaultTheme.border);
        _borderH = borderHsl.hue;
        _borderS = borderHsl.saturation;
        _borderL = borderHsl.lightness;
      }
      // Support both old (highlightDiff) and new (highlightH/S/L) formats for backward compatibility
      if (configMap.containsKey('highlightH')) {
        _highlightH = (configMap['highlightH'] as num).toDouble();
        _highlightS = (configMap['highlightS'] as num).toDouble();
        _highlightL = (configMap['highlightL'] as num).toDouble();
      } else {
        // Fallback: compute from default theme if old format is used
        final defaultTheme = AppTheme.defaultTheme();
        final highlightHsl = HSLColor.fromColor(defaultTheme.highlight);
        _highlightH = highlightHsl.hue;
        _highlightS = highlightHsl.saturation;
        _highlightL = highlightHsl.lightness;
      }
      _bgLightDiff = (configMap['bgLightDiff'] as num).toDouble();
      _bgDarkDiff = (configMap['bgDarkDiff'] as num).toDouble();
      _textMutedDiff = (configMap['textMutedDiff'] as num).toDouble();
      _borderMutedDiff = (configMap['borderMutedDiff'] as num).toDouble();
      _isLightMode = configMap['isLightMode'] as bool? ?? false;

      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets the list of saved configuration names
  List<String> getSavedConfigurationNames() {
    // This is a synchronous getter, but we need async for SharedPreferences
    // We'll use a cached list that gets updated on save/load
    return _savedNames;
  }

  List<String> _savedNames = [];

  /// Loads the list of saved configuration names from SharedPreferences
  Future<void> refreshSavedConfigurationNames() async {
    final prefs = await SharedPreferences.getInstance();
    _savedNames = prefs.getStringList('theme_config_names') ?? [];
    notifyListeners();
  }
}
