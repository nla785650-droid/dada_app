import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/likes_provider.dart';

// ══════════════════════════════════════════════════════════════
// MyLikesScreen：我的喜欢列表
//
// 布局：Geek Chic 风格两列网格 + 封面图
// 功能：
//   · 实时监听 likesProvider（无需下拉刷新）
//   · 点击卡片 → ProviderProfilePage (Hero 动画)
//   · 长按 / 点击删除按钮 → 取消喜欢（动画移除）
// ══════════════════════════════════════════════════════════════

class MyLikesScreen extends ConsumerStatefulWidget {
  const MyLikesScreen({super.key});

  @override
  ConsumerState<MyLikesScreen> createState() => _MyLikesScreenState();
}

class _MyLikesScreenState extends ConsumerState<MyLikesScreen> {
  final Set<String> _dismissing = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(likesProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: _buildAppBar(state.entries.length),
      body: state.isLoading
          ? _buildSkeleton()
          : state.entries.isEmpty
              ? _EmptyView()
              : _buildGrid(state.entries),
    );
  }

  AppBar _buildAppBar(int count) {
    return AppBar(
      title: Row(
        children: [
          const Text('我的喜欢'),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ],
        ],
      ),
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.onSurface,
      elevation: 0,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: AppTheme.divider),
      ),
      actions: [
        // Realtime 状态点
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _LiveDot(),
        ),
      ],
    );
  }

  Widget _buildGrid(List<LikedEntry> entries) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final entry = entries[i];
        if (_dismissing.contains(entry.provider.id)) {
          return const SizedBox.shrink();
        }
        return _LikedCard(
          key: ValueKey(entry.likeId),
          entry: entry,
          onUnlike: () => _onUnlike(entry),
          onTap: () => _goToProvider(entry),
        );
      },
    );
  }

  Future<void> _onUnlike(LikedEntry entry) async {
    HapticFeedback.mediumImpact();

    // 先标记为消失（UI 动画）
    setState(() => _dismissing.add(entry.provider.id));

    // 短暂等待后执行实际删除
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    ref.read(likesProvider.notifier).unlike(entry.provider.id);
    setState(() => _dismissing.remove(entry.provider.id));
  }

  void _goToProvider(LikedEntry entry) {
    context.push(
      '/provider/${entry.provider.id}',
      extra: entry.provider.toExtra(),
    );
  }

  Widget _buildSkeleton() {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.62,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(18),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 喜欢卡片
// ══════════════════════════════════════════════════════════════

class _LikedCard extends StatefulWidget {
  const _LikedCard({
    super.key,
    required this.entry,
    required this.onUnlike,
    required this.onTap,
  });

  final LikedEntry entry;
  final VoidCallback onUnlike;
  final VoidCallback onTap;

  @override
  State<_LikedCard> createState() => _LikedCardState();
}

class _LikedCardState extends State<_LikedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  bool _showDelete = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onLongPress() {
    HapticFeedback.selectionClick();
    setState(() => _showDelete = !_showDelete);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.entry.provider;

    return GestureDetector(
      onTap: () {
        if (_showDelete) {
          setState(() => _showDelete = false);
          return;
        }
        widget.onTap();
      },
      onLongPress: _onLongPress,
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse(),
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 封面图
                  Expanded(
                    flex: 7,
                    child: Hero(
                      tag: 'likes_${p.id}',
                      child: CachedNetworkImage(
                        imageUrl: p.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (_, __) => Container(
                          color: AppTheme.surfaceVariant,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.surfaceVariant,
                          child: const Icon(Icons.person_rounded,
                              size: 40, color: AppTheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  ),
                  // 信息区
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 名字
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // 类型标签
                          Row(
                            children: [
                              Text(p.typeEmoji,
                                  style: const TextStyle(fontSize: 11)),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  p.tag,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppTheme.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          // 价格
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '¥${p.price}起',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.accent,
                                ),
                              ),
                              // 评分
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded,
                                      size: 11, color: Color(0xFFFFC107)),
                                  Text(
                                    p.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // 已验证徽章
              Positioned(
                top: 8, left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.favorite_rounded,
                          color: Colors.pinkAccent, size: 9),
                      const SizedBox(width: 3),
                      Text(
                        _formatDate(widget.entry.likedAt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 取消喜欢按钮（长按显示）
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _showDelete
                    ? Positioned.fill(
                        key: const ValueKey('delete'),
                        child: GestureDetector(
                          onTap: widget.onUnlike,
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.55),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 52, height: 52,
                                  decoration: BoxDecoration(
                                    color: AppTheme.error,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.error
                                            .withValues(alpha: 0.4),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.heart_broken_rounded,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '取消喜欢',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('normal')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${d.month}/${d.day}';
  }
}

// ── 空状态 ──
class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 动画爱心
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 900),
            curve: Curves.elasticOut,
            builder: (_, v, __) => Transform.scale(
              scale: v,
              child: const Text('💔',
                  style: TextStyle(fontSize: 68)),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '还没有喜欢的达人',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '在"发现"页右滑或点击❤️\n将心仪的达人加入收藏吧',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: () => context.go('/discover'),
            icon: const Icon(Icons.explore_rounded, size: 18),
            label: const Text('去发现'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Realtime 状态指示灯 ──
class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: Color.lerp(
                AppTheme.accent,
                AppTheme.accent.withValues(alpha: 0.25),
                _ctrl.value,
              ),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '实时同步',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.accent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
