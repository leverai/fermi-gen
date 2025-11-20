import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fermi_frontend/screens/question_v2/question_screen_v2.dart';
import 'package:fermi_frontend/services/demo/onboarding_realtime.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// Standalone demo for previewing theme colors on the onboarding screen.
///
/// Shows the onboarding screen visually (no tutorial logic) and allows
/// dynamically changing theme colors and switching between dark/light themes.
void main() {
  runApp(const ThemePreviewApp());
}

class ThemePreviewApp extends StatelessWidget {
  const ThemePreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Theme Preview',
      theme: ThemeData(
        extensions: <ThemeExtension<dynamic>>[
          AppTheme.defaultTheme(),
          const AppFont(),
        ],
      ),
      home: const ThemePreviewScreen(),
    );
  }
}

class ThemePreviewScreen extends StatefulWidget {
  const ThemePreviewScreen({super.key});

  @override
  State<ThemePreviewScreen> createState() => _ThemePreviewScreenState();
}

class _ThemePreviewScreenState extends State<ThemePreviewScreen> {
  bool _isDarkTheme = true;
  // Only store the 3 base colors
  Color _bg = AppTheme.defaultTheme().bg;
  Color _primary = AppTheme.defaultTheme().primary;
  Color _secondary = AppTheme.defaultTheme().secondary;

  // Configurable percentage adjustments
  double _bgLightAdjustment = 0.05; // +5%
  double _bgDarkAdjustment = -0.05; // -5%
  double _textMutedAdjustment = -0.25; // -25%
  double _highlightAdjustment = -0.30; // -30%
  double _borderAdjustment = -0.10; // -10%
  double _borderMutedAdjustment = -0.10; // -10%
  double _primaryMutedAdjustment = -0.50; // -50%
  double _secondaryMutedAdjustment = -0.50; // -50%

  /// Adjust lightness by a percentage (0.0 to 1.0)
  Color _adjustLightness(Color color, double adjustment) {
    final hsl = HSLColor.fromColor(color);
    final newLightness = (hsl.lightness + adjustment).clamp(0.0, 1.0);
    return hsl.withLightness(newLightness).toColor();
  }

  /// Generate dark theme from base colors
  AppTheme _generateDarkTheme(Color bg, Color primary, Color secondary) {
    final defaultTheme = AppTheme.defaultTheme();
    final bgHsl = HSLColor.fromColor(bg);

    return AppTheme(
      // Backgrounds
      bg: bg,
      bgLight: _adjustLightness(bg, _bgLightAdjustment),
      bgDark: _adjustLightness(bg, _bgDarkAdjustment),

      // Text (invert bg lightness)
      text: () {
        final textHsl = HSLColor.fromAHSL(
            1.0, bgHsl.hue, bgHsl.saturation, 1.0 - bgHsl.lightness);
        return textHsl.toColor();
      }(),

      // Text muted (text lightness adjustment)
      textMuted: () {
        final textHsl = HSLColor.fromAHSL(
            1.0, bgHsl.hue, bgHsl.saturation, 1.0 - bgHsl.lightness);
        final textMutedLightness =
            (textHsl.lightness + _textMutedAdjustment).clamp(0.0, 1.0);
        return textHsl.withLightness(textMutedLightness).toColor();
      }(),

      // Highlight (textMuted lightness adjustment)
      highlight: () {
        final textHsl = HSLColor.fromAHSL(
            1.0, bgHsl.hue, bgHsl.saturation, 1.0 - bgHsl.lightness);
        final textMutedLightness =
            (textHsl.lightness + _textMutedAdjustment).clamp(0.0, 1.0);
        final highlightLightness =
            (textMutedLightness + _highlightAdjustment).clamp(0.0, 1.0);
        return textHsl.withLightness(highlightLightness).toColor();
      }(),

      // Border (highlight lightness adjustment)
      border: () {
        final textHsl = HSLColor.fromAHSL(
            1.0, bgHsl.hue, bgHsl.saturation, 1.0 - bgHsl.lightness);
        final textMutedLightness =
            (textHsl.lightness + _textMutedAdjustment).clamp(0.0, 1.0);
        final highlightLightness =
            (textMutedLightness + _highlightAdjustment).clamp(0.0, 1.0);
        final borderLightness =
            (highlightLightness + _borderAdjustment).clamp(0.0, 1.0);
        return textHsl.withLightness(borderLightness).toColor();
      }(),

      // Border muted (border lightness adjustment)
      borderMuted: () {
        final textHsl = HSLColor.fromAHSL(
            1.0, bgHsl.hue, bgHsl.saturation, 1.0 - bgHsl.lightness);
        final textMutedLightness =
            (textHsl.lightness + _textMutedAdjustment).clamp(0.0, 1.0);
        final highlightLightness =
            (textMutedLightness + _highlightAdjustment).clamp(0.0, 1.0);
        final borderLightness =
            (highlightLightness + _borderAdjustment).clamp(0.0, 1.0);
        final borderMutedLightness =
            (borderLightness + _borderMutedAdjustment).clamp(0.0, 1.0);
        return textHsl.withLightness(borderMutedLightness).toColor();
      }(),

      // Brand colors
      primary: primary,
      primaryMuted: _adjustLightness(primary, _primaryMutedAdjustment),
      secondary: secondary,
      secondaryMuted: _adjustLightness(secondary, _secondaryMutedAdjustment),

      // Semantic colors (unchanged from default)
      danger: defaultTheme.danger,
      warning: defaultTheme.warning,
      success: defaultTheme.success,
      info: defaultTheme.info,
    );
  }

