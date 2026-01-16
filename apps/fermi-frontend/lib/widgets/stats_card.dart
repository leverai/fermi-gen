import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fermi_frontend/models/player_stats.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';

/// A Neubrutalism-styled stats card displaying player statistics.
class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.stats,
    this.onTap,
  });

  final PlayerStats stats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: appTheme.primaryMuted,
              offset: appTheme.shadowOffset,
              blurRadius: 0,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Material(
          color: appTheme.bg,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            // ignore: deprecated_member_use
            splashColor: appTheme.highlight.withOpacity(0.3),
            // ignore: deprecated_member_use
            // highlightColor: appTheme.bgLight.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatItem(
                    label: 'Parties',
                    value: stats.totalPartyGames.toString(),
                  ),
                  _StatItem(
                    label: 'Daily Guesses',
                    value: stats.totalDailyGuesses.toString(),
                  ),
                  _StatItem(
                    label: 'Survivals',
                    value: stats.totalSurvivalRuns.toString(),
                  ),
                  _RankItem(
                    label: 'Rank',
                    rank: stats.rank,
                  ),
                  _StatItem(
                    label: 'Level',
                    value: stats.level.toString(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single stat item with label and value.
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 28,
            fontWeight: FontWeight.w300,
            color: appTheme.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: appTheme.textMuted,
          ).copyWith(
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}

/// A rank item displaying the rank image.
class _RankItem extends StatelessWidget {
  const _RankItem({
    required this.label,
    required this.rank,
  });

  final String label;
  final RankInfo rank;

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(
          width: 40,
          height: 40,
          child: SvgPicture.network(
            rank.picture,
            placeholderBuilder: (context) => Icon(
              Icons.military_tech,
              size: 24,
              color: appTheme.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color: appTheme.textMuted,
          ).copyWith(
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
