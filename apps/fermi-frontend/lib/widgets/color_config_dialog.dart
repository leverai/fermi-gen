import 'package:flutter/material.dart';
import 'package:fermi_frontend/state/theme_config_service.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// Dialog widget for configuring theme colors.
///
/// Provides text inputs for HSL values and diff percentages, along with
/// reset and theme toggle buttons.
class ColorConfigDialog extends StatefulWidget {
  const ColorConfigDialog({
    super.key,
    required this.themeConfigService,
  });

  final ThemeConfigService themeConfigService;

  @override
  State<ColorConfigDialog> createState() => _ColorConfigDialogState();
}

class _ColorConfigDialogState extends State<ColorConfigDialog> {
  late final Map<String, TextEditingController> _controllers;
  final TextEditingController _saveNameController = TextEditingController();
  String? _selectedConfigName;

  @override
  void initState() {
    super.initState();
    _controllers = _createControllers();
    _updateControllers();
    _loadSavedNames();
    widget.themeConfigService.addListener(_onServiceChanged);
  }

  void _onServiceChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadSavedNames() async {
    await widget.themeConfigService.refreshSavedConfigurationNames();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    widget.themeConfigService.removeListener(_onServiceChanged);
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _saveNameController.dispose();
    super.dispose();
  }

  Map<String, TextEditingController> _createControllers() {
    return {
      'bg': TextEditingController(),
      'primary': TextEditingController(),
      'secondary': TextEditingController(),
      'text': TextEditingController(),
      'success': TextEditingController(),
      'danger': TextEditingController(),
      'highlight': TextEditingController(),
      'border': TextEditingController(),
      'bgLightDiff': TextEditingController(),
      'bgDarkDiff': TextEditingController(),
      'textMutedDiff': TextEditingController(),
      'borderMutedDiff': TextEditingController(),
    };
  }

  String _formatHsl(double hue, double saturation, double lightness) {
    return '${hue.round()}, ${(saturation * 100).round()}%, ${(lightness * 100).round()}%';
  }

  void _updateControllers() {
    if (!mounted) return;
    // Format HSL values as "H, S%, L%"
    _controllers['bg']!.text = _formatHsl(
      widget.themeConfigService.bgH,
      widget.themeConfigService.bgS,
      widget.themeConfigService.bgL,
    );
    _controllers['primary']!.text = _formatHsl(
      widget.themeConfigService.primaryH,
      widget.themeConfigService.primaryS,
      widget.themeConfigService.primaryL,
    );
    _controllers['secondary']!.text = _formatHsl(
      widget.themeConfigService.secondaryH,
      widget.themeConfigService.secondaryS,
      widget.themeConfigService.secondaryL,
    );
    _controllers['text']!.text = _formatHsl(
      widget.themeConfigService.textH,
      widget.themeConfigService.textS,
      widget.themeConfigService.textL,
    );
    _controllers['success']!.text = _formatHsl(
      widget.themeConfigService.successH,
      widget.themeConfigService.successS,
      widget.themeConfigService.successL,
    );
    _controllers['danger']!.text = _formatHsl(
      widget.themeConfigService.dangerH,
      widget.themeConfigService.dangerS,
      widget.themeConfigService.dangerL,
    );
    _controllers['highlight']!.text = _formatHsl(
      widget.themeConfigService.highlightH,
      widget.themeConfigService.highlightS,
      widget.themeConfigService.highlightL,
    );
    _controllers['border']!.text = _formatHsl(
      widget.themeConfigService.borderH,
      widget.themeConfigService.borderS,
      widget.themeConfigService.borderL,
    );
    _controllers['bgLightDiff']!.text =
        widget.themeConfigService.bgLightDiff.round().toString();
    _controllers['bgDarkDiff']!.text =
        widget.themeConfigService.bgDarkDiff.round().toString();
    _controllers['textMutedDiff']!.text =
        widget.themeConfigService.textMutedDiff.round().toString();
    _controllers['borderMutedDiff']!.text =
        widget.themeConfigService.borderMutedDiff.round().toString();
  }