  /// Invert lightness of a color
  Color _invertLightness(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness(1.0 - hsl.lightness).toColor();
  }

  /// Convert dark theme to light theme
  AppTheme _toLightTheme(AppTheme darkTheme) {
    return AppTheme(
      // Swap bgDark and bgLight, invert all
      bgDark: _invertLightness(darkTheme.bgLight),
      bg: _invertLightness(darkTheme.bg),
      bgLight: _invertLightness(darkTheme.bgDark),
      // Invert text colors
      text: _invertLightness(darkTheme.text),
      textMuted: _invertLightness(darkTheme.textMuted),
      // Invert UI element colors
      highlight: _invertLightness(darkTheme.highlight),
      border: _invertLightness(darkTheme.border),
      borderMuted: _invertLightness(darkTheme.borderMuted),
      // Invert brand colors
      primary: _invertLightness(darkTheme.primary),
      primaryMuted: _invertLightness(darkTheme.primaryMuted),
      secondary: _invertLightness(darkTheme.secondary),
      secondaryMuted: _invertLightness(darkTheme.secondaryMuted),
      // Invert semantic colors
      danger: _invertLightness(darkTheme.danger),
      warning: _invertLightness(darkTheme.warning),
      success: _invertLightness(darkTheme.success),
      info: _invertLightness(darkTheme.info),
    );
  }

  /// Get the current dark theme
  AppTheme get _currentTheme => _generateDarkTheme(_bg, _primary, _secondary);

  /// Get the active theme (dark or light)
  AppTheme get _activeTheme =>
      _isDarkTheme ? _currentTheme : _toLightTheme(_currentTheme);

  void _toggleTheme() {
    setState(() {
      _isDarkTheme = !_isDarkTheme;
    });
  }

  void _updateColor(String colorName, Color newColor) {
    setState(() {
      switch (colorName) {
        case 'bg':
          _bg = newColor;
          break;
        case 'primary':
          _primary = newColor;
          break;
        case 'secondary':
          _secondary = newColor;
          break;
      }
    });
  }

  Color _getColorValue(String colorName) {
    switch (colorName) {
      case 'bg':
        return _bg;
      case 'primary':
        return _primary;
      case 'secondary':
        return _secondary;
      default:
        return Colors.black;
    }
  }

  void _resetTheme() {
    setState(() {
      final defaultTheme = AppTheme.defaultTheme();
      _bg = defaultTheme.bg;
      _primary = defaultTheme.primary;
      _secondary = defaultTheme.secondary;
      // Reset adjustments to defaults
      _bgLightAdjustment = 0.05;
      _bgDarkAdjustment = -0.05;
      _textMutedAdjustment = -0.25;
      _highlightAdjustment = -0.30;
      _borderAdjustment = -0.10;
      _borderMutedAdjustment = -0.10;
      _primaryMutedAdjustment = -0.50;
      _secondaryMutedAdjustment = -0.50;
    });
  }

