import 'package:flutter/material.dart';

import '../models/discover_filter_model.dart';
import 'discover_filter_sheet.dart';
import 'match_diversity_indicator.dart';

/// 匹配页顶层：推荐 / 附近
enum MatchMainTab { recommend, nearby }

class MatchTabHeader extends StatelessWidget {
  const MatchTabHeader({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.filterState,
    required this.onFilterApply,
    required this.recentTagHistoryLength,
    required this.diversityScore,
    required this.nearbyCityLabel,
  });

  final MatchMainTab selectedTab;
  final ValueChanged<MatchMainTab> onTabChanged;
  final DiscoverFilterState filterState;
  final ValueChanged<DiscoverFilterState> onFilterApply;
  final int recentTagHistoryLength;
  final double diversityScore;
  final String nearbyCityLabel;

  static const xhsRed = Color(0xFFFF2442);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.55),
            Colors.black.withValues(alpha: 0.12),
            Colors.transparent,
          ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _MatchTopTabItem(
                        label: '推荐',
                        selected: selectedTab == MatchMainTab.recommend,
                        underlineColor: xhsRed,
                        onTap: () => onTabChanged(MatchMainTab.recommend),
                      ),
                    ),
                    Expanded(
                      child: _MatchTopTabItem(
                        label: '附近',
                        selected: selectedTab == MatchMainTab.nearby,
                        underlineColor: xhsRed,
                        onTap: () => onTabChanged(MatchMainTab.nearby),
                      ),
                    ),
                  ],
                ),
              ),
              if (recentTagHistoryLength >= 3)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: MatchDiversityIndicator(score: diversityScore),
                ),
              GestureDetector(
                onTap: () {
                  DiscoverFilterSheet.show(
                    context,
                    initialState: filterState,
                    onApply: onFilterApply,
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: filterState.hasAnyFilter
                        ? const Color(0xFF9B59B6).withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: filterState.hasAnyFilter
                          ? const Color(0xFF9B59B6)
                          : Colors.white24,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tune_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        filterState.hasAnyFilter
                            ? '筛选 ${filterState.activeCount}'
                            : '筛选',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              selectedTab == MatchMainTab.nearby
                  ? '同城优先 · $nearbyCityLabel'
                  : '右滑喜欢 · 左滑无感',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.75),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchTopTabItem extends StatelessWidget {
  const _MatchTopTabItem({
    required this.label,
    required this.selected,
    required this.underlineColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color underlineColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                color: selected ? Colors.white : Colors.white70,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              height: 3,
              width: selected ? 22 : 0,
              decoration: BoxDecoration(
                color: underlineColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
