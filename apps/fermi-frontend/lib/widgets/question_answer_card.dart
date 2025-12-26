import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fermi_frontend/widgets/question_widget.dart';
import 'package:fermi_frontend/widgets/answer_accuracy_scale.dart';
import 'package:fermi_frontend/widgets/slider_text_mirror.dart';
import 'package:fermi_frontend/widgets/unit_tape.dart';
import 'package:fermi_frontend/models/answer_value.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

const double kQuestionAnswerCardQuestionHeight = 24.0 * 5;
const double kQuestionAnswerCardAnswerRowHeight = 60.0;
const double kQuestionAnswerCardAccuracyScaleHeight = 48.0;
const double kQuestionAnswerCardSpacing = 24.0;
const double kQuestionAnswerCardQuestionToDividerSpacing = 0.0;

/// A reusable card widget that displays a question and answer input area.
///
/// This widget encapsulates the bordered card UI used in both party mode
/// and daily question screens. It contains:
/// - Question text with tags
/// - Horizontal divider
/// - Answer input row (SliderTextMirror + UnitTape)
/// - Answer accuracy scale
/// - Optional button widget
class QuestionAnswerCard extends StatelessWidget {
  const QuestionAnswerCard({
    super.key,
    required this.questionText,
    required this.tags,
    required this.currentAnswer,
    required this.submittedAnswer,
    required this.unitOptions,
    required this.units,
    required this.currentLocale,
    required this.onAnswerChanged,
    required this.onLocaleChanged,
    required this.editable,
    this.revealedAnswer,
    this.revealedColor,
    this.unitOptionsNotifier,
    this.unitTapeController,
    this.questionWidgetKey,
    this.unitKey,
    this.answerScaleKey,
    this.buttonWidget,
    this.allowCopy = false,
    // Other players' converted answers
    this.otherPlayersAnswers,
    this.otherPlayersAvatars,
    this.currentPlayerAvatarUrl,
  });

  final String questionText;
  final List<String> tags;
  final AnswerValue currentAnswer;
  final AnswerValue? submittedAnswer;
  final Map<String, String> unitOptions;
  final List<String> units;
  final String currentLocale;
  final ValueChanged<AnswerValue> onAnswerChanged;
  final ValueChanged<String> onLocaleChanged;
  final bool editable;
  final AnswerValue? revealedAnswer;
  final Color? revealedColor;
  final ValueNotifier<Map<String, String>>? unitOptionsNotifier;
  final UnitTapeController? unitTapeController;
  final Key? questionWidgetKey;
  final Key? unitKey;
  final Key? answerScaleKey;
  final Widget? buttonWidget;
  final bool allowCopy;
  // Other players' converted answers
  final Map<String, AnswerValue>? otherPlayersAnswers;
  final Map<String, String?>? otherPlayersAvatars;
  final String? currentPlayerAvatarUrl;

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: questionText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Question copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Color.alphaBlend(
            // ignore: deprecated_member_use
            revealedColor?.withOpacity(0.1) ?? Colors.transparent,
            appTheme.bgLight),
        borderRadius: BorderRadius.circular(appTheme.borderRadius),
        boxShadow: [
          BoxShadow(
            color: revealedColor ?? appTheme.shadowColor,
            offset: appTheme.shadowOffset,
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(appTheme.borderRadius),
        child: InkWell(
          onLongPress: allowCopy ? () => _copyToClipboard(context) : null,
          borderRadius: BorderRadius.circular(appTheme.borderRadius),
          splashColor:
              // ignore: deprecated_member_use
              appTheme.primary.withOpacity(0.12),
          highlightColor:
              // ignore: deprecated_member_use
              appTheme.primary.withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.all(kQuestionAnswerCardSpacing),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Question widget (without border, just text + tags)
                QuestionWidget(
                  key: questionWidgetKey,
                  text: questionText,
                  tags: tags,
                  height: kQuestionAnswerCardQuestionHeight,
                  showBorder: false,
                  bottomSpacing: 24.0,
                  revealedColor: revealedColor,
                ),
                const SizedBox(
                    height: kQuestionAnswerCardQuestionToDividerSpacing),
                // Horizontal separator between question and answer area
                Divider(
                  height: 1,
                  thickness: 1,
                  color:
                      // ignore: deprecated_member_use
                      appTheme.border.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                // Answer display row: SliderTextMirror (left) + UnitTape (right)
                SizedBox(
                  height: kQuestionAnswerCardAnswerRowHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // SliderTextMirror on the left
                      SliderTextMirror(
                        value: currentAnswer,
                        unitOptions: unitOptions,
                      ),
                      // UnitTape on the right (if units available)
                      if (units.isNotEmpty)
                        UnitTape(
                          key: unitKey,
                          units: units,
                          unitOptions: unitOptions,
                          initialValue: currentAnswer.unit,
                          currentLocale: currentLocale,
                          onUnitChanged: (unit) => onAnswerChanged(
                            currentAnswer.copyWith(unit: unit),
                          ),
                          onLocaleChanged: onLocaleChanged,
                          editable: editable,
                          unitOptionsNotifier: unitOptionsNotifier,
                          controller: unitTapeController,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Answer Accuracy Scale
                AnswerAccuracyScale(
                  key: answerScaleKey,
                  currentAnswer: currentAnswer,
                  submittedAnswer: submittedAnswer,
                  revealedAnswer: revealedAnswer,
                  revealedColor: revealedColor,
                  editable: editable,
                  otherPlayersAnswers: otherPlayersAnswers,
                  otherPlayersAvatars: otherPlayersAvatars,
                  currentPlayerAvatarUrl: currentPlayerAvatarUrl,
                  onAnswerChanged: editable ? onAnswerChanged : null,
                ),
                // Button widget (if provided)
                if (buttonWidget != null) ...[
                  const SizedBox(height: 48.0),
                  buttonWidget!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
