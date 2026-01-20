import 'package:flutter/material.dart';
import 'package:fermi_frontend/services/feedback_service.dart';

class LeaveButtonOverlay extends StatelessWidget {
  const LeaveButtonOverlay({
    super.key,
    required this.iconColor,
    required this.splashColor,
    required this.onPressed,
  });

  final Color iconColor;
  final Color splashColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 48,
          height: 48,
          child: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            onPressed: () {
              FeedbackService.instance.secondaryClick();
              onPressed();
            },
            icon: const Icon(Icons.arrow_back),
            color: iconColor,
            splashRadius: 22,
            splashColor: splashColor,
            tooltip: 'Leave',
          ),
        ),
      ),
    );
  }
}
