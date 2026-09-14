import 'package:flutter/material.dart';
import 'package:fermi_frontend/models/feature_announcement.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

Future<FeatureAnnouncementAction?> showWhatsNewBottomSheet({
  required BuildContext context,
  required List<FeatureAnnouncement> announcements,
}) {
  return showModalBottomSheet<FeatureAnnouncementAction>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    builder: (_) => WhatsNewBottomSheet(announcements: announcements),
  );
}

class WhatsNewBottomSheet extends StatelessWidget {
  const WhatsNewBottomSheet({
    super.key,
    required this.announcements,
  });

  final List<FeatureAnnouncement> announcements;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: BoxDecoration(
          color: appTheme.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: appTheme.shadowColor,
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: appTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      "What's new",
                      style: AppFont.primaryTextStyle(
                        context,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: appTheme.text,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: appTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < announcements.length; index++) ...[
                _AnnouncementCard(announcement: announcements[index]),
                if (index < announcements.length - 1)
                  const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Got it',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: appTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.announcement});

  final FeatureAnnouncement announcement;

  @override
  Widget build(BuildContext context) {
    final appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: appTheme.bgLight,
        borderRadius: BorderRadius.circular(appTheme.borderRadius),
        border: Border.all(color: appTheme.borderMuted),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: appTheme.secondaryMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.auto_awesome,
                  color: appTheme.secondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  announcement.title,
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: appTheme.text,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            announcement.description,
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: appTheme.textMuted,
              height: 1.4,
            ),
          ),
          if (announcement.action case final action?) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(action),
                style: ElevatedButton.styleFrom(
                  backgroundColor: appTheme.secondary,
                  foregroundColor: appTheme.bg,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  announcement.actionLabel ?? 'Learn more',
                  style: AppFont.primaryTextStyle(
                    context,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: appTheme.bg,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
