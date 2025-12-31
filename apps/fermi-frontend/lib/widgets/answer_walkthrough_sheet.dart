import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/serp_text_block.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/answer_walkthrough_blocks.dart';
import 'package:fermi_frontend/widgets/answer_walkthrough_references.dart';

/// A bottom sheet that displays a parsed SerpAPI AI response
/// in a human-readable, scrollable format.
class AnswerWalkthroughSheet extends StatelessWidget {
  const AnswerWalkthroughSheet({
    super.key,
    required this.response,
    this.title = 'Answer Walkthrough',
  });

  final SerpAiResponse response;
  final String title;

  /// Show the sheet as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required SerpAiResponse response,
    String title = 'Answer Walkthrough',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AnswerWalkthroughSheet(
        response: response,
        title: title,
      ),
    );
  }

  /// Try to show the sheet from raw JSON string.
  /// Returns false if parsing fails.
  static Future<bool> showFromJson(
    BuildContext context, {
    required String jsonString,
    String title = 'Answer Walkthrough',
  }) async {
    final response = SerpAiResponse.tryParse(jsonString);
    if (response == null || !response.hasContent) {
      return false;
    }
    await show(context, response: response, title: title);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: appTheme.bgLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: appTheme.shadowColor,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: appTheme.borderMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 48), // Balance for the close button
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: appTheme.text,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.keyboard_arrow_down,
                      color: appTheme.text, size: 32),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: _AnswerWalkthroughContent(
              response: response,
              appTheme: appTheme,
            ),
          ),
        ],
      ),
    );
  }
}

/// The scrollable content area of the walkthrough sheet.
class _AnswerWalkthroughContent extends StatelessWidget {
  const _AnswerWalkthroughContent({
    required this.response,
    required this.appTheme,
  });

  final SerpAiResponse response;
  final AppTheme appTheme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      children: [
        // AI header badge
        _AiHeaderBadge(appTheme: appTheme),
        const SizedBox(height: 16),

        // Text blocks
        ...response.textBlocks.map(
          (block) => Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: TextBlockRenderer(
              block: block,
              response: response,
              appTheme: appTheme,
            ),
          ),
        ),

        // References section
        if (response.references.isNotEmpty) ...[
          const SizedBox(height: 16),
          Divider(color: appTheme.borderMuted, thickness: 1),
          const SizedBox(height: 16),
          ReferencesSection(
            references: response.references,
            appTheme: appTheme,
          ),
        ],

        // Bottom padding
        const SizedBox(height: 32),
      ],
    );
  }
}

/// AI Overview header badge similar to Google's AI search.
class _AiHeaderBadge extends StatelessWidget {
  const _AiHeaderBadge({required this.appTheme});

  final AppTheme appTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                appTheme.primary.withAlpha(40),
                appTheme.secondary.withAlpha(40),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: appTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'AI Overview',
                style: AppFont.primaryTextStyle(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: appTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
