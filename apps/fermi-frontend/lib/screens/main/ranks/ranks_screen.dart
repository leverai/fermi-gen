import 'package:fermi_frontend/models/player_stats.dart';
import 'package:fermi_frontend/models/rank_data.dart';
import 'package:fermi_frontend/screens/main/ranks/widgets/rank_scale_widget.dart';
import 'package:fermi_frontend/theme/app_font.dart';
import 'package:fermi_frontend/theme/app_theme.dart';
import 'package:fermi_frontend/widgets/leave_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class RanksScreen extends StatefulWidget {
  const RanksScreen({
    super.key,
    required this.playerStats,
  });

  final PlayerStats playerStats;

  @override
  State<RanksScreen> createState() => _RanksScreenState();
}

class _RanksScreenState extends State<RanksScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize page controller to the user's rank - 1 (since id 1 is index 0)
    final initialIndex = widget.playerStats.rank.id - 1;
    _currentIndex = initialIndex.clamp(0, allRanks.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();

    return Scaffold(
      backgroundColor: appTheme.bgDark,
      body: Stack(
        children: [
          // Main Content
          Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Use arrows
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: allRanks.length,
                  itemBuilder: (context, index) {
                    final rank = allRanks[index];
                    return _RankPage(
                        rank: rank, playerStats: widget.playerStats);
                  },
                ),
              ),
              RankScaleWidget(
                currentRank: allRanks[_currentIndex],
                playerPercentile: widget.playerStats.averagePercentile,
              ),
              // Bottom padding for scale
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),

          // Leave Button
          LeaveButtonOverlay(
            iconColor: appTheme.text,
            splashColor: appTheme.textMuted.withOpacity(0.2),
            onPressed: () => Navigator.of(context).pop(),
          ),

          // Navigation Arrows
          if (_currentIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: FloatingActionButton(
                  heroTag: 'left_arrow',
                  onPressed: () => _goToPage(_currentIndex - 1),
                  mini: true,
                  backgroundColor: appTheme.bgLight,
                  foregroundColor: appTheme.text,
                  elevation: 2,
                  child: const Icon(Icons.arrow_back),
                ),
              ),
            ),

          if (_currentIndex < allRanks.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: Center(
                child: FloatingActionButton(
                  heroTag: 'right_arrow',
                  onPressed: () => _goToPage(_currentIndex + 1),
                  mini: true,
                  backgroundColor: appTheme.bgLight,
                  foregroundColor: appTheme.text,
                  elevation: 2,
                  child: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RankPage extends StatelessWidget {
  const _RankPage({required this.rank, required this.playerStats});

  final RankDefinition rank;
  final PlayerStats playerStats;

  String _getRankImageUrl() {
    if (playerStats.rank.picture.isEmpty) return '';
    final parts = playerStats.rank.picture.split('/');
    if (parts.isEmpty) return '';
    parts.removeLast();
    return '${parts.join('/')}/${rank.id}.svg';
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme appTheme =
        Theme.of(context).extension<AppTheme>() ?? AppTheme.defaultTheme();
    final imageUrl = _getRankImageUrl();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (imageUrl.isNotEmpty)
          SizedBox(
            width: 140,
            height: 140,
            child: SvgPicture.network(
              imageUrl,
              placeholderBuilder: (context) => Icon(
                Icons.military_tech,
                size: 80,
                color: appTheme.textMuted,
              ),
            ),
          ),
        const SizedBox(height: 24),
        Text(
          rank.name,
          style: AppFont.primaryTextStyle(
            context,
            fontSize: 36, // Larger for emphasis
            fontWeight: FontWeight.bold,
            color: appTheme.text,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: appTheme.bgLight,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: appTheme.shadowColor,
                offset: appTheme.shadowOffset,
                blurRadius: 0,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Text(
            'Top ${100 - rank.minPercentile}%',
            style: AppFont.primaryTextStyle(
              context,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: appTheme.textMuted,
            ),
          ),
        ),
        if (playerStats.rank.id == rank.id) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Your Current Rank ✓',
              style: AppFont.primaryTextStyle(
                context,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: appTheme.secondary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
