import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../data/models/provider_summary.dart';

// ══════════════════════════════════════════════════════════════
// LikedProvider Model：喜欢列表条目
// ══════════════════════════════════════════════════════════════

class LikedEntry {
  const LikedEntry({
    required this.likeId,
    required this.provider,
    required this.likedAt,
  });

  final String likeId;
  final ProviderSummary provider;
  final DateTime likedAt;

  factory LikedEntry.fromJson(Map<String, dynamic> json) {
    final typeEmoji = _emojiForType(json['provider_type'] as String?);
    final tag = _labelForType(json['provider_type'] as String?);
    final config = json['provider_config'] as Map<String, dynamic>? ?? {};
    final tags = (config['tags'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList() ??
        const ['二次元', '专业'];

    return LikedEntry(
      likeId: json['like_id'] as String,
      likedAt: DateTime.parse(
          json['liked_at'] as String? ?? DateTime.now().toIso8601String()),
      provider: ProviderSummary(
        id:        json['target_user_id'] as String,
        name:      json['display_name'] as String? ?? '达人',
        tag:       tag,
        typeEmoji: typeEmoji,
        imageUrl:  json['avatar_url'] as String? ??
            'https://picsum.photos/seed/${json["target_user_id"]}/400/600',
        avatarUrl: json['avatar_url'] as String?,
        rating:    (config['rating'] as num?)?.toDouble() ?? 4.8,
        reviews:   (config['review_count'] as num?)?.toInt() ?? 0,
        location:  json['location'] as String? ?? '',
        price:     (json['base_price'] as num?)?.toInt() ?? 120,
        tags:      tags,
      ),
    );
  }

  static String _emojiForType(String? type) => switch (type) {
        'cos_commission' => '🎭',
        'photography'   => '📸',
        'companion'     => '🎮',
        _               => '✨',
      };

  static String _labelForType(String? type) => switch (type) {
        'cos_commission' => 'Cos委托',
        'photography'   => '摄影陪拍',
        'companion'     => '社交陪玩',
        _               => '达人服务',
      };

  // Mock 构造（Supabase 未连接时降级）
  factory LikedEntry.mock(String targetId, String name, String imageUrl) {
    return LikedEntry(
      likeId:   'like_$targetId',
      likedAt:  DateTime.now(),
      provider: ProviderSummary(
        id:        targetId,
        name:      name,
        tag:       'Cos委托',
        typeEmoji: '🎭',
        imageUrl:  imageUrl,
        rating:    4.9,
        reviews:   28,
        location:  '上海',
        price:     160,
        tags:      const ['二次元', '古风', '专业'],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// LikesState
// ══════════════════════════════════════════════════════════════

class LikesState {
  const LikesState({
    this.likedIds = const {},
    this.entries = const [],
    this.isLoading = false,
    this.pendingIds = const {},
  });

  /// 已喜欢的 targetUserId 集合（快速 O(1) 判断是否已喜欢）
  final Set<String> likedIds;

  /// 完整的喜欢列表（供 MyLikesScreen 展示）
  final List<LikedEntry> entries;

  final bool isLoading;

  /// 正在请求中的 id（乐观 UI 用，防重复点击）
  final Set<String> pendingIds;

  bool isLiked(String targetId) => likedIds.contains(targetId);

  LikesState copyWith({
    Set<String>? likedIds,
    List<LikedEntry>? entries,
    bool? isLoading,
    Set<String>? pendingIds,
  }) =>
      LikesState(
        likedIds:   likedIds   ?? this.likedIds,
        entries:    entries    ?? this.entries,
        isLoading:  isLoading  ?? this.isLoading,
        pendingIds: pendingIds ?? this.pendingIds,
      );
}

// ══════════════════════════════════════════════════════════════
// LikesNotifier
// ══════════════════════════════════════════════════════════════

class LikesNotifier extends StateNotifier<LikesState> {
  LikesNotifier() : super(const LikesState()) {
    _loadInitial();
  }

  static SupabaseClient get _db => Supabase.instance.client;
  String? get _userId => _db.auth.currentUser?.id;

  Future<void> _loadInitial() async {
    state = state.copyWith(isLoading: true);
    try {
      final userId = _userId;
      if (userId == null) {
        // 未登录：加载 mock 数据演示
        state = state.copyWith(
          entries: _mockEntries,
          likedIds: _mockEntries.map((e) => e.provider.id).toSet(),
          isLoading: false,
        );
        return;
      }

      final data = await _db
          .from('my_liked_providers')
          .select()
          .eq('user_id', userId)
          .order('liked_at', ascending: false);

      final entries = (data as List<dynamic>)
          .map((json) => LikedEntry.fromJson(json as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        entries: entries,
        likedIds: entries.map((e) => e.provider.id).toSet(),
        isLoading: false,
      );
    } catch (_) {
      // Supabase 未配置时降级 mock
      state = state.copyWith(
        entries: _mockEntries,
        likedIds: _mockEntries.map((e) => e.provider.id).toSet(),
        isLoading: false,
      );
    }
  }

  // ── 喜欢一个达人（右滑 / 点❤️）──
  Future<void> like(ProviderSummary provider) async {
    if (state.isLiked(provider.id)) return;
    if (state.pendingIds.contains(provider.id)) return;

    // 乐观更新：立即反映到 UI
    final newEntry = LikedEntry(
      likeId:   'optimistic_${provider.id}',
      likedAt:  DateTime.now(),
      provider: provider,
    );
    state = state.copyWith(
      likedIds:   {...state.likedIds, provider.id},
      entries:    [newEntry, ...state.entries],
      pendingIds: {...state.pendingIds, provider.id},
    );

    try {
      final userId = _userId;
      if (userId != null) {
        await _db.from('user_likes').upsert({
          'user_id':        userId,
          'target_user_id': provider.id,
        }, onConflict: 'user_id,target_user_id');
      }
      // 成功后移除 pending 状态，更新真实 likeId
      state = state.copyWith(
        pendingIds: state.pendingIds.difference({provider.id}),
      );
    } catch (_) {
      // 保留乐观更新的结果（离线模式可用）
      state = state.copyWith(
        pendingIds: state.pendingIds.difference({provider.id}),
      );
    }
  }

  // ── 取消喜欢 ──
  Future<void> unlike(String targetUserId) async {
    if (!state.isLiked(targetUserId)) return;
    if (state.pendingIds.contains(targetUserId)) return;

    // 乐观更新
    final newLikedIds = state.likedIds.difference({targetUserId});
    final newEntries = state.entries
        .where((e) => e.provider.id != targetUserId)
        .toList();
    state = state.copyWith(
      likedIds:   newLikedIds,
      entries:    newEntries,
      pendingIds: {...state.pendingIds, targetUserId},
    );

    try {
      final userId = _userId;
      if (userId != null) {
        await _db
            .from('user_likes')
            .delete()
            .eq('user_id', userId)
            .eq('target_user_id', targetUserId);
      }
    } catch (_) {
      // 网络失败：保留乐观删除（防止回滚引发 UX 困惑）
    } finally {
      state = state.copyWith(
        pendingIds: state.pendingIds.difference({targetUserId}),
      );
    }
  }

  void refresh() => _loadInitial();
}

// ── Providers ──

final likesProvider =
    StateNotifierProvider<LikesNotifier, LikesState>(
  (_) => LikesNotifier(),
);

/// 用于监听 Supabase Realtime 的 StreamProvider
/// 当其他设备上操作了喜欢，本机也能同步更新
final likesStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;
  if (userId == null) return const Stream.empty();

  return client
      .from('user_likes')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false);
});

// ── Mock 数据（演示模式）──

final _mockEntries = [
  LikedEntry.mock(
    'provider_001',
    '小樱 🌸',
    'https://picsum.photos/seed/like1/400/600',
  ),
  LikedEntry.mock(
    'provider_002',
    '星野 📸',
    'https://picsum.photos/seed/like2/400/600',
  ),
  LikedEntry.mock(
    'provider_003',
    '凉宫 🎮',
    'https://picsum.photos/seed/like3/400/600',
  ),
  LikedEntry.mock(
    'provider_004',
    '派蒙 ✨',
    'https://picsum.photos/seed/like4/400/600',
  ),
  LikedEntry.mock(
    'provider_005',
    '神乐 🎭',
    'https://picsum.photos/seed/like5/400/600',
  ),
];
