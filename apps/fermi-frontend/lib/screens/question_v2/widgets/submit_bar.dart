import 'package:flutter/material.dart';
import 'package:fermi_frontend/widgets/main_button.dart';
import 'package:fermi_frontend/screens/question_v2/models/question_state.dart';
import 'package:fermi_frontend/widgets/circular_determinate_spinner.dart';

class SubmitBar extends StatelessWidget {
  const SubmitBar({
    super.key,
    required this.state,
    required this.isLast,
    required this.isHost,
    required this.onSubmit,
    required this.onNext,
    this.autoNextProgress = 0.0,
    this.questionDeadlineProgress = 0.0,
    this.questionDeadlineColor,
    this.autoNextColor,
    this.mainButtonController,
    this.submitButtonKey,
  });

  final QuestionPaneState state;
  final bool isLast;
  final bool isHost;
  final VoidCallback onSubmit;
  final VoidCallback onNext;
  final double autoNextProgress; // 0..1 when in finished state
  final double questionDeadlineProgress; // 0..1 for question deadline countdown
  final Color? questionDeadlineColor; // Color for question deadline indicator
  final Color? autoNextColor; // Color for auto-next indicator
  final MainButtonController? mainButtonController;
  final Key? submitButtonKey; // Key for the main action button (for tutorial)

  @override
  Widget build(BuildContext context) {
    switch (state) {
      case QuestionPaneState.started:
        return SizedBox(
          width: double.infinity,
          child: MainButton(
            key: submitButtonKey,
            onPressed: onSubmit,
            label: MainButtonLabel.submit,
            showSpacebarGlyph: true,
          ),
        );
      case QuestionPaneState.locked:
        return const SizedBox(
          width: double.infinity,
          child: MainButton(
            onPressed: null,
            isLoading: true,
          ),
        );
      case QuestionPaneState.finished:
        if (isLast) {
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: double.infinity,
                child: MainButton(
                  onPressed: onNext,
                  label: MainButtonLabel.finish,
                  showSpacebarGlyph: true,
                  controller: mainButtonController,
                ),
              ),
              if (isHost && autoNextProgress > 0 && autoNextProgress < 1.0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      // ignore: deprecated_member_use
                      color: Colors.white.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CircularDeterminateSpinner(
                        progress: autoNextProgress,
                        color: autoNextColor,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: double.infinity,
              child: MainButton(
                onPressed: isHost ? onNext : null,
                label: MainButtonLabel.next,
                showSpacebarGlyph: true,
                isLoading: false,
                controller: mainButtonController,
              ),
            ),
            if (autoNextProgress > 0 && autoNextProgress < 1.0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    // ignore: deprecated_member_use
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: CircularDeterminateSpinner(
                      progress: autoNextProgress,
                      color: autoNextColor,
                    ),
                  ),
                ),
              ),
          ],
        );
    }
  }
}
