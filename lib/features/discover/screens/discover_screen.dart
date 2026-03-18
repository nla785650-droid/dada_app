import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:palette_generator/palette_generator.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/provider_summary.dart';
import '../../provider/widgets/rating_bottom_sheet.dart';
import '../models/discover_filter_model.dart';
import '../providers/likes_provider.dart';
import '../widgets/discover_filter_sheet.dart';

// ══════════════════════════════════════════════════════════════
// DiscoverScreen：探探式滑卡发现页
//
// 增强特性：
//   1. 动态背景渐变 —— 根据当前卡片头像主色调平滑过渡
//      使用 palette_generator 提取图像主色，
//      SpringSimulation 驱动 Color 插值动画
//   2. 弹簧物理拖拽 —— 叠加 GestureDetector 追踪拖拽偏移，
//      卡片随手指旋转 + 缩放，松手后 SpringSimulation 回弹
//   3. Diversity Score —— 追踪最近 5 条的标签重复率，
//      若连续 >80% 重叠则强制注入不同标签的高质量卡片
// ══════════════════════════════════════════════════════════════

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen>
    with TickerProviderStateMixin {
  final _swiperController = CardSwiperController();

  // ── 背景颜色动画 ──
  late AnimationController _bgCtrl;
  late Animation<Color?> _bgTopAnim;
  late Animation<Color?> _bgBottomAnim;
  Color _bgTopCurrent = const Color(0xFF2A1A3E);
  Color _bgBottomCurrent = const Color(0xFF1A0A2E);
  Color _bgTopTarget = const Color(0xFF2A1A3E);
  Color _bgBottomTarget = const Color(0xFF1A0A2E);

  // ── 卡片拖拽物理 ──
  late AnimationController _dragCtrl;
  CardSwiperDirection? _dragDirection;

  // ── 统计 ──
  int _likeCount = 0;
  int _nopeCount = 0;
  int _currentIndex = 0;

  // ── 调色板缓存 ──
  final Map<String, (Color, Color)> _paletteCache = {};

  // ── Diversity Score ──
  final List<List<String>> _recentTagHistory = [];
  static const _diversityWindow = 5;
  static const _diversityThreshold = 0.8;
  bool _diversityInjected = false;

  // ── 数据 ──
  late List<_DiscoverProfile> _profiles;
  List<_DiscoverProfile> _allProfiles = [];
  DiscoverFilterState _filterState = const DiscoverFilterState();

  @override
  void initState() {
    super.initState();

    _allProfiles = _buildMockProfiles();
    _profiles = _applyFilter(_allProfiles, _filterState);

    // 背景弹簧动画控制器
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _refreshBgAnimation();

    // 拖拽弹簧动画控制器
    _dragCtrl = AnimationController.unbounded(vsync: this);

    // 预加载首张卡片调色板
    _preloadPalettes(0);
  }

  @override
  void dispose() {
    _swiperController.dispose();
    _bgCtrl.dispose();
    _dragCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────
  // 调色板提取
  // ────────────────────────────────────────

  Future<void> _preloadPalettes(int startIndex) async {
    for (int i = startIndex; i < math.min(startIndex + 3, _profiles.length); i++) {
      final profile = _profiles[i];
      if (_paletteCache.containsKey(profile.imageUrl)) continue;
      _extractPalette(profile);
    }
  }

  Future<void> _extractPalette(_DiscoverProfile profile) async {
    try {
      final generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(profile.imageUrl),
        size: const Size(80, 120), // 低分辨率采样，节省内存
        maximumColorCount: 8,
      );

      final dominant = generator.dominantColor?.color ??
          generator.vibrantColor?.color ??
          AppTheme.primary;

      // 由主色派生亮色（顶部）和暗色（底部）
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
      // 网络失败降级到品牌色
      _paletteCache[profile.imageUrl] = (
        const Color(0xFF2A1A3E),
        const Color(0xFF1A0A2E),
      );
    }
  }

  // ────────────────────────────────────────
  // 背景动画 —— 弹簧过渡
  // ────────────────────────────────────────

  void _refreshBgAnimation() {
    _bgTopAnim = ColorTween(
      begin: _bgTopCurrent,
      end: _bgTopTarget,
    ).animate(CurvedAnimation(
      parent: _bgCtrl,
      // 弹簧感：快速启动，末尾轻微超调
      curve: const _SpringCurve(stiffness: 280, damping: 22),
    ));

    _bgBottomAnim = ColorTween(
      begin: _bgBottomCurrent,
      end: _bgBottomTarget,
    ).animate(CurvedAnimation(
      parent: _bgCtrl,
      curve: const _SpringCurve(stiffness: 280, damping: 22),
    ));
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

    // 预加载后续3张
    _preloadPalettes(profileIndex + 1);
  }

  // ────────────────────────────────────────
  // Diversity Score 计算
  // ────────────────────────────────────────

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

  /// 多样性分数 = 不重复标签数 / 总标签槽位
  /// 分数越低 = 重复越高
  double _calcDiversityScore(List<List<String>> history) {
    final allFlat = history.expand((t) => t).toList();
    final unique = allFlat.toSet().length;
    return unique / allFlat.length.toDouble();
  }

  void _injectDiversityCard() {
    // 找一张与最近5张标签完全不同的卡片
    final recentTags = _recentTagHistory.expand((t) => t).toSet();
    final diversePick = _diversityPool.firstWhere(
      (p) => p.tags.every((t) => !recentTags.contains(t)),
      orElse: () => _diversityPool[math.Random().nextInt(_diversityPool.length)],
    );

    // 在当前位置后插入多样性卡片
    final insertAt = math.min(_currentIndex + 2, _profiles.length);
    setState(() {
      _profiles.insert(insertAt, diversePick);
      _diversityInjected = true;
    });
  }

  // ────────────────────────────────────────
  // 卡片滑动处理
  // ────────────────────────────────────────

  bool _onSwipe(int prev, int? current, CardSwiperDirection direction) {
    final profile = _profiles[prev];

    setState(() {
      if (direction == CardSwiperDirection.right) {
        _likeCount++;
      } else if (direction == CardSwiperDirection.left) {
        _nopeCount++;
      }
      _currentIndex = current ?? _profiles.length;
      _dragDirection = null;
    });

    // 右滑喜欢 → 持久化 + Toast
    if (direction == CardSwiperDirection.right) {
      _handleLike(profile);
    }

    // 更新多样性追踪
    _updateDiversityHistory(profile.tags);

    // 触发背景过渡
    if (current != null) {
      _transitionBackground(current);
    }

    return true;
  }

  // ── 筛选逻辑 ──
  List<_DiscoverProfile> _applyFilter(
    List<_DiscoverProfile> list,
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

  void _onFilterApply(DiscoverFilterState state) {
    setState(() {
      _filterState = state;
      _profiles = _applyFilter(_allProfiles, state);
      _currentIndex = 0;
      _recentTagHistory.clear();
      _paletteCache.clear();
    });
    _preloadPalettes(0);
    if (_profiles.isNotEmpty) {
      _transitionBackground(0);
    }
  }

  // ── 喜欢行为处理（持久化 + 反馈）──
  void _handleLike(_DiscoverProfile profile) {
    final summary = _toSummary(profile);

    // 写入 Supabase user_likes 表（乐观更新）
    ref.read(likesProvider.notifier).like(summary);

    // Haptic + 匹配 Toast
    HapticFeedback.mediumImpact();
    MatchSuccessOverlay.show(context, name: profile.name);

    // 微型 Toast："已加入我的喜欢"
    _showLikeToast();
  }

  void _showLikeToast() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _LikeToast(
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  // 将 _DiscoverProfile 转为 ProviderSummary 供路由传递
  ProviderSummary _toSummary(_DiscoverProfile p) => ProviderSummary(
        id:        p.id,
        name:      p.name,
        tag:       p.tag,
        typeEmoji: p.typeEmoji,
        imageUrl:  p.imageUrl,
        rating:    p.rating,
        reviews:   p.reviews,
        location:  p.location,
        price:     p.price,
        tags:      p.tags,
        isDiversityPick: p.isDiversityPick,
      );

  void _onDirectionChange(
    CardSwiperDirection horizontal,
    CardSwiperDirection vertical,
  ) {
    final dominant = horizontal != CardSwiperDirection.none
        ? horizontal
        : vertical != CardSwiperDirection.none
            ? vertical
            : null;
    setState(() => _dragDirection = dominant);
  }

  // ────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bgCtrl,
      builder: (context, _) {
        final topColor = _bgTopAnim.value ?? _bgTopCurrent;
        final bottomColor = _bgBottomAnim.value ?? _bgBottomCurrent;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [topColor, bottomColor],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  _buildStats(),
                  Expanded(child: _buildCardStack()),
                  _buildActionButtons(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
            child: const Text(
              '发现 · 匹配',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          // 多样性状态指示器
          if (_recentTagHistory.length >= 3)
            _DiversityIndicator(
              score: _calcDiversityScore(_recentTagHistory),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              DiscoverFilterSheet.show(
                context,
                initialState: _filterState,
                onApply: _onFilterApply,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _filterState.hasAnyFilter
                    ? AppTheme.primary.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _filterState.hasAnyFilter
                      ? AppTheme.primary
                      : Colors.white24,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune_rounded, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    _filterState.hasAnyFilter
                        ? '筛选 ${_filterState.activeCount}'
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
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Row(
        children: [
          _StatPill(
            icon: Icons.favorite_rounded,
            label: '喜欢 $_likeCount',
            color: AppTheme.accent,
          ),
          const SizedBox(width: 8),
          _StatPill(
            icon: Icons.close_rounded,
            label: '跳过 $_nopeCount',
            color: Colors.white60,
          ),
        ],
      ),
    );
  }

  Widget _buildCardStack() {
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
              '试试调整筛选条件或清除筛选',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
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

    if (_currentIndex >= _profiles.length) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            const Text(
              '今日匹配已看完！',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '明天再来发现更多精彩',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => setState(() {
                _currentIndex = 0;
                _allProfiles = _buildMockProfiles();
                _profiles = _applyFilter(_allProfiles, _filterState);
                _recentTagHistory.clear();
              }),
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

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CardSwiper(
            controller: _swiperController,
            cardsCount: _profiles.length,
            numberOfCardsDisplayed: math.min(3, _profiles.length - _currentIndex),
            backCardOffset: const Offset(0, 28),
            scale: 0.90,
            padding: const EdgeInsets.symmetric(vertical: 8),
            onSwipe: _onSwipe,
            onSwipeDirectionChange: _onDirectionChange,
            cardBuilder: (context, index, hOffset, vOffset) {
              final p = _profiles[index];
              return _SwipeCard(
                profile: p,
                dragDirection: index == _currentIndex ? _dragDirection : null,
                onTap: () => context.push(
                  '/provider/${p.id}',
                  extra: _toSummary(p).toExtra(),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final currentProfile = (_currentIndex < _profiles.length)
        ? _profiles[_currentIndex]
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // ❌ 左滑跳过
          _ActionButton(
            icon: Icons.close_rounded,
            color: Colors.white70,
            bgColor: Colors.white.withOpacity(0.15),
            size: 52,
            onTap: () => _swiperController.swipe(CardSwiperDirection.left),
          ),
          // ⭐ 打开评分浮层
          _ActionButton(
            icon: Icons.star_rounded,
            color: AppTheme.warning,
            bgColor: AppTheme.warning.withOpacity(0.15),
            size: 44,
            onTap: () {
              if (currentProfile == null) return;
              RatingBottomSheet.show(
                context,
                provider: _toSummary(currentProfile),
              );
            },
          ),
          // ❤️ 右滑喜欢 + 匹配 Toast + 持久化
          _ActionButton(
            icon: Icons.favorite_rounded,
            color: Colors.white,
            bgColor: AppTheme.accent,
            size: 60,
            onTap: () {
              // swipe() 会触发 _onSwipe → _handleLike，无需重复调用
              _swiperController.swipe(CardSwiperDirection.right);
            },
            isMain: true,
          ),
          // ⚡ 立即预约（跳转达人主页）
          _ActionButton(
            icon: Icons.bolt_rounded,
            color: AppTheme.primary,
            bgColor: AppTheme.primary.withOpacity(0.15),
            size: 44,
            onTap: () {
              if (currentProfile == null) return;
              context.push(
                '/provider/${currentProfile.id}',
                extra: _toSummary(currentProfile).toExtra(),
              );
            },
          ),
          // ↩️ 撤销
          _ActionButton(
            icon: Icons.undo_rounded,
            color: Colors.white70,
            bgColor: Colors.white.withOpacity(0.15),
            size: 44,
            onTap: () => _swiperController.undo(),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 弹簧曲线（模拟 spring physics 的 Curve 实现）
// 基于欠阻尼弹簧公式：x(t) = 1 - e^(-dt) * cos(wt)
// stiffness 控制弹性强度，damping 控制衰减速度
// ══════════════════════════════════════════════════════════════

class _SpringCurve extends Curve {
  const _SpringCurve({this.stiffness = 200, this.damping = 20});

  final double stiffness;
  final double damping;

  @override
  double transform(double t) {
    final w = math.sqrt(stiffness - damping * damping / 4);
    final result = 1 -
        math.exp(-damping * t / 2) *
            (math.cos(w * t) + (damping / (2 * w)) * math.sin(w * t));
    return result.clamp(0.0, 1.0);
  }
}

// ══════════════════════════════════════════════════════════════
// 卡片组件（带方向指示动画）
// ══════════════════════════════════════════════════════════════

class _SwipeCard extends StatelessWidget {
  const _SwipeCard({
    required this.profile,
    this.dragDirection,
    this.onTap,
  });

  final _DiscoverProfile profile;
  final CardSwiperDirection? dragDirection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 只响应短促 tap，不干扰拖拽（GestureDetector 的 tap 需要手指抬起且位移小）
      onTap: onTap,
      child: Hero(
        tag: 'discover_${profile.id}',
        child: Material(
          color: Colors.transparent,
          child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 背景图
                CachedNetworkImage(
                  imageUrl: profile.imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: AppTheme.surfaceVariant,
                    child: const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  ),
                ),
                // 底部渐变
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppTheme.cardGradient),
                ),
                // 顶部半透明遮罩（毛玻璃效果）
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.35),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Like / Nope 方向指示
                if (dragDirection == CardSwiperDirection.right)
                  _DirectionIndicator(label: 'LIKE', color: AppTheme.success, alignment: Alignment.topLeft),
                if (dragDirection == CardSwiperDirection.left)
                  _DirectionIndicator(label: 'NOPE', color: AppTheme.error, alignment: Alignment.topRight),
                if (dragDirection == CardSwiperDirection.top)
                  _DirectionIndicator(label: 'SUPER', color: AppTheme.warning, alignment: Alignment.topCenter),
                // 信息层
                Positioned(
                  left: 20, right: 20, bottom: 28,
                  child: _CardInfo(profile: profile),
                ),
                // 达人类型标签（左上角）
                Positioned(
                  top: 16, left: 16,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        color: Colors.black.withOpacity(0.3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(profile.typeEmoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              profile.tag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),  // Hero
    );  // GestureDetector
  }
}

// ── 方向指示标签 ──
class _DirectionIndicator extends StatelessWidget {
  const _DirectionIndicator({
    required this.label,
    required this.color,
    required this.alignment,
  });

  final String label;
  final Color color;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Transform.rotate(
            angle: alignment == Alignment.topLeft ? -0.3 : 0.3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── 卡片信息区 ──
class _CardInfo extends StatelessWidget {
  const _CardInfo({required this.profile});
  final _DiscoverProfile profile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              profile.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFC107)),
                  const SizedBox(width: 2),
                  Text(
                    profile.rating.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.location_on_rounded, size: 13, color: Colors.white60),
            const SizedBox(width: 2),
            Text(profile.location, style: const TextStyle(color: Colors.white60, fontSize: 12)),
            const SizedBox(width: 12),
            const Icon(Icons.reviews_rounded, size: 13, color: Colors.white60),
            const SizedBox(width: 2),
            Text('${profile.reviews}条评价', style: const TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ...profile.tags.take(3).map(
              (t) => Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white30, width: 0.5),
                ),
                child: Text(
                  '# $t',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.accent]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: AppTheme.accent.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Text(
                '¥${profile.price}起',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Diversity 指示器（右上角状态胶囊）
// ══════════════════════════════════════════════════════════════

class _DiversityIndicator extends StatelessWidget {
  const _DiversityIndicator({required this.score});
  final double score;

  @override
  Widget build(BuildContext context) {
    final isLow = score < 0.3;
    final color = isLow ? AppTheme.warning : AppTheme.success;
    final label = isLow ? '注入新鲜感' : '内容多样';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLow ? Icons.shuffle_rounded : Icons.auto_awesome_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 模型
// ══════════════════════════════════════════════════════════════

class _DiscoverProfile {
  const _DiscoverProfile({
    required this.id,
    required this.name,
    required this.tag,
    required this.typeEmoji,
    required this.imageUrl,
    required this.rating,
    required this.reviews,
    required this.location,
    required this.price,
    required this.tags,
    this.isDiversityPick = false,
    this.gender,
    this.heightCm,
    this.zodiac,
    this.mbti,
  });

  final String id;
  final String name;
  final String tag;
  final String typeEmoji;
  final String imageUrl;
  final double rating;
  final int reviews;
  final String location;
  final int price;
  final List<String> tags;
  final bool isDiversityPick;
  final String? gender;   // 男/女
  final int? heightCm;
  final String? zodiac;
  final String? mbti;
}

List<_DiscoverProfile> _buildMockProfiles() {
  final names = ['小樱', '星野', '绫波', '凉宫', '柚子', '美月', '彩花', '晴香', '雪乃', '和泉'];
  final types = ['Coser', '摄影师', '陪玩', 'Coser', '摄影师'];
  final emojis = ['🎭', '📸', '🎮', '🎭', '📸'];
  final locs = ['北京', '上海', '广州', '成都', '杭州'];
  final allTags = [
    ['汉服', '古风', '唐装'],
    ['日系', '写真', '棚拍'],
    ['王者', '原神', '二次元'],
    ['洛丽塔', 'JK制服', '小清新'],
    ['户外', '城市', '胶片'],
  ];
  final genders = ['女', '女', '男', '女', '男', '女', '男', '女', '女', '男'];
  final heights = [158, 165, 178, 162, 175, 168, 182, 155, 170, 172];
  final zodiacs = ['白羊座', '金牛座', '双子座', '巨蟹座', '狮子座', '处女座', '天秤座', '天蝎座', '射手座', '摩羯座'];
  final mbtis = ['INFP', 'ENFP', 'ISTJ', 'INFJ', 'ENTP', 'ISFJ', 'ESTP', 'INTJ', 'ENFJ', 'ISTP'];

  return List.generate(15, (i) {
    return _DiscoverProfile(
      id: 'p_$i',
      name: names[i % 10],
      tag: types[i % 5],
      typeEmoji: emojis[i % 5],
      imageUrl: 'https://picsum.photos/seed/profile$i/400/600',
      rating: 4.5 + (i % 5) * 0.1,
      reviews: 20 + i * 7,
      location: locs[i % 5],
      price: 80 + i * 30,
      tags: allTags[i % 5],
      gender: genders[i % 10],
      heightCm: heights[i % 10],
      zodiac: zodiacs[i % 10],
      mbti: mbtis[i % 10],
    );
  });
}

// 多样性注入池（标签与主池完全不重叠的高质量卡片）
final _diversityPool = [
  const _DiscoverProfile(
    id: 'div_1', name: '雏菊', tag: '摄影师', typeEmoji: '📸',
    imageUrl: 'https://picsum.photos/seed/div1/400/600',
    rating: 4.9, reviews: 156, location: '深圳',
    price: 240, tags: ['建筑', '极简', '黑白'],
    isDiversityPick: true,
    gender: '女', heightCm: 166, zodiac: '水瓶座', mbti: 'INTJ',
  ),
  const _DiscoverProfile(
    id: 'div_2', name: '冬霞', tag: 'Coser', typeEmoji: '🎭',
    imageUrl: 'https://picsum.photos/seed/div2/400/600',
    rating: 4.8, reviews: 89, location: '武汉',
    price: 160, tags: ['机甲', '赛博朋克', '科幻'],
    isDiversityPick: true,
    gender: '女', heightCm: 168, zodiac: '天蝎座', mbti: 'ENTP',
  ),
  const _DiscoverProfile(
    id: 'div_3', name: '苍月', tag: '陪玩', typeEmoji: '🎮',
    imageUrl: 'https://picsum.photos/seed/div3/400/600',
    rating: 5.0, reviews: 210, location: '杭州',
    price: 90, tags: ['剧本杀', '桌游', '密室'],
    isDiversityPick: true,
    gender: '男', heightCm: 175, zodiac: '双子座', mbti: 'ENFP',
  ),
];

// ══════════════════════════════════════════════════════════════
// 通用小组件
// ══════════════════════════════════════════════════════════════

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.size,
    required this.onTap,
    this.isMain = false,
  });

  final IconData icon;
  final Color color;
  final Color bgColor;
  final double size;
  final VoidCallback onTap;
  final bool isMain;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: isMain ? Colors.transparent : Colors.white.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(isMain ? 0.4 : 0.2),
              blurRadius: isMain ? 16 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.44),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 喜欢 Toast（屏幕中央短暂出现）
// ══════════════════════════════════════════════════════════════

class _LikeToast extends StatefulWidget {
  const _LikeToast({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_LikeToast> createState() => _LikeToastState();
}

class _LikeToastState extends State<_LikeToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _scale = TweenSequence([
      TweenSequenceItem(
          tween: Tween(begin: 0.5, end: 1.15)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.15, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 20),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 0.8)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 20),
    ]).animate(_ctrl);

    _opacity = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 25),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).size.height * 0.25,
      left: 0, right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) => Opacity(
            opacity: _opacity.value,
            child: Transform.scale(
              scale: _scale.value,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: AppTheme.accent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accent.withValues(alpha: 0.3),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_rounded,
                        color: Colors.pinkAccent, size: 16),
                    SizedBox(width: 6),
                    Text(
                      '已加入我的喜欢',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
