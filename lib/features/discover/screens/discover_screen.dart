import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/provider_summary.dart';
import '../../provider/widgets/rating_bottom_sheet.dart';
import '../data/match_mock_data.dart';
import '../models/discover_filter_model.dart';
import '../models/match_profile.dart';
import '../providers/likes_provider.dart';
import '../utils/spring_curve.dart';
import '../widgets/discover_filter_sheet.dart';
import '../widgets/match_like_toast.dart';
import '../widgets/match_tab_header.dart';
import '../widgets/tinder_swipe_stack.dart';

/// 匹配页：类 Tinder 全屏滑动（沉浸式，无底部操作钮）
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with
        TickerProviderStateMixin,
        AutomaticKeepAliveClientMixin {
  MatchMainTab _matchMainTab = MatchMainTab.recommend;
  static const _matchNearbyCity = '上海';

  late AnimationController _bgCtrl;
  late Animation<Color?> _bgTopAnim;
  late Animation<Color?> _bgBottomAnim;
  Color _bgTopCurrent = const Color(0xFF2A1A3E);
  Color _bgBottomCurrent = const Color(0xFF1A0A2E);
  Color _bgTopTarget = const Color(0xFF2A1A3E);
  Color _bgBottomTarget = const Color(0xFF1A0A2E);

  int _currentIndex = 0;

  final Map<String, (Color, Color)> _paletteCache = {};

  final List<List<String>> _recentTagHistory = [];
  static const _diversityWindow = 5;
  static const _diversityThreshold = 0.8;
  bool _diversityInjected = false;

  late List<MatchProfile> _profiles;
  List<MatchProfile> _allProfiles = [];
  DiscoverFilterState _filterState = const DiscoverFilterState();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _allProfiles = buildMatchMockProfiles();
    _profiles = _composeVisibleProfiles();

    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _refreshBgAnimation();
    _preloadPalettes(0);
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    super.dispose();
  }

  Future<void> _preloadPalettes(int startIndex) async {
    for (int i = startIndex;
        i < math.min(startIndex + 3, _profiles.length);
        i++) {
      final profile = _profiles[i];
      if (_paletteCache.containsKey(profile.imageUrl)) continue;
      _extractPalette(profile);
    }
  }

  Future<void> _extractPalette(MatchProfile profile) async {
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(profile.imageUrl),
        size: const Size(80, 120),
        maximumColorCount: 8,
      );

      final dominant = generator.dominantColor?.color ??
          generator.vibrantColor?.color ??
          AppTheme.primary;

      final topColor = HSLColor.fromColor(dominant)
          .withLightness(0.22)
          .withSaturation(0.45)
          .toColor();
      final bottomColor = HSLColor.fromColor(dominant)
          .withLightness(0.10)
          .withSaturation(0.50)
          .toColor();

      if (mounted) {
        setState(() => _paletteCache[profile.imageUrl] = (topColor, bottomColor));
      }
    } catch (_) {
      _paletteCache[profile.imageUrl] = (
        const Color(0xFF2A1A3E),
        const Color(0xFF1A0A2E),
      );
    }
  }

  void _refreshBgAnimation() {
    _bgTopAnim = ColorTween(begin: _bgTopCurrent, end: _bgTopTarget).animate(
      CurvedAnimation(
        parent: _bgCtrl,
        curve: const SpringCurve(stiffness: 280, damping: 22),
      ),
    );

    _bgBottomAnim =
        ColorTween(begin: _bgBottomCurrent, end: _bgBottomTarget).animate(
      CurvedAnimation(
        parent: _bgCtrl,
        curve: const SpringCurve(stiffness: 280, damping: 22),
      ),
    );
  }

  void _transitionBackground(int profileIndex) {
    if (profileIndex >= _profiles.length) return;

    final profile = _profiles[profileIndex];
    final palette = _paletteCache[profile.imageUrl];

    final newTop = palette?.$1 ?? const Color(0xFF2A1A3E);
    final newBottom = palette?.$2 ?? const Color(0xFF1A0A2E);

    if (newTop == _bgTopTarget && newBottom == _bgBottomTarget) return;

    _bgTopCurrent = _bgTopAnim.value ?? _bgTopCurrent;
    _bgBottomCurrent = _bgBottomAnim.value ?? _bgBottomCurrent;
    _bgTopTarget = newTop;
    _bgBottomTarget = newBottom;

    _refreshBgAnimation();
    _bgCtrl
      ..reset()
      ..forward();

    _preloadPalettes(profileIndex + 1);
  }

  void _updateDiversityHistory(List<String> tags) {
    _recentTagHistory.add(tags);
    if (_recentTagHistory.length > _diversityWindow) {
      _recentTagHistory.removeAt(0);
    }

    if (_recentTagHistory.length == _diversityWindow && !_diversityInjected) {
      final score = _calcDiversityScore(_recentTagHistory);
      if (score < (1 - _diversityThreshold)) {
        _injectDiversityCard();
      }
    }
    _diversityInjected = false;
  }

  double _calcDiversityScore(List<List<String>> history) {
    final allFlat = history.expand((t) => t).toList();
    final unique = allFlat.toSet().length;
    return unique / allFlat.length.toDouble();
  }

  void _injectDiversityCard() {
    final recentTags = _recentTagHistory.expand((t) => t).toSet();
    final diversePick = pickDiverseProfile(recentTags);

    final insertAt = math.min(_currentIndex + 2, _profiles.length);
    setState(() {
      _profiles.insert(insertAt, diversePick);
      _diversityInjected = true;
    });
  }

  void _onCardSwiped(MatchProfile profile, MatchSwipeDirection direction) {
    setState(() {
      _currentIndex++;
    });

    if (direction == MatchSwipeDirection.like) {
      _handleLike(profile);
    }

    _updateDiversityHistory(profile.tags);

    if (_currentIndex < _profiles.length) {
      _transitionBackground(_currentIndex);
    }
  }

  List<MatchProfile> _applyFilter(
    List<MatchProfile> list,
    DiscoverFilterState filter,
  ) {
    if (!filter.hasAnyFilter) return List.from(list);

    return list.where((p) {
      if (filter.serviceTypes.isNotEmpty) {
        if (!filter.serviceTypes.contains(p.tag)) return false;
      }
      if (filter.gender != null && p.gender != filter.gender) return false;
      if (filter.heightRange != null && p.heightCm != null) {
        if (!_heightInRange(p.heightCm!, filter.heightRange!)) return false;
      }
      if (filter.styles.isNotEmpty) {
        final match = p.tags.any((t) => filter.styles.contains(t));
        if (!match) return false;
      }
      if (filter.zodiac != null && p.zodiac != filter.zodiac) return false;
      if (filter.mbti != null && p.mbti != filter.mbti) return false;
      return true;
    }).toList();
  }

  bool _heightInRange(int heightCm, String range) {
    return switch (range) {
      '150-160' => heightCm >= 150 && heightCm < 160,
      '160-170' => heightCm >= 160 && heightCm < 170,
      '170-180' => heightCm >= 170 && heightCm < 180,
      '180+' => heightCm >= 180,
      _ => true,
    };
  }

  List<MatchProfile> _composeVisibleProfiles() {
    var list = _applyFilter(_allProfiles, _filterState);
    if (_matchMainTab == MatchMainTab.nearby) {
      list = list.where((p) => p.location == _matchNearbyCity).toList();
    }
    return list;
  }

  void _onFilterApply(DiscoverFilterState state) {
    setState(() {
      _filterState = state;
      _profiles = _composeVisibleProfiles();
      _currentIndex = 0;
      _recentTagHistory.clear();
      _paletteCache.clear();
    });
    _preloadPalettes(0);
    if (_profiles.isNotEmpty) {
      _transitionBackground(0);
    }
  }

  void _onMatchMainTab(MatchMainTab tab) {
    if (_matchMainTab == tab) return;
    setState(() {
      _matchMainTab = tab;
      _profiles = _composeVisibleProfiles();
      _currentIndex = 0;
      _recentTagHistory.clear();
      _paletteCache.clear();
    });
    _preloadPalettes(0);
    if (_profiles.isNotEmpty) {
      _transitionBackground(0);
    }
  }

  void _handleLike(MatchProfile profile) {
    final summary = _toSummary(profile);
    ref.read(likesProvider.notifier).like(summary);
    HapticFeedback.mediumImpact();
    MatchSuccessOverlay.show(context, name: profile.name);
    showMatchLikeToast(context);
  }

  ProviderSummary _toSummary(MatchProfile p) => ProviderSummary(
        id: p.id,
        name: p.name,
        tag: p.tag,
        typeEmoji: p.typeEmoji,
        imageUrl: p.imageUrl,
        rating: p.rating,
        reviews: p.reviews,
        location: p.location,
        price: p.price,
        tags: p.tags,
        isDiversityPick: p.isDiversityPick,
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final bottomPad = MediaQuery.paddingOf(context).bottom + 72;

    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, _) {
        final topColor = _bgTopAnim.value ?? _bgTopCurrent;
        final bottomColor = _bgBottomAnim.value ?? _bgBottomCurrent;

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [topColor, bottomColor],
                  ),
                ),
                child: const SizedBox.expand(),
              ),
              if (_profiles.isNotEmpty && _currentIndex < _profiles.length)
                TinderSwipeStack(
                  profiles: _profiles,
                  currentIndex: _currentIndex,
                  bottomContentInset: bottomPad,
                  onSwiped: _onCardSwiped,
                  onProfileTap: (p) => context.push(
                    '/provider/${p.id}',
                    extra: _toSummary(p).toExtra(),
                  ),
                )
              else
                _buildEmptyOrDone(context),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: MatchTabHeader(
                    selectedTab: _matchMainTab,
                    onTabChanged: _onMatchMainTab,
                    filterState: _filterState,
                    onFilterApply: _onFilterApply,
                    recentTagHistoryLength: _recentTagHistory.length,
                    diversityScore: _recentTagHistory.length >= 3
                        ? _calcDiversityScore(_recentTagHistory)
                        : 1.0,
                    nearbyCityLabel: _matchNearbyCity,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyOrDone(BuildContext context) {
    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🔍', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text(
              '暂无符合筛选的达人',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '试试调整筛选条件',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                DiscoverFilterSheet.show(
                  context,
                  initialState: _filterState,
                  onApply: _onFilterApply,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('调整筛选'),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          const Text(
            '今日卡片已刷完',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '明天再来，或重新加载',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _currentIndex = 0;
                _allProfiles = buildMatchMockProfiles();
                _profiles = _composeVisibleProfiles();
                _recentTagHistory.clear();
              });
              _preloadPalettes(0);
              if (_profiles.isNotEmpty) {
                _transitionBackground(0);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('重新发现'),
          ),
        ],
      ),
    );
  }
}
