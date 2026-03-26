import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/profile_model.dart';

/// 首页顶层：关注 / 推荐 / 同城
enum HomeFeedTab { following, recommend, nearby }

// ─────────────────────────────────────────────
// State
// ─────────────────────────────────────────────
class HomePostsState {
  const HomePostsState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.feedTab = HomeFeedTab.recommend,
    this.selectedCategory = 'all',
    this.hasMore = true,
    this.page = 0,
  });

  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final HomeFeedTab feedTab;
  final String selectedCategory;
  final bool hasMore;
  final int page;

  HomePostsState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    HomeFeedTab? feedTab,
    String? selectedCategory,
    bool? hasMore,
    int? page,
  }) {
    return HomePostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
      feedTab: feedTab ?? this.feedTab,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
    );
  }
}

// ─────────────────────────────────────────────
// Notifier
// ─────────────────────────────────────────────
class HomePostsNotifier extends StateNotifier<HomePostsState> {
  HomePostsNotifier() : super(const HomePostsState()) {
    _loadInitial();
  }

  static const _pageSize = 10;
  /// 同城 Tab 使用的模拟定位（接入 LBS 后替换）
  static const _mockUserCity = '上海';

  static const _nicknames = [
    '小樱', '星野', '绫波', '凉宫', '柚子', '美月', '旅拍摄影师', '阿凯', '眠眠', '小鱼',
  ];

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final posts = await _fetchMockPosts(page: 0);
      state = state.copyWith(
        posts: posts,
        isLoading: false,
        page: 1,
        hasMore: posts.length >= _pageSize,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '加载失败，请重试');
    }
  }

  Future<void> refresh() async {
    state = HomePostsState(
      feedTab: state.feedTab,
      selectedCategory: state.selectedCategory,
    );
    await _loadInitial();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final more = await _fetchMockPosts(page: state.page);
      state = state.copyWith(
        posts: [...state.posts, ...more],
        isLoadingMore: false,
        page: state.page + 1,
        hasMore: more.length >= _pageSize,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMore: false);
    }
  }

  void filterByCategory(String category) {
    state = HomePostsState(
      feedTab: state.feedTab,
      selectedCategory: category,
    );
    _loadInitial();
  }

  void setFeedTab(HomeFeedTab tab) {
    if (state.feedTab == tab) return;
    state = HomePostsState(
      feedTab: tab,
      selectedCategory:
          tab == HomeFeedTab.recommend ? state.selectedCategory : 'all',
    );
    _loadInitial();
  }

  /// 用户在本页发布的动态，插入瀑布流顶部（MVP 本地模拟）。
  void prependUserPost(Post post) {
    state = state.copyWith(
      posts: [post, ...state.posts],
      isLoading: false,
      error: null,
    );
  }

  Post _buildMockPost(int globalIndex, int page) {
    final mockImages = [
      'https://picsum.photos/seed/cos1/400/560',
      'https://picsum.photos/seed/cos2/400/480',
      'https://picsum.photos/seed/cos3/400/520',
      'https://picsum.photos/seed/cos4/400/440',
      'https://picsum.photos/seed/cos5/400/600',
      'https://picsum.photos/seed/cos6/400/500',
      'https://picsum.photos/seed/cos7/400/460',
      'https://picsum.photos/seed/cos8/400/540',
      'https://picsum.photos/seed/cos9/400/580',
      'https://picsum.photos/seed/cos10/400/420',
    ];

    final categories = ['cosplay', 'photo', 'game', 'other'];
    final titles = [
      '🌸 精品Coser | 汉服古风专属',
      '📸 摄影陪拍 | 日系小清新',
      '🎮 游戏陪玩 | 王者荣耀全排',
      '✨ 原神角色 | 派蒙超高还原',
      '🎭 洛丽塔Cos | 同城面基',
      '🌙 暗黑系Cos | 高定战甲',
      '📷 棚拍体验 | 日出金光',
      '🎯 LOL陪练 | 晋级保障',
      '💫 Cos委托 | 素材拍摄',
      '🎪 同人活动 | 漫展同行',
    ];

    final idx = globalIndex % 10;
    final category = categories[globalIndex % 4];
    final locs = ['北京', '上海', '广州', '成都', '杭州'];
    final location = locs[globalIndex % 5];
    final pid = globalIndex % 100;

    final profile = Profile(
      id: 'provider_$pid',
      username: 'user_$pid',
      displayName: _nicknames[pid % _nicknames.length],
      avatarUrl: 'https://picsum.photos/seed/av$pid/128/128',
      role: 'provider',
      location: location,
      createdAt: DateTime.now(),
      isVerified: pid % 3 == 0,
    );

    final sampleImages = idx % 4 == 0
        ? <String>[mockImages[idx], mockImages[(idx + 3) % 10]]
        : <String>[mockImages[idx]];

    return Post(
      id: 'mock_${page}_$globalIndex',
      providerId: profile.id,
      title: titles[idx],
      description: '专业团队，品质保证，欢迎咨询',
      category: category,
      images: sampleImages,
      coverImage: sampleImages.first,
      price: (50 + (globalIndex * 37 + page * 13) % 450).toDouble(),
      priceUnit: globalIndex % 3 == 0 ? '小时' : '次',
      tags: const ['专业', '精品'],
      location: location,
      createdAt: DateTime.now().subtract(Duration(hours: globalIndex % 48)),
      provider: profile,
    );
  }

  bool _postMatches(Post p) {
    switch (state.feedTab) {
      case HomeFeedTab.recommend:
        if (state.selectedCategory == 'all') return true;
        return p.category == state.selectedCategory;
      case HomeFeedTab.following:
        final n = int.tryParse(p.providerId.replaceFirst('provider_', '')) ?? 0;
        return n % 2 == 0;
      case HomeFeedTab.nearby:
        return p.location == _mockUserCity;
    }
  }

  // 模拟数据（接入 Supabase 后替换此方法）
  Future<List<Post>> _fetchMockPosts({required int page}) async {
    await Future.delayed(const Duration(milliseconds: 500));

    final out = <Post>[];
    final base = page * 40;
    var globalI = base;
    final guard = base + 400;

    while (out.length < _pageSize && globalI < guard) {
      final p = _buildMockPost(globalI, page);
      if (_postMatches(p)) out.add(p);
      globalI++;
    }

    return out;
  }
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────
final homePostsProvider =
    StateNotifierProvider<HomePostsNotifier, HomePostsState>(
  (ref) => HomePostsNotifier(),
);
