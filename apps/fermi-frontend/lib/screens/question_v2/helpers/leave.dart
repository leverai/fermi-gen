import 'package:flutter/material.dart';
import 'package:fermi_frontend/widgets/styled_dialog.dart';

typedef LeaveConfirmed = Future<void> Function();

Future<void> confirmLeaveDialog({
  required BuildContext context,
  required Color highlightColor,
  required LeaveConfirmed onConfirm,
}) async {
  final bool? ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return _LeaveDialog(
        highlightColor: highlightColor,
      );
    },
  );
  if (ok == true) {
    await onConfirm();
  }
}

/// Styled leave confirmation dialog matching the tutorial dialog design.
///
/// Shows a primary message, secondary message, and two action buttons:
/// - Cancel: Dismisses the dialog without leaving
/// - Leave: Confirms leaving the game
class _LeaveDialog extends StatelessWidget {
  const _LeaveDialog({
    required this.highlightColor,
  });

  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    return StyledDialog(
      message: 'Leave game?',
      secondaryMessage: 'Are you sure you want to leave this game?',
      primaryButtonLabel: 'Leave',
      primaryButtonColor: highlightColor,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      secondaryButtonLabel: 'Cancel',
      onSecondaryPressed: () => Navigator.of(context).pop(false),
      showAsDialog: true,
    );
  }
}
