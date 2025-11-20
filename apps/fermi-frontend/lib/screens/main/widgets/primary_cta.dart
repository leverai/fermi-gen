import 'package:flutter/material.dart';
import 'package:fermi_frontend/widgets/main_button.dart';

class PrimaryCta extends StatelessWidget {
  const PrimaryCta({
    super.key,
    required this.isLoading,
    required this.onPressed,
    required this.isLocked,
  });

  final bool isLoading;
  final VoidCallback? onPressed;
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MainButton(
        onPressed: isLoading ? null : onPressed,
        isLoading: isLoading,
        label: isLocked ? MainButtonLabel.create : MainButtonLabel.join,
        showSpacebarGlyph: true,
        iconAssetPath: 'assets/icons/spacebar.svg',
      ),
    );
  }
}