  void _showColorConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => _ColorConfigDialog(
        isDarkTheme: _isDarkTheme,
        currentTheme: _currentTheme,
        bgLightAdjustment: _bgLightAdjustment,
        bgDarkAdjustment: _bgDarkAdjustment,
        textMutedAdjustment: _textMutedAdjustment,
        highlightAdjustment: _highlightAdjustment,
        borderAdjustment: _borderAdjustment,
        borderMutedAdjustment: _borderMutedAdjustment,
        primaryMutedAdjustment: _primaryMutedAdjustment,
        secondaryMutedAdjustment: _secondaryMutedAdjustment,
        onThemeToggle: () {
          setState(() {
            _toggleTheme();
          });
        },
        onReset: () {
          setState(() {
            _resetTheme();
          });
          Navigator.pop(context);
        },
        onColorChanged: (colorName, newColor) {
          setState(() {
            _updateColor(colorName, newColor);
          });
        },
        onAdjustmentChanged: (name, value) {
          setState(() {
            switch (name) {
              case 'bgLight':
                _bgLightAdjustment = value;
                break;
              case 'bgDark':
                _bgDarkAdjustment = value;
                break;
              case 'textMuted':
                _textMutedAdjustment = value;
                break;
              case 'highlight':
                _highlightAdjustment = value;
                break;
              case 'border':
                _borderAdjustment = value;
                break;
              case 'borderMuted':
                _borderMutedAdjustment = value;
                break;
              case 'primaryMuted':
                _primaryMutedAdjustment = value;
                break;
              case 'secondaryMuted':
                _secondaryMutedAdjustment = value;
                break;
            }
          });
        },
        getColorValue: _getColorValue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        extensions: <ThemeExtension<dynamic>>[
          _activeTheme,
          const AppFont(),
        ],
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Onboarding screen preview (no tutorial)
            IgnorePointer(
              // Disable interactions for preview
              child: _OnboardingPreview(
                realtime: OnboardingRealtime(initialLocale: 'US'),
              ),
            ),
            // Settings button
            Positioned(
              top: 16,
              right: 16,
              child: FloatingActionButton(
                onPressed: _showColorConfigDialog,
                child: const Icon(Icons.palette),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for configuring theme colors
class _ColorConfigDialog extends StatelessWidget {
  const _ColorConfigDialog({
    required this.isDarkTheme,
    required this.currentTheme,
    required this.bgLightAdjustment,
    required this.bgDarkAdjustment,
    required this.textMutedAdjustment,
    required this.highlightAdjustment,
    required this.borderAdjustment,
    required this.borderMutedAdjustment,
    required this.primaryMutedAdjustment,
    required this.secondaryMutedAdjustment,
    required this.onThemeToggle,
    required this.onReset,
    required this.onColorChanged,
    required this.onAdjustmentChanged,
    required this.getColorValue,
  });

  final bool isDarkTheme;
  final AppTheme currentTheme;
  final double bgLightAdjustment;
  final double bgDarkAdjustment;
  final double textMutedAdjustment;
  final double highlightAdjustment;
  final double borderAdjustment;
  final double borderMutedAdjustment;
  final double primaryMutedAdjustment;
  final double secondaryMutedAdjustment;
  final VoidCallback onThemeToggle;
  final VoidCallback onReset;
  final Function(String, Color) onColorChanged;
  final Function(String, double) onAdjustmentChanged;
  final Color Function(String) getColorValue;

  Widget _buildColorSection(
      String title, List<String> colorNames, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colorNames.map((colorName) {
            final color = getColorValue(colorName);
            return _ColorPickerButton(
              label: colorName,
              color: color,
              onColorChanged: (newColor) => onColorChanged(colorName, newColor),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildReadOnlyColorSection(
      String title, List<String> colorNames, BuildContext context) {
    final theme = currentTheme;
    Color getGeneratedColor(String name) {
      switch (name) {
        case 'bgDark':
          return theme.bgDark;
        case 'bgLight':
          return theme.bgLight;
        case 'text':
          return theme.text;
        case 'textMuted':
          return theme.textMuted;
        case 'highlight':
          return theme.highlight;
        case 'border':
          return theme.border;
        case 'borderMuted':
          return theme.borderMuted;
        case 'primaryMuted':
          return theme.primaryMuted;
        case 'secondaryMuted':
          return theme.secondaryMuted;
        default:
          return Colors.black;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colorNames.map((colorName) {
            final color = getGeneratedColor(colorName);
            return _ReadOnlyColorButton(
              label: colorName,
              color: color,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAdjustmentSlider(String name, String label, double value,
      double min, double max, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              Text(
                '${(value * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: 200, // 0.5% increments
            label: '${(value * 100).toStringAsFixed(0)}%',
            onChanged: (newValue) {
              onAdjustmentChanged(name, newValue);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // ignore: deprecated_member_use
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Theme Configuration',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Theme toggle
                      ElevatedButton.icon(
                        onPressed: onThemeToggle,
                        icon: Icon(
                            isDarkTheme ? Icons.dark_mode : Icons.light_mode),
                        label: Text(isDarkTheme ? 'Dark' : 'Light'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isDarkTheme ? Colors.blueGrey : Colors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Reset button
                      OutlinedButton(
                        onPressed: onReset,
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Color pickers - only show base colors
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Base Colors',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        // ignore: deprecated_member_use
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            // ignore: deprecated_member_use
                            ?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All other colors are automatically generated from these three base colors.',
                      style: TextStyle(
                        fontSize: 12,
                        // ignore: deprecated_member_use
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            // ignore: deprecated_member_use
                            ?.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildColorSection(
                        'Base Colors',
                        [
                          'bg',
                          'primary',
                          'secondary',
                        ],
                        context),
                    const SizedBox(height: 24),
                    // Adjustment controls
                    Text(
                      'Color Adjustments',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        // ignore: deprecated_member_use
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            // ignore: deprecated_member_use
                            ?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Adjust the lightness differences for generated colors.',
                      style: TextStyle(
                        fontSize: 12,
                        // ignore: deprecated_member_use
                        color: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color
                            // ignore: deprecated_member_use
                            ?.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildAdjustmentSlider('bgLight', 'Background Light',
                        bgLightAdjustment, -1.0, 1.0, context),
                    _buildAdjustmentSlider('bgDark', 'Background Dark',
                        bgDarkAdjustment, -1.0, 1.0, context),
                    _buildAdjustmentSlider('textMuted', 'Text Muted',
                        textMutedAdjustment, -1.0, 1.0, context),
                    _buildAdjustmentSlider('highlight', 'Highlight',
                        highlightAdjustment, -1.0, 1.0, context),
                    _buildAdjustmentSlider('border', 'Border', borderAdjustment,
                        -1.0, 1.0, context),
                    _buildAdjustmentSlider('borderMuted', 'Border Muted',
                        borderMutedAdjustment, -1.0, 1.0, context),
                    _buildAdjustmentSlider('primaryMuted', 'Primary Muted',
                        primaryMutedAdjustment, -1.0, 1.0, context),
                    _buildAdjustmentSlider('secondaryMuted', 'Secondary Muted',
                        secondaryMutedAdjustment, -1.0, 1.0, context),
                    const SizedBox(height: 16),
                    // Show generated colors (read-only preview)
                    Text(
                      'Generated Colors (Preview)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        // ignore: deprecated_member_use
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color
                            // ignore: deprecated_member_use
                            ?.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildReadOnlyColorSection(
                        'Backgrounds',
                        [
                          'bgDark',
                          'bgLight',
                        ],
                        context),
                    _buildReadOnlyColorSection(
                        'Text',
                        [
                          'text',
                          'textMuted',
                        ],
                        context),
                    _buildReadOnlyColorSection(
                        'UI Elements',
                        [
                          'highlight',
                          'border',
                          'borderMuted',
                        ],
                        context),
                    _buildReadOnlyColorSection(
                        'Brand',
                        [
                          'primaryMuted',
                          'secondaryMuted',
                        ],
                        context),
                  ],
                ),
              ),
            ),
            // Close button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Color picker button widget
class _ColorPickerButton extends StatelessWidget {
  const _ColorPickerButton({
    required this.label,
    required this.color,
    required this.onColorChanged,
  });

  final String label;
  final Color color;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final borderColor = theme.dividerColor;

    return InkWell(
      onTap: () async {
        final newColor = await showDialog<Color>(
          context: context,
          builder: (context) => _ColorPickerDialog(initialColor: color),
        );
        if (newColor != null) {
          onColorChanged(newColor);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: borderColor, width: 2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: textColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only color button widget (for generated colors)
class _ReadOnlyColorButton extends StatelessWidget {
  const _ReadOnlyColorButton({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyLarge?.color ?? Colors.black;
    final borderColor = theme.dividerColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor, width: 2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Color picker dialog
class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog({required this.initialColor});

  final Color initialColor;

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selectedColor;
  late TextEditingController _hslController;
  String? _hslError;

  @override
  void initState() {
    super.initState();
    _selectedColor = widget.initialColor;
    final hsl = HSLColor.fromColor(_selectedColor);
    _hslController = TextEditingController(
      text: _formatHSL(hsl.hue, hsl.saturation, hsl.lightness),
    );
  }

  @override
  void dispose() {
    _hslController.dispose();
    super.dispose();
  }

  String _formatHSL(double hue, double saturation, double lightness) {
    return '${hue.round()}, ${saturation.toStringAsFixed(2)}, ${lightness.toStringAsFixed(2)}';
  }

  void _updateColorFromHSL() {
    final text = _hslController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _hslError = null;
      });
      return;
    }

    // Parse formats like:
    // "336, 0.0, 0.01"
    // "336,0.0,0.01"
    // "336 0.0 0.01"
    final parts =
        text.split(RegExp(r'[,\s]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length != 3) {
      setState(() {
        _hslError = 'Invalid format. Use: H, S, L (e.g., 336, 0.0, 0.01)';
      });
      return;
    }

    final hue = double.tryParse(parts[0]);
    final saturation = double.tryParse(parts[1]);
    final lightness = double.tryParse(parts[2]);

    if (hue == null || saturation == null || lightness == null) {
      setState(() {
        _hslError = 'Invalid numbers';
      });
      return;
    }

    if (hue < 0 || hue > 360) {
      setState(() {
        _hslError = 'Hue must be 0-360';
      });
      return;
    }

    if (saturation < 0 || saturation > 1 || lightness < 0 || lightness > 1) {
      setState(() {
        _hslError = 'Saturation and lightness must be 0-1';
      });
      return;
    }

    final newColor =
        HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
    // Only update if color actually changed to avoid unnecessary rebuilds
    // ignore: deprecated_member_use
    if (_selectedColor.value != newColor.value) {
      setState(() {
        _selectedColor = newColor;
        _hslError = null;
      });
    } else {
      // Clear error if color is valid
      if (_hslError != null) {
        setState(() {
          _hslError = null;
        });
      }
    }
  }

  void _updateHSLDisplay() {
    final hsl = HSLColor.fromColor(_selectedColor);
    final newText = _formatHSL(hsl.hue, hsl.saturation, hsl.lightness);
    // Only update if the text is different to avoid cursor jumping
    if (_hslController.text != newText && !_hslController.selection.isValid) {
      _hslController.text = newText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hsl = HSLColor.fromColor(_selectedColor);

    return AlertDialog(
      title: const Text('Pick Color'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Hue slider
          Row(
            children: [
              const SizedBox(width: 80, child: Text('Hue:')),
              Expanded(
                child: Slider(
                  value: hsl.hue,
                  min: 0,
                  max: 360,
                  divisions: 360,
                  label: hsl.hue.round().toString(),
                  onChanged: (value) {
                    setState(() {
                      _selectedColor = hsl.withHue(value).toColor();
                      _updateHSLDisplay();
                    });
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(hsl.hue.round().toString()),
              ),
            ],
          ),
          // Saturation slider
          Row(
            children: [
              const SizedBox(width: 80, child: Text('Sat:')),
              Expanded(
                child: Slider(
                  value: hsl.saturation,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  label: (hsl.saturation * 100).round().toString(),
                  onChanged: (value) {
                    setState(() {
                      _selectedColor = hsl.withSaturation(value).toColor();
                      _updateHSLDisplay();
                    });
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: Text('${(hsl.saturation * 100).round()}%'),
              ),
            ],
          ),
          // Lightness slider
          Row(
            children: [
              const SizedBox(width: 80, child: Text('Light:')),
              Expanded(
                child: Slider(
                  value: hsl.lightness,
                  min: 0,
                  max: 1,
                  divisions: 100,
                  label: (hsl.lightness * 100).round().toString(),
                  onChanged: (value) {
                    setState(() {
                      _selectedColor = hsl.withLightness(value).toColor();
                      _updateHSLDisplay();
                    });
                  },
                ),
              ),
              SizedBox(
                width: 60,
                child: Text('${(hsl.lightness * 100).round()}%'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // HSL text input
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('HSL (H, S, L):'),
              const SizedBox(height: 8),
              TextField(
                controller: _hslController,
                decoration: InputDecoration(
                  hintText: 'e.g., 336, 0.0, 0.01',
                  border: const OutlineInputBorder(),
                  errorText: _hslError,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste),
                    tooltip: 'Paste HSL values',
                    onPressed: () async {
                      // Try to paste from clipboard
                      final clipboard = await Clipboard.getData('text/plain');
                      if (clipboard?.text != null) {
                        _hslController.text = clipboard!.text!;
                        _updateColorFromHSL();
                      }
                    },
                  ),
                ),
                onChanged: (_) => _updateColorFromHSL(),
                onSubmitted: (_) => _updateColorFromHSL(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Color preview
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: _selectedColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedColor),
          child: const Text('OK'),
        ),
      ],
    );
  }
}

/// Simplified onboarding preview (no tutorial logic)
class _OnboardingPreview extends StatelessWidget {
  const _OnboardingPreview({required this.realtime});

  final OnboardingRealtime realtime;

  @override
  Widget build(BuildContext context) {
    return QuestionScreenV2(
      gameId: 'onboarding',
      realtime: realtime,
      questionCount: 1,
      isHost: true,
      showLeaveButton: false,
    );
  }
}
