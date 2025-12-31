import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fermi_frontend/models/serp_text_block.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// References section at the bottom of the walkthrough.
class ReferencesSection extends StatelessWidget {
  const ReferencesSection({
    super.key,
    required this.references,
    required this.appTheme,
  });

  final List<SerpReference> references;
  final AppTheme appTheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sources',
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: appTheme.textMuted,
          ),
        ),
        const SizedBox(height: 12),
        ...references.map((ref) => ReferenceItem(
              reference: ref,
              appTheme: appTheme,
            )),
      ],
    );
  }
}

/// A single reference item.
class ReferenceItem extends StatelessWidget {
  const ReferenceItem({
    super.key,
    required this.reference,
    required this.appTheme,
  });

  final SerpReference reference;
  final AppTheme appTheme;

  void _copyLink(BuildContext context) {
    Clipboard.setData(ClipboardData(text: reference.link));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Link copied: ${reference.source ?? reference.title}'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: GestureDetector(
        onTap: () => _copyLink(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: appTheme.bg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Index badge
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: appTheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${reference.index + 1}',
                    style: AppFont.primaryTextStyle(
                      context,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: appTheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reference.title,
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: appTheme.text,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (reference.source != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.link,
                            size: 12,
                            color: appTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            reference.source!,
                            style: AppFont.primaryTextStyle(
                              context,
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: appTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Copy icon
              Icon(
                Icons.content_copy,
                size: 16,
                color: appTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
