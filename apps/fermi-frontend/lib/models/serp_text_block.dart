import 'dart:convert';

/// Models and parser for SerpAPI Google AI Mode text_blocks responses.
///
/// This supports the following text_block types:
/// - paragraph: Regular text with optional highlighted words and reference_indexes
/// - heading: Section heading
/// - list: Bulleted list with nested items (can contain text_blocks or lists recursively)
/// - code_block: Fenced code block
/// - table: 2D array data (first row headers)
/// - expandable: Collapsible content (treated as section)
/// - comparison: Comparison content (treated as paragraph)

/// Base class for all text block types.
sealed class SerpTextBlock {
  const SerpTextBlock();

  factory SerpTextBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? 'paragraph';

    switch (type) {
      case 'heading':
        return SerpHeadingBlock.fromJson(json);
      case 'paragraph':
        return SerpParagraphBlock.fromJson(json);
      case 'list':
        return SerpListBlock.fromJson(json);
      case 'code_block':
        return SerpCodeBlock.fromJson(json);
      case 'table':
        return SerpTableBlock.fromJson(json);
      case 'expandable':
        return SerpExpandableBlock.fromJson(json);
      case 'comparison':
        return SerpComparisonBlock.fromJson(json);
      default:
        // Fallback: treat unknown types as paragraph
        return SerpParagraphBlock.fromJson(json);
    }
  }
}

/// A heading block (## Heading Text in markdown).
class SerpHeadingBlock extends SerpTextBlock {
  final String snippet;

  const SerpHeadingBlock({required this.snippet});

  factory SerpHeadingBlock.fromJson(Map<String, dynamic> json) {
    return SerpHeadingBlock(
      snippet: json['snippet'] as String? ?? '',
    );
  }
}

/// A paragraph block with optional highlighted words, LaTeX expressions, and reference indexes.
class SerpParagraphBlock extends SerpTextBlock {
  final String snippet;
  final List<String> highlightedWords;
  final List<String> snippetLatex;
  final List<int> referenceIndexes;

  const SerpParagraphBlock({
    required this.snippet,
    this.highlightedWords = const [],
    this.snippetLatex = const [],
    this.referenceIndexes = const [],
  });

