import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/serp_text_block.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/latex_text_renderer.dart';

/// Renders a single text block based on its type.
class TextBlockRenderer extends StatelessWidget {
  const TextBlockRenderer({
    super.key,
    required this.block,
    required this.response,
    required this.appTheme,
    this.indentLevel = 0,
  });

  final SerpTextBlock block;
  final SerpAiResponse response;
  final AppTheme appTheme;
  final int indentLevel;

  @override
  Widget build(BuildContext context) {
    return switch (block) {
      SerpHeadingBlock block => HeadingBlockWidget(
          block: block,
          appTheme: appTheme,
        ),
      SerpParagraphBlock block => ParagraphBlockWidget(
          block: block,
          response: response,
          appTheme: appTheme,
        ),
      SerpListBlock block => ListBlockWidget(
          block: block,
          response: response,
          appTheme: appTheme,
          indentLevel: indentLevel,
        ),
      SerpCodeBlock block => CodeBlockWidget(
          block: block,
          appTheme: appTheme,
        ),
      SerpTableBlock block => TableBlockWidget(
          block: block,
          appTheme: appTheme,
        ),
      SerpExpandableBlock block => ExpandableBlockWidget(
          block: block,
          response: response,
          appTheme: appTheme,
        ),
      SerpComparisonBlock block => ComparisonBlockWidget(
          block: block,
          response: response,
          appTheme: appTheme,
        ),
    };
  }
}

/// Renders a heading block.
class HeadingBlockWidget extends StatelessWidget {
  const HeadingBlockWidget({
    super.key,
    required this.block,
    required this.appTheme,
  });

  final SerpHeadingBlock block;
  final AppTheme appTheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Text(
        block.snippet,
        style: AppFont.primaryTextStyle(
          context,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: appTheme.text,
        ),
      ),
    );
  }
}

/// Renders a paragraph block with optional highlighted words and LaTeX.
class ParagraphBlockWidget extends StatelessWidget {
  const ParagraphBlockWidget({
    super.key,
    required this.block,
    required this.response,
    required this.appTheme,
  });

  final SerpParagraphBlock block;
  final SerpAiResponse response;
  final AppTheme appTheme;

  @override
  Widget build(BuildContext context) {
    final text = block.snippet;
    final highlightedWords = block.highlightedWords;
    final latexExpressions = block.snippetLatex;

    // If has LaTeX, use LatexTextRenderer
    if (latexExpressions.isNotEmpty || text.contains(r'$')) {
      return LatexTextRenderer(
        text: text,
        latexExpressions: latexExpressions,
        textColor: appTheme.text,
      );
    }

    // If no highlighted words, return plain text
    if (highlightedWords.isEmpty) {
      return _buildPlainText(context, text);
    }

    // Build rich text with highlights
    return _buildHighlightedText(context, text, highlightedWords);
  }

  Widget _buildPlainText(BuildContext context, String text) {
    return Text(
      text,
      style: AppFont.primaryTextStyle(
        context,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: appTheme.text,
        height: 1.5,
      ),
    );
  }

