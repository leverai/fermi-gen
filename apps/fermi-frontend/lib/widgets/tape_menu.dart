import 'package:flutter/material.dart';
import 'package:fermi_frontend/theme/app_font.dart';

/// A generic menu widget that displays a list of selectable options
class TapeMenu extends StatelessWidget {
  const TapeMenu({
    super.key,
    required this.options,
    required this.currentValue,
    required this.foregroundColor,
    required this.foregroundNegativeColor,
    required this.foregroundP30Color,
    required this.onSelect,
    this.noneOptionKey,
  });

  final Map<String, String> options; // Display name -> value
  final String currentValue;
  final Color foregroundColor;
  final Color foregroundNegativeColor;
  final Color foregroundP30Color;
  final ValueChanged<String> onSelect;
  final String?
      noneOptionKey; // Key that represents "none" option for special styling

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Close menu when tapping outside
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GestureDetector(
            onTap: () {
              // Prevent closing when tapping on the menu itself
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: options.entries.map((entry) {
                final isSelected = entry.value == currentValue;
                final isNoneOption =
                    noneOptionKey != null && entry.key == noneOptionKey;

                Color textColor;
                if (isSelected) {
                  textColor = foregroundNegativeColor;
                } else if (isNoneOption) {
                  textColor = foregroundP30Color;
                } else {
                  textColor = foregroundColor;
                }

                return GestureDetector(
                  onTap: () {
                    onSelect(entry.value);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12.0, horizontal: 24.0),
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontFamily: AppFont.of(context),
                        fontSize: 26,
                        fontWeight: FontWeight.w600, // SemiBold weight
                        color: textColor,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}