  factory SerpParagraphBlock.fromJson(Map<String, dynamic> json) {
    return SerpParagraphBlock(
      snippet: json['snippet'] as String? ?? '',
      highlightedWords: (json['snippet_highlighted_words'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      snippetLatex: (json['snippet_latex'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      referenceIndexes: (json['reference_indexes'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}

/// An item within a list block.
class SerpListItem {
  final String? snippet;
  final List<String> snippetLatex;
  final List<SerpTextBlock> textBlocks;
  final List<SerpListItem> nestedList;
  final SerpCodeBlock? codeBlock;

  const SerpListItem({
    this.snippet,
    this.snippetLatex = const [],
    this.textBlocks = const [],
    this.nestedList = const [],
    this.codeBlock,
  });

  factory SerpListItem.fromJson(Map<String, dynamic> json) {
    // Parse nested text_blocks if present
    final textBlocksJson = json['text_blocks'] as List<dynamic>?;
    final parsedTextBlocks = textBlocksJson != null
        ? textBlocksJson
            .whereType<Map<String, dynamic>>()
            .map((e) => SerpTextBlock.fromJson(e))
            .toList()
        : <SerpTextBlock>[];

    // Parse nested list if present
    final nestedListJson = json['list'] as List<dynamic>?;
    final parsedNestedList = nestedListJson != null
        ? nestedListJson
            .whereType<Map<String, dynamic>>()
            .map((e) => SerpListItem.fromJson(e))
            .toList()
        : <SerpListItem>[];

    // Parse code_block if present
    final codeBlockJson = json['code_block'] as Map<String, dynamic>?;
    final parsedCodeBlock =
        codeBlockJson != null ? SerpCodeBlock.fromJson(codeBlockJson) : null;

    // Parse snippet_latex if present
    final snippetLatexList = (json['snippet_latex'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        <String>[];

    return SerpListItem(
      snippet: json['snippet'] as String?,
      snippetLatex: snippetLatexList,
      textBlocks: parsedTextBlocks,
      nestedList: parsedNestedList,
      codeBlock: parsedCodeBlock,
    );
  }
}

/// A list block containing bullet items.
class SerpListBlock extends SerpTextBlock {
  final List<SerpListItem> items;
  final List<int> referenceIndexes;

  const SerpListBlock({
    required this.items,
    this.referenceIndexes = const [],
  });

  factory SerpListBlock.fromJson(Map<String, dynamic> json) {
    final listJson = json['list'] as List<dynamic>? ?? [];
    final items = listJson
        .whereType<Map<String, dynamic>>()
        .map((e) => SerpListItem.fromJson(e))
        .toList();

    return SerpListBlock(
      items: items,
      referenceIndexes: (json['reference_indexes'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}

/// A code block with optional language specification.
class SerpCodeBlock extends SerpTextBlock {
  final String code;
  final String? language;

  const SerpCodeBlock({
    required this.code,
    this.language,
  });

  factory SerpCodeBlock.fromJson(Map<String, dynamic> json) {
    return SerpCodeBlock(
      code: json['snippet'] as String? ?? json['code'] as String? ?? '',
      language: json['language'] as String?,
    );
  }
}

/// A table block with headers and rows.
class SerpTableBlock extends SerpTextBlock {
  final List<String> headers;
  final List<List<String>> rows;

  const SerpTableBlock({
    required this.headers,
    required this.rows,
  });

  factory SerpTableBlock.fromJson(Map<String, dynamic> json) {
    final tableData = json['table'] as List<dynamic>? ?? [];

    if (tableData.isEmpty) {
      return const SerpTableBlock(headers: [], rows: []);
    }

    // First row is headers
    final headers = (tableData.first as List<dynamic>?)
            ?.map((e) => e?.toString() ?? '')
            .toList() ??
        [];

    // Rest are data rows
    final rows = tableData
        .skip(1)
        .map((row) =>
            (row as List<dynamic>?)?.map((e) => e?.toString() ?? '').toList() ??
            <String>[])
        .toList();

    return SerpTableBlock(headers: headers, rows: rows);
  }
}

/// An expandable/collapsible block (treated as a section with text_blocks).
class SerpExpandableBlock extends SerpTextBlock {
  final String? title;
  final List<SerpTextBlock> textBlocks;

  const SerpExpandableBlock({
    this.title,
    this.textBlocks = const [],
  });

  factory SerpExpandableBlock.fromJson(Map<String, dynamic> json) {
    final textBlocksJson = json['text_blocks'] as List<dynamic>?;
    final parsedTextBlocks = textBlocksJson != null
        ? textBlocksJson
            .whereType<Map<String, dynamic>>()
            .map((e) => SerpTextBlock.fromJson(e))
            .toList()
        : <SerpTextBlock>[];

    return SerpExpandableBlock(
      title: json['title'] as String? ?? json['snippet'] as String?,
      textBlocks: parsedTextBlocks,
    );
  }
}

/// A comparison block (treated as paragraph content).
class SerpComparisonBlock extends SerpTextBlock {
  final String snippet;
  final List<int> referenceIndexes;

  const SerpComparisonBlock({
    required this.snippet,
    this.referenceIndexes = const [],
  });

  factory SerpComparisonBlock.fromJson(Map<String, dynamic> json) {
    return SerpComparisonBlock(
      snippet: json['snippet'] as String? ?? '',
      referenceIndexes: (json['reference_indexes'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
    );
  }
}

/// A reference/source citation.
class SerpReference {
  final String title;
  final String link;
  final String? snippet;
  final String? source;
  final int index;

  const SerpReference({
    required this.title,
    required this.link,
    this.snippet,
    this.source,
    required this.index,
  });

  factory SerpReference.fromJson(Map<String, dynamic> json) {
    return SerpReference(
      title: json['title'] as String? ?? '',
      link: json['link'] as String? ?? '',
      snippet: json['snippet'] as String?,
      source: json['source'] as String?,
      index: json['index'] as int? ?? 0,
    );
  }
}

/// Top-level AI response containing text_blocks and references.
class SerpAiResponse {
  final List<SerpTextBlock> textBlocks;
  final List<SerpReference> references;

  const SerpAiResponse({
    required this.textBlocks,
    required this.references,
  });

  /// Parse from JSON string.
  /// Returns null if parsing fails.
  static SerpAiResponse? tryParse(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return SerpAiResponse.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  factory SerpAiResponse.fromJson(Map<String, dynamic> json) {
    final textBlocksJson = json['text_blocks'] as List<dynamic>? ?? [];
    final referencesJson = json['references'] as List<dynamic>? ?? [];

    return SerpAiResponse(
      textBlocks: textBlocksJson
          .whereType<Map<String, dynamic>>()
          .map((e) => SerpTextBlock.fromJson(e))
          .toList(),
      references: referencesJson
          .whereType<Map<String, dynamic>>()
          .map((e) => SerpReference.fromJson(e))
          .toList(),
    );
  }

  /// Check if this response has any content.
  bool get hasContent => textBlocks.isNotEmpty;

  /// Get a reference by index.
  SerpReference? getReference(int index) {
    return references.where((r) => r.index == index).firstOrNull;
  }
}