  /// Parses HSL string in format "H, S%, L%" or "H, S, L"
  /// Returns (hue, saturation, lightness) or null if parsing fails
  (double?, double?, double?) _parseHsl(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return (null, null, null);

    // Remove all % signs and split by comma or whitespace
    final cleaned = trimmed.replaceAll('%', '');
    final parts =
        cleaned.split(RegExp(r'[,\s]+')).where((p) => p.isNotEmpty).toList();

    if (parts.length != 3) return (null, null, null);

    final hue = double.tryParse(parts[0]);
    final saturation = double.tryParse(parts[1]);
    final lightness = double.tryParse(parts[2]);

    if (hue == null || saturation == null || lightness == null) {
      return (null, null, null);
    }

    // Validate ranges
    if (hue < 0 || hue > 360) return (null, null, null);
    if (saturation < 0 || saturation > 100) return (null, null, null);
    if (lightness < 0 || lightness > 100) return (null, null, null);

    // Convert saturation and lightness from 0-100 to 0-1
    return (hue, saturation / 100.0, lightness / 100.0);
  }

  void _applyChanges() {
    // Parse and apply HSL values
    final bgHsl = _parseHsl(_controllers['bg']!.text);
    if (bgHsl.$1 != null) widget.themeConfigService.setBgH(bgHsl.$1!);
    if (bgHsl.$2 != null) widget.themeConfigService.setBgS(bgHsl.$2!);
    if (bgHsl.$3 != null) widget.themeConfigService.setBgL(bgHsl.$3!);

    final primaryHsl = _parseHsl(_controllers['primary']!.text);
    if (primaryHsl.$1 != null) {
      widget.themeConfigService.setPrimaryH(primaryHsl.$1!);
    }
    if (primaryHsl.$2 != null) {
      widget.themeConfigService.setPrimaryS(primaryHsl.$2!);
    }
    if (primaryHsl.$3 != null) {
      widget.themeConfigService.setPrimaryL(primaryHsl.$3!);
    }

    final secondaryHsl = _parseHsl(_controllers['secondary']!.text);
    if (secondaryHsl.$1 != null) {
      widget.themeConfigService.setSecondaryH(secondaryHsl.$1!);
    }
    if (secondaryHsl.$2 != null) {
      widget.themeConfigService.setSecondaryS(secondaryHsl.$2!);
    }
    if (secondaryHsl.$3 != null) {
      widget.themeConfigService.setSecondaryL(secondaryHsl.$3!);
    }

    final textHsl = _parseHsl(_controllers['text']!.text);
    if (textHsl.$1 != null) widget.themeConfigService.setTextH(textHsl.$1!);
    if (textHsl.$2 != null) widget.themeConfigService.setTextS(textHsl.$2!);
    if (textHsl.$3 != null) widget.themeConfigService.setTextL(textHsl.$3!);

    final successHsl = _parseHsl(_controllers['success']!.text);
    if (successHsl.$1 != null) {
      widget.themeConfigService.setSuccessH(successHsl.$1!);
    }
    if (successHsl.$2 != null) {
      widget.themeConfigService.setSuccessS(successHsl.$2!);
    }
    if (successHsl.$3 != null) {
      widget.themeConfigService.setSuccessL(successHsl.$3!);
    }

    final dangerHsl = _parseHsl(_controllers['danger']!.text);
    if (dangerHsl.$1 != null) {
      widget.themeConfigService.setDangerH(dangerHsl.$1!);
    }
    if (dangerHsl.$2 != null) {
      widget.themeConfigService.setDangerS(dangerHsl.$2!);
    }
    if (dangerHsl.$3 != null) {
      widget.themeConfigService.setDangerL(dangerHsl.$3!);
    }

    final highlightHsl = _parseHsl(_controllers['highlight']!.text);
    if (highlightHsl.$1 != null) {
      widget.themeConfigService.setHighlightH(highlightHsl.$1!);
    }
    if (highlightHsl.$2 != null) {
      widget.themeConfigService.setHighlightS(highlightHsl.$2!);
    }
    if (highlightHsl.$3 != null) {
      widget.themeConfigService.setHighlightL(highlightHsl.$3!);
    }

    final borderHsl = _parseHsl(_controllers['border']!.text);
    if (borderHsl.$1 != null) {
      widget.themeConfigService.setBorderH(borderHsl.$1!);
    }
    if (borderHsl.$2 != null) {
      widget.themeConfigService.setBorderS(borderHsl.$2!);
    }
    if (borderHsl.$3 != null) {
      widget.themeConfigService.setBorderL(borderHsl.$3!);
    }

    // Parse and apply diff values
    final bgLightDiff = int.tryParse(_controllers['bgLightDiff']!.text);
    final bgDarkDiff = int.tryParse(_controllers['bgDarkDiff']!.text);
    final textMutedDiff = int.tryParse(_controllers['textMutedDiff']!.text);
    final borderMutedDiff = int.tryParse(_controllers['borderMutedDiff']!.text);

    if (bgLightDiff != null) {
      widget.themeConfigService
          .setBgLightDiff(bgLightDiff.clamp(-100, 100).toDouble());
    }
    if (bgDarkDiff != null) {
      widget.themeConfigService
          .setBgDarkDiff(bgDarkDiff.clamp(-100, 100).toDouble());
    }
    if (textMutedDiff != null) {
      widget.themeConfigService
          .setTextMutedDiff(textMutedDiff.clamp(-100, 100).toDouble());
    }
    if (borderMutedDiff != null) {
      widget.themeConfigService
          .setBorderMutedDiff(borderMutedDiff.clamp(-100, 100).toDouble());
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Dialog(
      backgroundColor: appTheme.bg,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: ListenableBuilder(
          listenable: widget.themeConfigService,
          builder: (context, _) {
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Color Configuration',
                    style: TextStyle(
                      color: appTheme.text,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // BG HSL
                  _buildSectionTitle('Background (HSL)', appTheme),
                  _buildHslInput(
                    label: 'BG',
                    controller: _controllers['bg']!,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 16),

                  // Primary HSL
                  _buildSectionTitle('Primary (HSL)', appTheme),
                  _buildHslInput(
                    label: 'Primary',
                    controller: _controllers['primary']!,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 16),

                  // Secondary HSL
                  _buildSectionTitle('Secondary (HSL)', appTheme),
                  _buildHslInput(
                    label: 'Secondary',
                    controller: _controllers['secondary']!,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 16),

                  // Text HSL
                  _buildSectionTitle('Text (HSL)', appTheme),
                  _buildHslInput(
                    label: 'Text',
                    controller: _controllers['text']!,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 16),

                  // Success HSL
                  _buildSectionTitle('Success (HSL)', appTheme),
                  _buildHslInput(
                    label: 'Success',
                    controller: _controllers['success']!,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 16),

                  // Danger HSL
                  _buildSectionTitle('Danger (HSL)', appTheme),
                  _buildHslInput(
                    label: 'Danger',
                    controller: _controllers['danger']!,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 16),

                  // Highlight HSL
                  _buildSectionTitle('Highlight (HSL)', appTheme),
                  _buildHslInput(
                    label: 'Highlight',
                    controller: _controllers['highlight']!,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 16),

                  // Border HSL
                  _buildSectionTitle('Border (HSL)', appTheme),
                  _buildHslInput(
                    label: 'Border',
                    controller: _controllers['border']!,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 16),

                  // Diff values
                  _buildSectionTitle('Diff Values (%)', appTheme),
                  _buildDiffInput(
                    label: 'bgLightDiff',
                    controller: _controllers['bgLightDiff']!,
                    appTheme: appTheme,
                  ),
                  _buildDiffInput(
                    label: 'bgDarkDiff',
                    controller: _controllers['bgDarkDiff']!,
                    appTheme: appTheme,
                  ),
                  _buildDiffInput(
                    label: 'textMutedDiff',
                    controller: _controllers['textMutedDiff']!,
                    appTheme: appTheme,
                  ),
                  _buildDiffInput(
                    label: 'borderMutedDiff',
                    controller: _controllers['borderMutedDiff']!,
                    appTheme: appTheme,
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          widget.themeConfigService.reset();
                          _updateControllers();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appTheme.warning,
                          foregroundColor: appTheme.bg,
                        ),
                        child: const Text('Reset'),
                      ),
                      ElevatedButton(
                        onPressed: widget.themeConfigService.toggleThemeMode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appTheme.info,
                          foregroundColor: appTheme.bg,
                        ),
                        child: Text(widget.themeConfigService.isLightMode
                            ? 'DM'
                            : 'LM'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appTheme.primary,
                          foregroundColor: appTheme.bg,
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Save/Load section
                  _buildSectionTitle('Save/Load Configurations', appTheme),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextInputField(
                          label: 'Configuration Name',
                          controller: _saveNameController,
                          appTheme: appTheme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          final name = _saveNameController.text.trim();
                          if (name.isEmpty) return;
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          await widget.themeConfigService
                              .saveConfiguration(name);
                          await _loadSavedNames();
                          _saveNameController.clear();
                          if (!mounted) return;
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Saved: $name'),
                              backgroundColor: appTheme.success,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appTheme.info,
                          foregroundColor: appTheme.bg,
                        ),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDropdown(
                          label: 'Saved Configurations',
                          value: _selectedConfigName,
                          items: widget.themeConfigService
                              .getSavedConfigurationNames(),
                          onChanged: (value) {
                            setState(() {
                              _selectedConfigName = value;
                            });
                          },
                          appTheme: appTheme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _selectedConfigName == null
                            ? null
                            : () async {
                                final scaffoldMessenger =
                                    ScaffoldMessenger.of(context);
                                final success = await widget.themeConfigService
                                    .loadConfiguration(_selectedConfigName!);
                                if (success) {
                                  _updateControllers();
                                  if (!mounted) return;
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content:
                                          Text('Loaded: $_selectedConfigName'),
                                      backgroundColor: appTheme.success,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                } else {
                                  if (!mounted) return;
                                  scaffoldMessenger.showSnackBar(
                                    SnackBar(
                                      content: const Text('Failed to load'),
                                      backgroundColor: appTheme.danger,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appTheme.primary,
                          foregroundColor: appTheme.bg,
                        ),
                        child: const Text('Load'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Apply button
                  ElevatedButton(
                    onPressed: _applyChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: appTheme.success,
                      foregroundColor: appTheme.bg,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Apply',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, AppTheme appTheme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        title,
        style: TextStyle(
          color: appTheme.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildHslInput({
    required String label,
    required TextEditingController controller,
    required AppTheme appTheme,
  }) {
    return _buildTextField(
      label: '$label (format: H, S%, L%)',
      controller: controller,
      appTheme: appTheme,
    );
  }

  Widget _buildDiffInput({
    required String label,
    required TextEditingController controller,
    required AppTheme appTheme,
  }) {
    return _buildTextField(
      label: label,
      controller: controller,
      appTheme: appTheme,
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required AppTheme appTheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: appTheme.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.text,
            style: TextStyle(
              color: appTheme.text,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: appTheme.bgLight,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: appTheme.border),
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: appTheme.border),
                borderRadius: BorderRadius.circular(4),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: appTheme.primary, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextInputField({
    required String label,
    required TextEditingController controller,
    required AppTheme appTheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: appTheme.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: TextInputType.text,
            style: TextStyle(
              color: appTheme.text,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: appTheme.bgLight,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: appTheme.border),
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: appTheme.border),
                borderRadius: BorderRadius.circular(4),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: appTheme.primary, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required AppTheme appTheme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: appTheme.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: value,
            items: items.isEmpty
                ? [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('None'),
                    ),
                  ]
                : items.map((name) {
                    return DropdownMenuItem<String>(
                      value: name,
                      child: Text(name),
                    );
                  }).toList(),
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: appTheme.bgLight,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: appTheme.border),
                borderRadius: BorderRadius.circular(4),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: appTheme.border),
                borderRadius: BorderRadius.circular(4),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: appTheme.primary, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            style: TextStyle(
              color: appTheme.text,
              fontSize: 14,
            ),
            dropdownColor: appTheme.bgLight,
            iconEnabledColor: appTheme.text,
          ),
        ],
      ),
    );
  }
}
