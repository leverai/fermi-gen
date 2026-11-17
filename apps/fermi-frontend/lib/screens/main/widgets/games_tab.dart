import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GamesTabDailyAction {
  const GamesTabDailyAction({
    required this.shortLabel,
    required this.detail,
    required this.onTap,
  });

  final String shortLabel;
  final String detail;
  final VoidCallback? onTap;
}

class GamesTab extends StatelessWidget {
  const GamesTab({
    super.key,
    this.displayName,
    required this.partyMetadata,
    required this.survivalMetadata,
    required this.precisionRushMetadata,
    required this.dailyAction,
    required this.onPartyCardTapped,
    required this.onSurvivalCardTapped,
    required this.onPrecisionRushCardTapped,
    required this.onArchiveTapped,
  });

  final String? displayName;
  final String partyMetadata;
  final String survivalMetadata;
  final String precisionRushMetadata;
  final GamesTabDailyAction dailyAction;
  final VoidCallback onPartyCardTapped;
  final VoidCallback onSurvivalCardTapped;
  final VoidCallback onPrecisionRushCardTapped;
  final VoidCallback onArchiveTapped;

  @override
  Widget build(BuildContext context) {
    final theme = _themeOf(context);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ClubhouseHeader(displayName: displayName),
            const SizedBox(height: 18),
            _PartyHero(
              onTap: onPartyCardTapped,
              metadata: partyMetadata,
            ),
            const SizedBox(height: 14),
            _DailyQuestionCard(action: dailyAction),
            const SizedBox(height: 24),
            const _SectionHeading(
              title: 'Flying solo?',
              trailing: 'Chase a personal best',
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 176,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _SoloTile(
                      title: 'Survival',
                      subtitle: survivalMetadata,
                      icon: Icons.local_fire_department_rounded,
                      color: theme.survival,
                      onTap: onSurvivalCardTapped,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SoloTile(
                      title: 'Precision\nRush',
                      subtitle: precisionRushMetadata,
                      icon: Icons.bolt_rounded,
                      color: theme.precisionRush,
                      onTap: onPrecisionRushCardTapped,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: onArchiveTapped,
              icon: const Icon(Icons.history_rounded),
              label: const Text('Daily question archive'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubhouseHeader extends StatelessWidget {
  const _ClubhouseHeader({required this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final theme = _themeOf(context);
    final firstName = displayName?.trim().split(RegExp(r'\s+')).first;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: theme.bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: SvgPicture.asset('assets/icons/logo-fg.svg'),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'THE CLUBHOUSE',
                style: AppFont.primaryTextStyle(
                  context,
                  color: theme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Hey ${firstName?.isNotEmpty == true ? firstName : 'Guest'} 👋',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFont.primaryTextStyle(
                  context,
                  color: theme.text,
                  fontSize: 20,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        SvgPicture.asset('assets/icons/llc_logo.svg', height: 18),
      ],
    );
  }
}

class _PartyHero extends StatelessWidget {
  const _PartyHero({required this.onTap, required this.metadata});

  final VoidCallback onTap;
  final String metadata;

  @override
  Widget build(BuildContext context) {
    final theme = _themeOf(context);
    final isLight = Theme.of(context).brightness == Brightness.light;
    final headlineColor = isLight ? theme.bgLight : theme.text;
    final bodyColor =
        isLight ? theme.bgLight.withAlpha(220) : theme.text.withAlpha(190);
    final metadataColor =
        isLight ? theme.bgLight.withAlpha(230) : theme.textMuted;
    final pillForeground = isLight ? theme.bgLight : theme.secondary;
    final pillBackground =
        isLight ? theme.bgLight.withAlpha(32) : theme.bgDark.withAlpha(100);

    return Material(
      color: theme.secondaryMuted,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Pill(
                          icon: Icons.wifi_tethering_rounded,
                          label: 'HOST A ROOM',
                          foreground: pillForeground,
                          background: pillBackground,
                        ),
                        const SizedBox(height: 22),
                        Text(
                          'Bring the\nsmart friends.',
                          style: AppFont.primaryTextStyle(
                            context,
                            color: headlineColor,
                            fontSize: 34,
                            height: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Choose a topic, share the code, settle who has the best intuition.',
                          style: AppFont.secondaryTextStyle(
                            context,
                            color: bodyColor,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: theme.secondary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      color: theme.bgDark,
                      size: 40,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: FilledButton.icon(
                      onPressed: onTap,
                      style: FilledButton.styleFrom(
                        foregroundColor: theme.bgDark,
                        backgroundColor: theme.secondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 15,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text(
                        'Start a party',
                        maxLines: 1,
                        style: AppFont.primaryTextStyle(
                          context,
                          color: theme.bgDark,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 2,
                    child: Text(
                      metadata,
                      maxLines: 2,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: AppFont.secondaryTextStyle(
                        context,
                        color: metadataColor,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppFont.primaryTextStyle(
              context,
              color: foreground,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyQuestionCard extends StatelessWidget {
  const _DailyQuestionCard({required this.action});

  final GamesTabDailyAction action;

  @override
  Widget build(BuildContext context) {
    final theme = _themeOf(context);

    return Material(
      color: theme.bg,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: action.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.primaryMuted,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.calendar_today_rounded, color: theme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily question',
                      style: AppFont.primaryTextStyle(
                        context,
                        color: theme.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      action.detail,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppFont.secondaryTextStyle(
                        context,
                        color: theme.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: action.onTap,
                child: Text(action.shortLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final theme = _themeOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppFont.primaryTextStyle(
              context,
              color: theme.text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          trailing,
          style: AppFont.secondaryTextStyle(
            context,
            color: theme.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _SoloTile extends StatelessWidget {
  const _SoloTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = _themeOf(context);
    return Material(
      color: color.withAlpha(38),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 34),
              const SizedBox(height: 26),
              SizedBox(
                height: 36,
                child: Text(
                  title,
                  style: AppFont.primaryTextStyle(
                    context,
                    color: theme.text,
                    fontSize: 18,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppFont.secondaryTextStyle(
                  context,
                  color: theme.textMuted,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

AppTheme _themeOf(BuildContext context) =>
    Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
