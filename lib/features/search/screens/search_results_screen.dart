import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/provider_summary.dart';
import '../../home/widgets/post_card.dart';
import '../providers/search_provider.dart';

// ══════════════════════════════════════════════════════════════
// SearchResultsScreen — 搜索结果页（小红书/抖音风格）
//
// 结构：
//   · 顶部固定搜索栏：返回 + 输入框 + 清空
//   · Tab：综合 | 达人 | 内容
//   · 综合：达人横向滑动 + 内容瀑布流
//   · 达人：2 列网格
//   · 内容：2 列瀑布流
// ══════════════════════════════════════════════════════════════

class SearchResultsScreen extends ConsumerStatefulWidget {
  const SearchResultsScreen({
    super.key,
    required this.initialKeyword,
  });

  final String initialKeyword;

  @override
  ConsumerState<SearchResultsScreen> createState() =>
      _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _searchController;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController(text: widget.initialKeyword);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearch(String keyword) {
    if (keyword.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    ref.invalidate(searchResultsProvider(keyword));
  }

  Future<void> _onRefreshSearch(String keyword) async {
    await Future.delayed(const Duration(seconds: 1));
    ref.invalidate(searchResultsProvider(keyword));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('搜索结果已更新')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keyword = _searchController.text.trim().isEmpty
        ? widget.initialKeyword
        : _searchController.text.trim();
    final asyncState = ref.watch(searchResultsProvider(keyword));

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          _buildSliverAppBar(),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: AppTheme.primary,
                unselectedLabelColor: AppTheme.onSurfaceVariant,
                indicatorColor: AppTheme.primary,
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: '综合'),
                  Tab(text: '达人'),
                  Tab(text: '内容'),
                ],
              ),
            ),
          ),
        ],
        body: asyncState.when(
          data: (state) => TabBarView(
            controller: _tabController,
            children: [
              _MixedTab(
                posts: state.posts,
                providers: state.providers,
                keyword: keyword,
                onRefresh: () => _onRefreshSearch(keyword),
              ),
              _ProvidersTab(
                providers: state.providers,
                keyword: keyword,
                onRefresh: () => _onRefreshSearch(keyword),
              ),
              _PostsTab(
                posts: state.posts,
                keyword: keyword,
                onRefresh: () => _onRefreshSearch(keyword),
              ),
            ],
          ),
          loading: () => const _LoadingView(),
          error: (e, _) => _ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(searchResultsProvider(keyword)),
          ),
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final topPad = MediaQuery.of(context).padding.top;

    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: AppTheme.surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.pop(),
      ),
      titleSpacing: 0,
      title: _SearchBar(
        controller:  _searchController,
        focusNode:   _focusNode,
        hintText:    '搜索达人、服务、风格...',
        onSubmitted: _onSearch,
        onChanged:   (_) => setState(() {}),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(
          color: AppTheme.divider,
        ),
      ),
    );
  }
}

// ── 顶部搜索输入框 ──
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onSubmitted,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(19),
        ),
        child: Row(
          children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded,
                size: 18, color: AppTheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14, color: AppTheme.onSurface),
                decoration: InputDecoration(
                  hintText: hintText,
                  hintStyle: const TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: onSubmitted,
                onChanged: onChanged,
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged?.call('');
                },
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.cancel_rounded,
                      size: 16, color: AppTheme.onSurfaceVariant),
                ),
              )
            else
              const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

// ── TabBar 持久化 Header ──
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  _TabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => 48;

  @override
  double get maxExtent => 48;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppTheme.surface,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate other) => tabBar != other.tabBar;
}

// ── 综合 Tab：达人横向 + 内容瀑布流 ──
class _MixedTab extends StatelessWidget {
  const _MixedTab({
    required this.posts,
    required this.providers,
    required this.keyword,
    required this.onRefresh,
  });

  final List<Post> posts;
  final List<ProviderSummary> providers;
  final String keyword;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty && providers.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: _EmptyView(keyword: keyword),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
        onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
        if (providers.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Text(
                    '相关达人',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                ),
                SizedBox(
                  height: 118,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: providers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _ProviderChip(provider: providers[i]),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
        if (posts.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                '相关内容',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 80),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              itemBuilder: (context, index) =>
                  PostCard(post: posts[index], index: index),
              childCount: posts.length,
            ),
          ),
        ],
      ],
    ),
    );
  }
}

// ── 达人 Tab ──
class _ProvidersTab extends StatelessWidget {
  const _ProvidersTab({
    required this.providers,
    required this.keyword,
    required this.onRefresh,
  });

  final List<ProviderSummary> providers;
  final String keyword;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: _EmptyView(keyword: keyword),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: onRefresh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
        child: GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.72,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: providers.length,
          itemBuilder: (_, i) => _ProviderCard(provider: providers[i]),
        ),
      ),
    );
  }
}

// ── 内容 Tab ──
class _PostsTab extends StatelessWidget {
  const _PostsTab({
    required this.posts,
    required this.keyword,
    required this.onRefresh,
  });

  final List<Post> posts;
  final String keyword;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 200,
            child: _EmptyView(keyword: keyword),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            itemBuilder: (context, index) =>
                PostCard(post: posts[index], index: index),
            childCount: posts.length,
          ),
        ),
      ],
    ),
    );
  }
}

// ── 达人横向小卡片 ──
class _ProviderChip extends StatelessWidget {
  const _ProviderChip({required this.provider});

  final ProviderSummary provider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        '/provider/${provider.id}',
        extra: provider.toExtra(),
      ),
      child: Container(
        width: 88,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: provider.avatarUrl ?? provider.imageUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                placeholder: (_, __) => Shimmer.fromColors(
                  baseColor: AppTheme.surfaceVariant,
                  highlightColor: Colors.white,
                  child: Container(color: AppTheme.surfaceVariant),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              provider.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              textAlign: TextAlign.center,
            ),
            Text(
              '¥${provider.price}/次',
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 达人网格卡片 ──
class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.provider});

  final ProviderSummary provider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(
        '/provider/${provider.id}',
        extra: provider.toExtra(),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: provider.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Shimmer.fromColors(
                      baseColor: AppTheme.surfaceVariant,
                      highlightColor: Colors.white,
                      child: Container(color: AppTheme.surfaceVariant),
                    ),
                  ),
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 12, color: Colors.amber),
                          const SizedBox(width: 2),
                          Text(
                            '${provider.rating}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      provider.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${provider.typeEmoji} ${provider.tag} · ${provider.location}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '¥${provider.price}/次',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 空状态 ──
class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.keyword});

  final String keyword;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          Text(
            '暂无「$keyword」相关结果',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            '试试其他关键词，如：COS委托、摄影陪拍、汉服',
            style: TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── 加载中 ──
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 32,
        height: 32,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

// ── 错误状态 ──
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 56, color: AppTheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
