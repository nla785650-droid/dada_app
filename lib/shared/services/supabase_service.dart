import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/post_model.dart';
import '../../data/models/profile_model.dart';
import '../../data/models/booking_model.dart';

// ──────────────────────────────────────────────────────────────
// SupabaseService：统一封装所有数据库 CRUD 操作
// 设计原则：
//   · 所有方法抛出 SupabaseException，由调用层统一处理
//   · 分页游标使用 range(offset, offset+limit-1) 避免 COUNT(*)
//   · 只查询必要字段（SELECT 限制）减少带宽消耗
// ──────────────────────────────────────────────────────────────

class SupabaseService {
  SupabaseService._();

  static SupabaseClient get _db => Supabase.instance.client;
  static const _uuid = Uuid();

  // ════════════════════════════════════════════
  // Auth
  // ════════════════════════════════════════════

  static User? get currentUser => _db.auth.currentUser;
  static String? get currentUserId => _db.auth.currentUser?.id;

  static Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    return _db.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
  }

  static Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return _db.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() => _db.auth.signOut();

  // ════════════════════════════════════════════
  // Profiles
  // ════════════════════════════════════════════

  static Future<Profile> fetchProfile(String userId) async {
    final data = await _db
        .from('profiles')
        .select('''
          id, username, display_name, avatar_url, bio,
          role, is_provider, provider_type, audit_status,
          provider_config, rating, review_count, completed_orders,
          is_verified, verification_video_url, location_text,
          created_at
        ''')
        .eq('id', userId)
        .single();
    return Profile.fromJson(data);
  }

  static Future<void> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    await _db
        .from('profiles')
        .update({...updates, 'updated_at': DateTime.now().toIso8601String()})
        .eq('id', userId);
  }

  /// 附近的达人（PostGIS 地理查询）
  /// [latLng] 格式: 'POINT(lng lat)'（WGS-84 坐标）
  static Future<List<Profile>> fetchNearbyProviders({
    required double lat,
    required double lng,
    double radiusKm = 50,
    String? providerType,
    int limit = 20,
  }) async {
    // 使用 Supabase RPC 调用 PostGIS ST_DWithin 函数
    // 函数在 DB 中定义，此处仅传参数
    final data = await _db.rpc('nearby_providers', params: {
      'lat': lat,
      'lng': lng,
      'radius_km': radiusKm,
      'category': providerType,
      'lmt': limit,
    });
    return (data as List).map((e) => Profile.fromJson(e)).toList();
  }

  // ════════════════════════════════════════════
  // Posts — 瀑布流分页加载
  // ════════════════════════════════════════════

  /// 瀑布流分页：使用 range(from, to) 游标，避免昂贵的 COUNT(*)
  /// [page] 从 0 开始，[pageSize] 建议 20
  static Future<List<Post>> fetchPosts({
    int page = 0,
    int pageSize = 20,
    String? category,    // 分类过滤
    String? keyword,     // 标题模糊搜索（trigram）
    String? orderBy,     // 'rating' | 'price_asc' | 'price_desc' | 'newest'
  }) async {
    // dynamic 类型避免 filter→transform 类型收窄导致的编译错误
    dynamic query = _db
        .from('posts')
        .select('''
          id, provider_id, title, description, category,
          images, cover_image, price, price_unit, tags,
          location_text, view_count, like_count, booking_count,
          created_at,
          profiles!posts_provider_id_fkey (
            id, username, display_name, avatar_url,
            rating, review_count, is_verified, audit_status
          )
        ''')
        .eq('is_active', true);

    if (category != null && category != 'all') {
      query = query.eq('category', category);
    }

    if (keyword != null && keyword.isNotEmpty) {
      // ilike 触发 trigram 索引（需要 pg_trgm + GIN 索引）
      query = query.ilike('title', '%$keyword%');
    }

    // 排序策略（调用 order 后类型升为 PostgrestTransformBuilder，用 dynamic 承接）
    switch (orderBy ?? 'newest') {
      case 'rating':
        query = query.order('created_at', ascending: false);
      case 'price_asc':
        query = query.order('price', ascending: true);
      case 'price_desc':
        query = query.order('price', ascending: false);
      case 'newest':
      default:
        query = query
            .order('is_featured', ascending: false)
            .order('created_at', ascending: false);
    }

    final from = page * pageSize;
    final to = from + pageSize - 1;
    final data = await query.range(from, to);

    return (data as List).map((e) => Post.fromJson(e)).toList();
  }

  static Future<Post> fetchPostById(String postId) async {
    final data = await _db
        .from('posts')
        .select('''
          *,
          profiles!posts_provider_id_fkey (*)
        ''')
        .eq('id', postId)
        .single();
    return Post.fromJson(data);
  }

  static Future<String> createPost(Map<String, dynamic> postData) async {
    final response = await _db
        .from('posts')
        .insert(postData)
        .select('id')
        .single();
    return response['id'] as String;
  }

  /// 增加浏览计数（乐观更新，不等待结果）
  static void incrementViewCount(String postId) {
    _db.rpc('increment_post_view', params: {'post_id': postId}).then(
      (_) {},
      onError: (_) {}, // 浏览计数失败不影响用户体验
    );
  }

  // ════════════════════════════════════════════
  // Bookings — 订单管理
  // ════════════════════════════════════════════

  static Future<Booking> createBooking({
    required String postId,
    required String providerId,
    required DateTime bookingDate,
    required String startTime,
    required String endTime,
    required double amount,
    String? customerNote,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('用户未登录');

    // 前端预检：查询 blocked_schedules 是否冲突
    final conflicts = await _db
        .from('blocked_schedules')
        .select('id')
        .eq('provider_id', providerId)
        .eq('booking_date', bookingDate.toIso8601String().split('T').first)
        .limit(1);

    if ((conflicts as List).isNotEmpty) {
      throw Exception('该时间档期已被预约，请选择其他时间');
    }

    final data = await _db
        .from('bookings')
        .insert({
          'post_id':       postId,
          'customer_id':   userId,
          'provider_id':   providerId,
          'booking_date':  bookingDate.toIso8601String().split('T').first,
          'start_time':    startTime,
          'end_time':      endTime,
          'amount':        amount,
          // 平台抽成 10%，快照在订单创建时
          'platform_fee':  (amount * 0.10).toStringAsFixed(2),
          'customer_note': customerNote,
        })
        .select()
        .single();

    return Booking.fromJson(data);
  }

  /// 更新订单状态（由触发器守护合法流转）
  static Future<void> updateBookingStatus(
    String bookingId,
    String newStatus, {
    String? cancelReason,
    String? cancelBy,
  }) async {
    final updates = <String, dynamic>{'status': newStatus};
    if (cancelReason != null) updates['cancel_reason'] = cancelReason;
    if (cancelBy != null) updates['cancel_by'] = cancelBy;

    await _db.from('bookings').update(updates).eq('id', bookingId);
  }

  /// 模拟支付（生产环境替换为真实支付网关回调）
  static Future<void> mockPay(String bookingId) async {
    await _db.from('bookings').update({
      'status':         'paid',
      'payment_method': 'mock',
      'payment_ref':    'MOCK_${_uuid.v4().substring(0, 8).toUpperCase()}',
    }).eq('id', bookingId);
  }

  static Future<List<Booking>> fetchMyBookings({
    required bool asCustomer, // true=买家视角，false=卖家视角
    String? status,
    int page = 0,
    int pageSize = 20,
  }) async {
    final userId = currentUserId;
    if (userId == null) return [];

    var query = _db
        .from('bookings')
        .select('''
          *,
          posts!bookings_post_id_fkey (id, title, cover_image),
          customer:profiles!bookings_customer_id_fkey (id, display_name, avatar_url),
          provider:profiles!bookings_provider_id_fkey (id, display_name, avatar_url)
        ''');

    query = asCustomer
        ? query.eq('customer_id', userId)
        : query.eq('provider_id', userId);

    if (status != null) query = query.eq('status', status);

    final from = page * pageSize;
    final data = await query
        .order('created_at', ascending: false)
        .range(from, from + pageSize - 1);

    return (data as List).map((e) => Booking.fromJson(e)).toList();
  }

  // ════════════════════════════════════════════
  // Reviews — 评价
  // ════════════════════════════════════════════

  static Future<void> submitReview({
    required String bookingId,
    required String revieweeId,
    required int ratingOverall,
    int? ratingPunctual,
    int? ratingQuality,
    int? ratingService,
    String? comment,
    List<String> photoUrls = const [],
    bool isAnonymous = false,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('用户未登录');

    await _db.from('reviews').insert({
      'booking_id':      bookingId,
      'reviewer_id':     userId,
      'reviewee_id':     revieweeId,
      'rating_overall':  ratingOverall,
      'rating_punctual': ratingPunctual,
      'rating_quality':  ratingQuality,
      'rating_service':  ratingService,
      'comment':         comment,
      'photo_urls':      photoUrls,
      'is_anonymous':    isAnonymous,
    });
    // 评分更新由 DB 触发器 reviews_update_rating 自动完成
  }

  static Future<List<Map<String, dynamic>>> fetchProviderReviews(
    String providerId, {
    int page = 0,
    int pageSize = 10,
  }) async {
    final from = page * pageSize;
    final data = await _db
        .from('reviews')
        .select('''
          id, rating_overall, rating_punctual, rating_quality, rating_service,
          comment, photo_urls, is_anonymous, created_at, reply, replied_at,
          reviewer:profiles!reviews_reviewer_id_fkey (
            id, display_name, avatar_url, username
          )
        ''')
        .eq('reviewee_id', providerId)
        .eq('visibility', 'public')
        .order('created_at', ascending: false)
        .range(from, from + pageSize - 1);

    return (data as List).cast<Map<String, dynamic>>();
  }

  // ════════════════════════════════════════════
  // Storage — 文件上传
  // ════════════════════════════════════════════

  /// 上传头像，返回公开 URL
  static Future<String> uploadAvatar(File file, String userId) async {
    final ext = file.path.split('.').last.toLowerCase();
    final path = '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _db.storage.from('avatars').upload(
      path,
      file,
      fileOptions: FileOptions(
        contentType: 'image/$ext',
        upsert: true,
      ),
    );
    return _db.storage.from('avatars').getPublicUrl(path);
  }

  /// 批量上传作品集图片，返回 URL 列表
  static Future<List<String>> uploadPortfolios(
    List<File> files,
    String userId, {
    void Function(int done, int total)? onProgress,
  }) async {
    final urls = <String>[];

    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = file.path.split('.').last.toLowerCase();
      final path = '$userId/portfolio_${_uuid.v4()}.$ext';

      await _db.storage.from('portfolios').upload(
        path,
        file,
        fileOptions: FileOptions(contentType: 'image/$ext'),
      );
      urls.add(_db.storage.from('portfolios').getPublicUrl(path));
      onProgress?.call(i + 1, files.length);
    }
    return urls;
  }

  // ════════════════════════════════════════════
  // 达人档期查询
  // ════════════════════════════════════════════

  /// 查询某达人在指定月份内的已锁定档期（用于日历展示）
  static Future<List<Map<String, dynamic>>> fetchBlockedSchedules(
    String providerId,
    DateTime month,
  ) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0);

    final data = await _db
        .from('blocked_schedules')
        .select('booking_date, start_time, end_time')
        .eq('provider_id', providerId)
        .gte('booking_date', start.toIso8601String().split('T').first)
        .lte('booking_date', end.toIso8601String().split('T').first);

    return (data as List).cast<Map<String, dynamic>>();
  }
}

// ──────────────────────────────────────────────────────────────
// Riverpod Provider 封装
// ──────────────────────────────────────────────────────────────

final supabaseServiceProvider = Provider<SupabaseService>((_) {
  // SupabaseService 是纯静态类，此处仅作类型注册
  return SupabaseService._();
});

final currentUserProfileProvider = FutureProvider<Profile?>((ref) async {
  final userId = SupabaseService.currentUserId;
  if (userId == null) return null;
  return SupabaseService.fetchProfile(userId);
});

final authStateStreamProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});