  Widget _buildHighlightedText(
    BuildContext context,
    String text,
    List<String> highlightedWords,
  ) {
    final spans = <TextSpan>[];
    var remainingText = text;

    // Build spans by finding highlighted words
    for (final word in highlightedWords) {
      final index = remainingText.indexOf(word);
      if (index >= 0) {
        // Add text before the highlighted word
        if (index > 0) {
          spans.add(TextSpan(
            text: remainingText.substring(0, index),
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: appTheme.text,
              height: 1.5,
            ),
          ));
        }
        // Add highlighted word
        spans.add(TextSpan(
          text: word,
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: appTheme.text,
            height: 1.5,
          ),
        ));
        remainingText = remainingText.substring(index + word.length);
      }
    }

    // Add remaining text
    if (remainingText.isNotEmpty) {
      spans.add(TextSpan(
        text: remainingText,
        style: AppFont.primaryTextStyle(
          context,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: appTheme.text,
          height: 1.5,
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

/// Renders a list block with bullet points.
class ListBlockWidget extends StatelessWidget {
  const ListBlockWidget({
    super.key,
    required this.block,
    required this.response,
    required this.appTheme,
    this.indentLevel = 0,
  });

  final SerpListBlock block;
  final SerpAiResponse response;
  final AppTheme appTheme;
  final int indentLevel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: block.items.map((item) {
        return ListItemWidget(
          item: item,
          response: response,
          appTheme: appTheme,
          indentLevel: indentLevel,
        );
      }).toList(),
    );
  }
}

/// Renders a single list item.
class ListItemWidget extends StatelessWidget {
  const ListItemWidget({
    super.key,
    required this.item,
    required this.response,
    required this.appTheme,
    this.indentLevel = 0,
  });

  final SerpListItem item;
  final SerpAiResponse response;
  final AppTheme appTheme;
  final int indentLevel;

  @override
  Widget build(BuildContext context) {
    final bulletChars = ['•', '◦', '▪', '▫'];
    final bulletChar = bulletChars[indentLevel % bulletChars.length];
    final leftPadding = indentLevel * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPadding, bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main snippet with bullet
          if (item.snippet != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                  child: Text(
                    bulletChar,
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: appTheme.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildSnippetContent(context, item.snippet!),
                ),
              ],
            ),

          // Nested text blocks
          if (item.textBlocks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: item.textBlocks.map((block) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextBlockRenderer(
                      block: block,
                      response: response,
                      appTheme: appTheme,
                      indentLevel: indentLevel + 1,
                    ),
                  );
                }).toList(),
              ),
            ),

          // Nested list
          if (item.nestedList.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: item.nestedList.map((nestedItem) {
                  return ListItemWidget(
                    item: nestedItem,
                    response: response,
                    appTheme: appTheme,
                    indentLevel: indentLevel + 1,
                  );
                }).toList(),
              ),
            ),

          // Code block within list item
          if (item.codeBlock != null)
            Padding(
              padding: const EdgeInsets.only(left: 20.0, top: 4.0),
              child: CodeBlockWidget(
                block: item.codeBlock!,
                appTheme: appTheme,
              ),
            ),
        ],
      ),
    );
  }

  /// Build snippet content, handling LaTeX if present.
  Widget _buildSnippetContent(BuildContext context, String text) {
    // Check if this item has LaTeX expressions
    if (item.snippetLatex.isNotEmpty || text.contains(r'$')) {
      return LatexTextRenderer(
        text: text,
        latexExpressions: item.snippetLatex,
        textColor: appTheme.text,
      );
    }

    // Check for "Label: content" pattern for bold labels
    final colonIndex = text.indexOf(':');
    if (colonIndex > 0 && colonIndex < 30) {
      final label = text.substring(0, colonIndex + 1);
      final content = text.substring(colonIndex + 1);

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: label,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: appTheme.text,
                height: 1.5,
              ),
            ),
            TextSpan(
              text: content,
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: appTheme.text,
                height: 1.5,
              ),
            ),
          ],
        ),
      );
    }

    // Plain text
    return Text(
      text,
      style: AppFont.primaryTextStyle(
        context,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: appTheme.text,
        height: 1.5,
      ),
    );
  }
}

/// Renders a code block.
class CodeBlockWidget extends StatelessWidget {
  const CodeBlockWidget({
    super.key,
    required this.block,
    required this.appTheme,
  });

  final SerpCodeBlock block;
  final AppTheme appTheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: appTheme.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: appTheme.borderMuted),
      ),
      child: SelectableText(
        block.code,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          height: 1.4,
        ),
      ),
    );
  }
}

/// Renders a table block.
class TableBlockWidget extends StatelessWidget {
  const TableBlockWidget({
    super.key,
    required this.block,
    required this.appTheme,
  });

  final SerpTableBlock block;
  final AppTheme appTheme;

  @override
  Widget build(BuildContext context) {
    if (block.headers.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(
          color: appTheme.borderMuted,
          width: 1,
        ),
        defaultColumnWidth: const IntrinsicColumnWidth(),
        children: [
          // Header row
          TableRow(
            decoration: BoxDecoration(color: appTheme.bg),
            children: block.headers
                .map((header) => _buildCell(context, header, isHeader: true))
                .toList(),
          ),
          // Data rows
          ...block.rows.map(
            (row) => TableRow(
              children: row.map((cell) => _buildCell(context, cell)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(BuildContext context, String text,
      {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: AppFont.primaryTextStyle(
          context,
          fontSize: 13,
          fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
          color: appTheme.text,
        ),
      ),
    );
  }
}

/// Renders an expandable block.
class ExpandableBlockWidget extends StatefulWidget {
  const ExpandableBlockWidget({
    super.key,
    required this.block,
    required this.response,
    required this.appTheme,
  });

  final SerpExpandableBlock block;
  final SerpAiResponse response;
  final AppTheme appTheme;

  @override
  State<ExpandableBlockWidget> createState() => _ExpandableBlockWidgetState();
}

class _ExpandableBlockWidgetState extends State<ExpandableBlockWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.block.title != null)
          GestureDetector(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Row(
              children: [
                Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 20,
                  color: widget.appTheme.textMuted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.block.title!,
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: widget.appTheme.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_isExpanded && widget.block.textBlocks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 24.0, top: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: widget.block.textBlocks.map((block) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: TextBlockRenderer(
                    block: block,
                    response: widget.response,
                    appTheme: widget.appTheme,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/// Renders a comparison block (as paragraph).
class ComparisonBlockWidget extends StatelessWidget {
  const ComparisonBlockWidget({
    super.key,
    required this.block,
    required this.response,
    required this.appTheme,
  });

  final SerpComparisonBlock block;
  final SerpAiResponse response;
  final AppTheme appTheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      block.snippet,
      style: AppFont.primaryTextStyle(
        context,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: appTheme.text,
        height: 1.5,
      ),
    );
  }
}
