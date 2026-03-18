import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/post_model.dart';
import '../../../data/models/provider_summary.dart';

// ─────────────────────────────────────────────
// 搜索结果状态
// ─────────────────────────────────────────────
class SearchResultsState {
  const SearchResultsState({
    this.posts = const [],
    this.providers = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Post> posts;
  final List<ProviderSummary> providers;
  final bool isLoading;
  final String? error;

  SearchResultsState copyWith({
    List<Post>? posts,
    List<ProviderSummary>? providers,
    bool? isLoading,
    String? error,
  }) {
    return SearchResultsState(
      posts: posts ?? this.posts,
      providers: providers ?? this.providers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ─────────────────────────────────────────────
// 搜索 Provider（根据关键词过滤 Mock 数据）
// ─────────────────────────────────────────────
final searchResultsProvider =
    FutureProvider.family<SearchResultsState, String>((ref, keyword) async {
  if (keyword.trim().isEmpty) {
    return const SearchResultsState();
  }

  await Future.delayed(const Duration(milliseconds: 500));

  final k = keyword.trim().toLowerCase();
  final mockPosts = _mockPosts;
  final mockProviders = _mockProviders;

  final matchedPosts = mockPosts.where((p) {
    final title = (p.title).toLowerCase();
    final loc = (p.location ?? '').toLowerCase();
    final cat = p.categoryLabel.toLowerCase();
    final tags = (p.tags ?? []).join(' ').toLowerCase();
    return title.contains(k) ||
        loc.contains(k) ||
        cat.contains(k) ||
        tags.contains(k);
  }).toList();

  final matchedProviders = mockProviders.where((p) {
    final name = p.name.toLowerCase();
    final tag = p.tag.toLowerCase();
    final loc = p.location.toLowerCase();
    final tags = p.tags.join(' ').toLowerCase();
    return name.contains(k) ||
        tag.contains(k) ||
        loc.contains(k) ||
        tags.contains(k);
  }).toList();

  return SearchResultsState(
    posts: matchedPosts,
    providers: matchedProviders,
  );
});

// ── Mock 帖子池 ──
List<Post> get _mockPosts {
  const images = [
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
  const categories = ['cosplay', 'photo', 'game', 'other'];
  const titles = [
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
    '🌸 汉服摄影 上海 外滩',
    '✨ 原神Cos 北京 漫展',
    '📸 摄影陪拍 古风写真',
    '🎮 王者陪玩 代练上分',
  ];
  const locations = ['北京', '上海', '广州', '成都', '杭州'];

  return List.generate(20, (i) {
    final idx = i % titles.length;
    return Post(
      id: 'search_post_$i',
      providerId: 'provider_${i % 5}',
      title: titles[idx],
      description: '专业团队，品质保证',
      category: categories[i % 4],
      images: [images[idx % images.length]],
      coverImage: images[idx % images.length],
      price: (50 + (i * 37) % 450).toDouble(),
      priceUnit: i % 3 == 0 ? '小时' : '次',
      tags: ['专业', '精品', '同城'],
      location: locations[i % 5],
      createdAt: DateTime.now().subtract(Duration(hours: i * 2)),
    );
  });
}

// ── Mock 达人池 ──
List<ProviderSummary> get _mockProviders {
  return [
    const ProviderSummary(
      id: 'p1',
      name: '凉月',
      tag: 'Coser',
      typeEmoji: '🎭',
      imageUrl: 'https://picsum.photos/seed/p1/400/600',
      avatarUrl: 'https://picsum.photos/seed/p1/200/200',
      rating: 4.9,
      reviews: 128,
      location: '上海',
      price: 180,
      tags: ['二次元', '汉服', '古风'],
    ),
    const ProviderSummary(
      id: 'p2',
      name: '星辰',
      tag: '摄影师',
      typeEmoji: '📸',
      imageUrl: 'https://picsum.photos/seed/p2/400/600',
      avatarUrl: 'https://picsum.photos/seed/p2/200/200',
      rating: 4.8,
      reviews: 96,
      location: '北京',
      price: 220,
      tags: ['日系', '写真', '户外'],
    ),
    const ProviderSummary(
      id: 'p3',
      name: '小樱',
      tag: '陪玩',
      typeEmoji: '🎮',
      imageUrl: 'https://picsum.photos/seed/p3/400/600',
      avatarUrl: 'https://picsum.photos/seed/p3/200/200',
      rating: 4.7,
      reviews: 64,
      location: '广州',
      price: 80,
      tags: ['王者', '原神', '代练'],
    ),
    const ProviderSummary(
      id: 'p4',
      name: '流光',
      tag: 'Coser',
      typeEmoji: '🎭',
      imageUrl: 'https://picsum.photos/seed/p4/400/600',
      avatarUrl: 'https://picsum.photos/seed/p4/200/200',
      rating: 4.9,
      reviews: 52,
      location: '上海',
      price: 150,
      tags: ['原神', '古风', '漫展'],
    ),
    const ProviderSummary(
      id: 'p5',
      name: '晨光',
      tag: '摄影师',
      typeEmoji: '📸',
      imageUrl: 'https://picsum.photos/seed/p5/400/600',
      avatarUrl: 'https://picsum.photos/seed/p5/200/200',
      rating: 4.6,
      reviews: 38,
      location: '成都',
      price: 120,
      tags: ['汉服', '写真', '棚拍'],
    ),
  ];
}
