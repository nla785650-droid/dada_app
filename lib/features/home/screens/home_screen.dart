import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/home_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/search_overlay.dart';
import '../widgets/notification_panel.dart';

/// 小红书式 Tab 选中红线
const Color _xhsTabRed = Color(0xFFFF2442);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  final _scrollController = ScrollController();
  bool _showFab = false;
  int _unreadCount = 3;

  @override
  bool get wantKeepAlive => true;

  static const _mainTabs = ['关注', '推荐', '同城'];
  static const _recommendChips = [
    _ChipDef('all', '全部'),
    _ChipDef('cosplay', 'Cosplay'),
    _ChipDef('photo', '摄影陪拍'),
    _ChipDef('game', '社交陪玩'),
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final show = _scrollController.offset > 200;
    if (show != _showFab) {
      setState(() => _showFab = show);
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(homePostsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  int _mainTabIndex(HomeFeedTab t) {
    return switch (t) {
      HomeFeedTab.following => 0,
      HomeFeedTab.recommend => 1,
      HomeFeedTab.nearby => 2,
    };
  }

  HomeFeedTab _tabFromIndex(int i) {
    return switch (i) {
      0 => HomeFeedTab.following,
      1 => HomeFeedTab.recommend,
      2 => HomeFeedTab.nearby,
      _ => HomeFeedTab.recommend,
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final postsState = ref.watch(homePostsProvider);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          await ref.read(homePostsProvider.notifier).refresh();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已为你推荐最新内容')),
          );
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverToBoxAdapter(
              child: _HomeTopSection(
                topPadding: topPadding,
                mainSelectedIndex: _mainTabIndex(postsState.feedTab),
                onMainTab: (i) => ref
                    .read(homePostsProvider.notifier)
                    .setFeedTab(_tabFromIndex(i)),
                showRecommendChips:
                    postsState.feedTab == HomeFeedTab.recommend,
                recommendSelectedId: postsState.selectedCategory,
                onChip: (id) =>
                    ref.read(homePostsProvider.notifier).filterByCategory(id),
                unreadCount: _unreadCount,
                onSearch: () async {
                  final keyword = await SearchOverlay.show(context);
                  if (keyword != null &&
                      keyword.trim().isNotEmpty &&
                      context.mounted) {
                    context.push('/search', extra: {'q': keyword.trim()});
                  }
                },
                onNotification: () async {
                  await NotificationPanel.show(context);
                  if (mounted) setState(() => _unreadCount = 0);
                },
                mainTabs: _mainTabs,
                recommendChips: _recommendChips,
              ),
            ),
            _buildWaterfallGrid(postsState),
            if (postsState.isLoadingMore)
              const SliverToBoxAdapter(child: _LoadingMoreIndicator()),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 80,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        offset: _showFab ? Offset.zero : const Offset(0, 2),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _showFab ? 1 : 0,
          child: FloatingActionButton.small(
            onPressed: () => _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            ),
            backgroundColor: AppTheme.primary,
            child: const Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWaterfallGrid(HomePostsState postsState) {
    if (postsState.isLoading && postsState.posts.isEmpty) {
      return const _ShimmerGrid();
    }

    if (postsState.error != null && postsState.posts.isEmpty) {
      return SliverFillRemaining(
        child: _ErrorView(
          message: postsState.error!,
          onRetry: () => ref.read(homePostsProvider.notifier).refresh(),
        ),
      );
    }

    if (postsState.posts.isEmpty) {
      return SliverFillRemaining(
        child: _EmptyFeedHint(feedTab: postsState.feedTab),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        itemBuilder: (context, index) {
          final post = postsState.posts[index];
          return PostCard(post: post, index: index);
        },
        childCount: postsState.posts.length,
      ),
    );
  }
}

class _ChipDef {
  const _ChipDef(this.id, this.label);
  final String id;
  final String label;
}

class _HomeTopSection extends StatelessWidget {
  const _HomeTopSection({
    required this.topPadding,
    required this.mainSelectedIndex,
    required this.onMainTab,
    required this.showRecommendChips,
    required this.recommendSelectedId,
    required this.onChip,
    required this.unreadCount,
    required this.onSearch,
    required this.onNotification,
    required this.mainTabs,
    required this.recommendChips,
  });

  final double topPadding;
  final int mainSelectedIndex;
  final ValueChanged<int> onMainTab;
  final bool showRecommendChips;
  final String recommendSelectedId;
  final ValueChanged<String> onChip;
  final int unreadCount;
  final VoidCallback onSearch;
  final VoidCallback onNotification;
  final List<String> mainTabs;
  final List<_ChipDef> recommendChips;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, topPadding + 6, 12, 0),
            child: Row(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) =>
                      AppTheme.primaryGradient.createShader(bounds),
                  child: const Text(
                    '搭哒',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const Spacer(),
                _IconBtn(
                  icon: Icons.search_rounded,
                  onTap: onSearch,
                ),
                const SizedBox(width: 8),
                _IconBtn(
                  icon: Icons.notifications_none_rounded,
                  onTap: onNotification,
                  unreadCount: unreadCount,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _XhsMainTabRow(
            labels: mainTabs,
            selectedIndex: mainSelectedIndex,
            onSelect: onMainTab,
          ),
          if (showRecommendChips) ...[
            const SizedBox(height: 6),
            _RecommendChipRow(
              chips: recommendChips,
              selectedId: recommendSelectedId,
              onSelect: onChip,
            ),
          ],
          const SizedBox(height: 4),
          Divider(height: 1, color: AppTheme.divider.withValues(alpha: 0.85)),
        ],
      ),
    );
  }
}

