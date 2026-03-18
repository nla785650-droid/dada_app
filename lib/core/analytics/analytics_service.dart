import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

// ══════════════════════════════════════════════════════════════
// AnalyticsService — Clean Architecture · Infrastructure Layer
//
// 职责：
//   · 封装所有埋点写入逻辑（单一职责）
//   · 本地队列批量写入（减少网络请求）
//   · 离线时队列缓存，恢复联网后重发
//   · 不持有 UI 状态，纯数据服务层
// ══════════════════════════════════════════════════════════════

// ── 事件类型枚举（对应 SQL CHECK 约束）──
enum BehaviorEvent {
  cardViewed('card_viewed'),
  cardSwipedLeft('card_swiped_left'),
  cardSwipedRight('card_swiped_right'),
  cardTapped('card_tapped'),
  cardRated('card_rated'),
  postViewed('post_viewed'),
  postLiked('post_liked'),
  postShared('post_shared'),
  bookingStarted('booking_started'),
  bookingPaid('booking_paid'),
  searchPerformed('search_performed'),
  profileViewed('profile_viewed');

  const BehaviorEvent(this.value);
  final String value;
}

// ── 行为事件数据模型 ──
class BehaviorRecord {
  const BehaviorRecord({
    required this.event,
    required this.targetId,
    required this.targetType,
    this.viewDuration,
    this.clickType,
    this.swipeVelocity,
    this.screenContext,
    this.extra,
  });

  final BehaviorEvent event;
  final String targetId;
  final String targetType;
  final int? viewDuration;         // 毫秒
  final String? clickType;         // 'single' | 'double' | 'long_press'
  final double? swipeVelocity;     // px/ms
  final String? screenContext;     // 'discover' | 'home' | 'profile'
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toJson({
    required String? userId,
    required String sessionId,
    required String abGroup,
  }) =>
      {
        'user_id':       userId,
        'session_id':    sessionId,
        'event_type':    event.value,
        'target_id':     targetId,
        'target_type':   targetType,
        'view_duration': viewDuration,
        'click_type':    clickType,
        'swipe_velocity': swipeVelocity,
        'ab_group':      abGroup,
        'screen_context': screenContext,
        'extra':         extra,
        'platform':      'flutter_web',
        'app_version':   '2.0.0',
      };
}

// ══════════════════════════════════════════════════════════════
// AnalyticsService（Singleton via Riverpod）
// ══════════════════════════════════════════════════════════════

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  static SupabaseClient get _db => Supabase.instance.client;

  // 本地队列（最多缓存 100 条，防止内存溢出）
  final List<Map<String, dynamic>> _queue = [];
  static const int _maxQueueSize   = 100;
  static const int _flushBatchSize = 20;

  // 会话 ID：每次启动生成一次
  final String _sessionId = const Uuid().v4();

  // 批量写入定时器（每 10 秒自动 flush 一次）
  Timer? _flushTimer;

  // A/B 实验分组缓存（由 FeatureFlagService 注入）
  String _currentAbGroup = 'control';

  void setAbGroup(String group) => _currentAbGroup = group;

  // ── 启动自动 flush ──
  void init() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _flush(),
    );
  }

  void dispose() {
    _flushTimer?.cancel();
    _flush(); // 最后一次强制写入
  }

  // ── 核心 track 方法 ──
  void track(BehaviorRecord record) {
    final userId = _db.auth.currentUser?.id;
    final json   = record.toJson(
      userId:    userId,
      sessionId: _sessionId,
      abGroup:   _currentAbGroup,
    );

    _queue.add(json);

    // 超过批量阈值立即 flush（高优先级事件）
    if (_queue.length >= _flushBatchSize ||
        record.event == BehaviorEvent.bookingPaid) {
      _flush();
    }
  }

  // ── 便捷方法 ──

  /// 卡片曝光（进入视口时调用，结束时传 duration）
  void trackCardView({
    required String providerId,
    int? durationMs,
  }) =>
      track(BehaviorRecord(
        event:        BehaviorEvent.cardViewed,
        targetId:     providerId,
        targetType:   'provider',
        viewDuration: durationMs,
        screenContext: 'discover',
      ));

  /// 卡片滑动
  void trackCardSwipe({
    required String providerId,
    required bool isLike,
    double? velocity,
  }) =>
      track(BehaviorRecord(
        event:         isLike
            ? BehaviorEvent.cardSwipedRight
            : BehaviorEvent.cardSwipedLeft,
        targetId:      providerId,
        targetType:    'provider',
        swipeVelocity: velocity,
        screenContext: 'discover',
      ));

  /// 打分
  void trackCardRating({
    required String providerId,
    required double rating,
  }) =>
      track(BehaviorRecord(
        event:      BehaviorEvent.cardRated,
        targetId:   providerId,
        targetType: 'provider',
        extra:      {'rating': rating},
        screenContext: 'discover',
      ));

  /// 支付完成
  void trackBookingPaid({
    required String bookingId,
    required double amount,
  }) =>
      track(BehaviorRecord(
        event:      BehaviorEvent.bookingPaid,
        targetId:   bookingId,
        targetType: 'booking',
        extra:      {'amount': amount},
      ));

  // ── 批量 flush 到 Supabase ──
  Future<void> _flush() async {
    if (_queue.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_queue);
    _queue.clear();

    try {
      // 最大批量大小：Supabase 建议 ≤ 500 条/次
      const chunkSize = 50;
      for (var i = 0; i < batch.length; i += chunkSize) {
        final chunk = batch.sublist(
          i,
          (i + chunkSize).clamp(0, batch.length),
        );
        await _db.from('user_behaviors').insert(chunk);
      }
    } catch (_) {
      // 网络失败：将数据放回队列（先进先出，防止无限重试撑爆内存）
      if (_queue.length + batch.length <= _maxQueueSize) {
        _queue.insertAll(0, batch);
      }
    }
  }

  // ── 强制同步 flush（应用退出前调用）──
  Future<void> forceFlush() => _flush();
}

// ── Riverpod Provider ──
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final service = AnalyticsService.instance..init();
  ref.onDispose(service.dispose);
  return service;
});
