import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/post_model.dart';

// ─────────────────────────────────────────────
// State
// ─────────────────────────────────────────────
class HomePostsState {
  const HomePostsState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.selectedCategory = 'all',
    this.hasMore = true,
    this.page = 0,
  });

  final List<Post> posts;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String selectedCategory;
  final bool hasMore;
  final int page;

  HomePostsState copyWith({
    List<Post>? posts,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? selectedCategory,
    bool? hasMore,
    int? page,
  }) {
    return HomePostsState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
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

  static const _pageSize = 20;

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
    state = HomePostsState(selectedCategory: state.selectedCategory);
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
    state = HomePostsState(selectedCategory: category);
    _loadInitial();
  }

  // 模拟数据（接入 Supabase 后替换此方法）
  Future<List<Post>> _fetchMockPosts({required int page}) async {
    await Future.delayed(const Duration(milliseconds: 800));

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
      '🎭 洛天依Cos | 同城面基',
      '🌙 暗黑系Cos | 高定战甲',
      '📷 棚拍体验 | 日出金光',
      '🎯 LOL陪练 | 晋级保障',
      '💫 Cos委托 | 素材拍摄',
      '🎪 同人活动 | 漫展同行',
    ];

    return List.generate(10, (i) {
      final idx = (page * 10 + i) % 10;
      return Post(
        id: 'mock_${page}_$i',
        providerId: 'provider_$i',
        title: titles[idx],
        description: '专业团队，品质保证，欢迎咨询',
        category: categories[i % 4],
        images: [mockImages[idx]],
        coverImage: mockImages[idx],
        price: (50 + (i * 37 + page * 13) % 450).toDouble(),
        priceUnit: i % 3 == 0 ? '小时' : '次',
        tags: ['专业', '精品'],
        location: ['北京', '上海', '广州', '成都', '杭州'][i % 5],
        createdAt: DateTime.now().subtract(Duration(hours: i * 3)),
      );
    });
  }
}

// ─────────────────────────────────────────────
// Provider
// ─────────────────────────────────────────────
final homePostsProvider =
    StateNotifierProvider<HomePostsNotifier, HomePostsState>(
  (ref) => HomePostsNotifier(),
);