class _XhsMainTabRow extends StatelessWidget {
  const _XhsMainTabRow({
    required this.labels,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: List.generate(labels.length, (i) {
          final selected = i == selectedIndex;
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(i),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w500,
                        color: selected
                            ? AppTheme.onSurface
                            : AppTheme.onSurfaceVariant,
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
                        color: _xhsTabRed,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _RecommendChipRow extends StatelessWidget {
  const _RecommendChipRow({
    required this.chips,
    required this.selectedId,
    required this.onSelect,
  });

  final List<_ChipDef> chips;
  final String selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = chips[i];
          final selected = selectedId == c.id;
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onSelect(c.id),
              borderRadius: BorderRadius.circular(18),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? _xhsTabRed.withValues(alpha: 0.12)
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: selected
                        ? _xhsTabRed.withValues(alpha: 0.35)
                        : Colors.transparent,
                  ),
                ),
                child: Text(
                  c.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? _xhsTabRed : AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyFeedHint extends StatelessWidget {
  const _EmptyFeedHint({required this.feedTab});

  final HomeFeedTab feedTab;

  @override
  Widget build(BuildContext context) {
    final (emoji, title, subtitle) = switch (feedTab) {
      HomeFeedTab.following => (
          '👀',
          '暂无关注动态',
          '去推荐页逛逛，发现感兴趣的达人吧',
        ),
      HomeFeedTab.recommend => (
          '🎭',
          '暂时没有内容',
          '下拉刷新试试',
        ),
      HomeFeedTab.nearby => (
          '📍',
          '同城暂无动态',
          '切换到推荐看看全国精选',
        ),
    };

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: 12),
        Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.unreadCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: AppTheme.onSurface),
            if (unreadCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 17,
                    minHeight: 17,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.error,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerGrid extends StatelessWidget {
  const _ShimmerGrid();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        itemBuilder: (_, index) => Shimmer.fromColors(
          baseColor: AppTheme.surfaceVariant,
          highlightColor: Colors.white,
          child: Container(
            height: index % 3 == 0 ? 260 : (index % 3 == 1 ? 200 : 230),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        childCount: 8,
      ),
    );
  }
}

class _LoadingMoreIndicator extends StatelessWidget {
  const _LoadingMoreIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.wifi_off_rounded,
          size: 56,
          color: AppTheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onRetry, child: const Text('重试')),
      ],
    );
  }
}
