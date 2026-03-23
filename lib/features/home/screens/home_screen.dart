import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/home_provider.dart';
import '../widgets/post_card.dart';
import '../widgets/category_filter_bar.dart';
import '../widgets/search_overlay.dart';
import '../widgets/notification_panel.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  bool _showFab      = false;
  int  _unreadCount  = 3; // mock 未读数，实际从 Supabase notifications 读取

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
    // 触底加载更多
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

  @override
  Widget build(BuildContext context) {
    final postsState = ref.watch(homePostsProvider);

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
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(context),
            _buildCategoryBar(),
            _buildWaterfallGrid(postsState),
            if (postsState.isLoadingMore)
              const SliverToBoxAdapter(child: _LoadingMoreIndicator()),
            // 底部安全区
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
            child: const Icon(Icons.keyboard_arrow_up_rounded,
                color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      expandedHeight: 110,
      collapsedHeight: 60,
      backgroundColor: AppTheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.of(context).padding.top + 12,
            20,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppTheme.primaryGradient.createShader(bounds),
                    child: const Text(
                      '搭哒',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      _IconBtn(
                        icon:  Icons.search_rounded,
                        onTap: () async {
                          final keyword = await SearchOverlay.show(context);
                          if (keyword != null &&
                              keyword.trim().isNotEmpty &&
                              context.mounted) {
                            context.push(
                              '/search',
                              extra: {'q': keyword.trim()},
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _IconBtn(
                        icon:        Icons.notifications_none_rounded,
                        onTap:       () async {
                          await NotificationPanel.show(context);
                          // 面板关闭后清除未读 badge
                          if (mounted) setState(() => _unreadCount = 0);
                        },
                        unreadCount: _unreadCount,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0),
        child: Container(
          height: 0.5,
          color: AppTheme.divider,
        ),
      ),
    );
  }

  Widget _buildCategoryBar() {
    return SliverToBoxAdapter(
      child: CategoryFilterBar(
        onCategoryChanged: (category) {
          ref.read(homePostsProvider.notifier).filterByCategory(category);
        },
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
      return const SliverFillRemaining(
        child: _EmptyView(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
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

// ─────────────────────────────────────────────
// 子组件
// ─────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.onTap,
    this.unreadCount = 0,
  });

  final IconData     icon;
  final VoidCallback onTap;
  final int          unreadCount;

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
            // 数字 badge（≤99 显示数字，>99 显示 99+）
            if (unreadCount > 0)
              Positioned(
                top:   -4,
                right: -4,
                child: AnimatedScale(
                  scale:    1.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 17, minHeight: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color:            AppTheme.error,
                      borderRadius:     BorderRadius.circular(9),
                      border:           Border.all(
                          color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color:      Colors.white,
                        fontSize:   9,
                        fontWeight: FontWeight.w800,
                        height:     1.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
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
        const Icon(Icons.wifi_off_rounded, size: 56, color: AppTheme.onSurfaceVariant),
        const SizedBox(height: 12),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: onRetry, child: const Text('重试')),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('🎭', style: TextStyle(fontSize: 64)),
        SizedBox(height: 12),
        Text('暂无内容', style: TextStyle(color: AppTheme.onSurfaceVariant)),
      ],
    );
  }
}
