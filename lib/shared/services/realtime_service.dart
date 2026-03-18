import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ──────────────────────────────────────────────────────────────
// RealtimeService：封装 Supabase Realtime 监听
//
// 架构说明：
//   · 每个业务维度（消息 / 订单）使用独立 channel，避免互相干扰
//   · 使用 StreamController 把 Postgres 变更事件转换为 Dart Stream
//   · Riverpod StreamProvider 自动管理生命周期（unmount 时 cancel）
//   · 心跳超时自动重连（Supabase SDK 内置，无需手动处理）
// ──────────────────────────────────────────────────────────────

class RealtimeService {
  RealtimeService._();

  static SupabaseClient get _db => Supabase.instance.client;

  // ════════════════════════════════════════════
  // 1. 私信实时监听
  //    · 监听 messages 表 INSERT 事件
  //    · 过滤条件：receiver_id = 当前用户（仅接收属于自己的消息）
  //    · 注意：RLS 在 Realtime 中同样生效，DB 层已保证安全
  // ════════════════════════════════════════════

  static Stream<Map<String, dynamic>> listenNewMessages(String userId) {
    final ctrl = StreamController<Map<String, dynamic>>.broadcast();

    final channel = _db
        .channel('messages_inbox_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          // Realtime 过滤器：只推送收件人为当前用户的消息
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            if (!ctrl.isClosed) {
              ctrl.add(payload.newRecord);
            }
          },
        )
        .subscribe((status, [error]) {
          if (error != null) {
            ctrl.addError(Exception('Realtime 连接异常: $error'));
          }
        });

    // Stream 关闭时自动取消订阅，防止内存泄漏
    ctrl.onCancel = () {
      channel.unsubscribe();
    };

    return ctrl.stream;
  }

  // ════════════════════════════════════════════
  // 2. 订单状态实时监听
  //    · 监听 bookings 表 UPDATE 事件（状态变更）
  //    · 买家和卖家都需要监听（通过 customer_id / provider_id 过滤）
  //    · 当状态变为 'paid' → 卖家 App 弹出新订单提醒
  //    · 当状态变为 'confirmed' → 买家 App 弹出确认通知
  // ════════════════════════════════════════════

  static Stream<Map<String, dynamic>> listenBookingUpdates(String userId) {
    final ctrl = StreamController<Map<String, dynamic>>.broadcast();

    // 买家频道：监听自己下的单
    final customerChannel = _db
        .channel('bookings_customer_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'customer_id',
            value: userId,
          ),
          callback: (payload) {
            if (!ctrl.isClosed) {
              ctrl.add({
                'role': 'customer',
                ...payload.newRecord,
                'old_status': payload.oldRecord['status'],
              });
            }
          },
        )
        .subscribe();

    // 卖家频道：监听接到的单
    final providerChannel = _db
        .channel('bookings_provider_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'provider_id',
            value: userId,
          ),
          callback: (payload) {
            if (!ctrl.isClosed) {
              ctrl.add({
                'role': 'provider',
                ...payload.newRecord,
                'old_status': payload.oldRecord['status'],
              });
            }
          },
        )
        .subscribe();

    ctrl.onCancel = () {
      customerChannel.unsubscribe();
      providerChannel.unsubscribe();
    };

    return ctrl.stream;
  }

  // ════════════════════════════════════════════
  // 3. 聊天室内消息双向监听
  //    · 监听指定对话（sender/receiver 双向过滤）
  //    · 返回 Stream<List<Map>>，用于聊天页面增量更新
  // ════════════════════════════════════════════

  static Stream<Map<String, dynamic>> listenChatRoom({
    required String currentUserId,
    required String otherUserId,
  }) {
    final ctrl = StreamController<Map<String, dynamic>>.broadcast();

    // 频道 ID 按双方 ID 排序拼接，确保同一对话复用同一频道
    final ids = [currentUserId, otherUserId]..sort();
    final channelId = 'chat_${ids[0]}_${ids[1]}';

    final channel = _db
        .channel(channelId)
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final record = payload.newRecord;
            final senderId = record['sender_id'] as String?;
            final receiverId = record['receiver_id'] as String?;

            // 仅转发属于这个对话的消息
            final relevant = (senderId == currentUserId && receiverId == otherUserId) ||
                (senderId == otherUserId && receiverId == currentUserId);

            if (relevant && !ctrl.isClosed) {
              ctrl.add(record);
            }
          },
        )
        .subscribe();

    ctrl.onCancel = () => channel.unsubscribe();
    return ctrl.stream;
  }

  // ════════════════════════════════════════════
  // 4. 达人审核状态变更监听
  //    · 仅监听自己的 profile 行（UPDATE 事件）
  //    · 审核通过 / 拒绝时实时通知用户，无需刷新页面
  // ════════════════════════════════════════════

  static Stream<Map<String, dynamic>> listenAuditStatus(String userId) {
    final ctrl = StreamController<Map<String, dynamic>>.broadcast();

    final channel = _db
        .channel('audit_status_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            final newRecord = payload.newRecord;
            final oldRecord = payload.oldRecord;
            // 只在 audit_status 实际变化时推送
            if (newRecord['audit_status'] != oldRecord['audit_status'] &&
                !ctrl.isClosed) {
              ctrl.add({
                'new_status': newRecord['audit_status'],
                'old_status': oldRecord['audit_status'],
              });
            }
          },
        )
        .subscribe();

    ctrl.onCancel = () => channel.unsubscribe();
    return ctrl.stream;
  }
}

// ──────────────────────────────────────────────────────────────
// Riverpod StreamProviders（自动管理订阅生命周期）
// ──────────────────────────────────────────────────────────────

/// 新私信监听（全局，用于底部 Tab 未读数角标）
final newMessageStreamProvider = StreamProvider.family<
    Map<String, dynamic>, String>((ref, userId) {
  return RealtimeService.listenNewMessages(userId);
});

/// 订单状态变更（全局，用于弹出通知）
final bookingUpdateStreamProvider = StreamProvider.family<
    Map<String, dynamic>, String>((ref, userId) {
  return RealtimeService.listenBookingUpdates(userId);
});

/// 聊天室消息（聊天详情页使用）
final chatRoomStreamProvider = StreamProvider.family<
    Map<String, dynamic>,
    ({String currentUserId, String otherUserId})>((ref, ids) {
  return RealtimeService.listenChatRoom(
    currentUserId: ids.currentUserId,
    otherUserId: ids.otherUserId,
  );
});

/// 审核状态变更（达人入驻后监听）
final auditStatusStreamProvider = StreamProvider.family<
    Map<String, dynamic>, String>((ref, userId) {
  return RealtimeService.listenAuditStatus(userId);
});

// ──────────────────────────────────────────────────────────────
// 未读消息计数 Notifier（结合 Realtime 实时更新角标）
// ──────────────────────────────────────────────────────────────

class UnreadCountNotifier extends StateNotifier<int> {
  UnreadCountNotifier(this._userId) : super(0) {
    _init();
  }

  final String _userId;
  StreamSubscription<Map<String, dynamic>>? _sub;

  Future<void> _init() async {
    // 启动时查一次未读总数
    await _fetchCount();

    // 监听新消息增量 +1
    _sub = RealtimeService.listenNewMessages(_userId).listen((_) {
      state = state + 1;
    });
  }

  Future<void> _fetchCount() async {
    try {
      // 直接取列表长度作为未读数，避免 FetchOptions API 版本差异问题
      final data = await Supabase.instance.client
          .from('messages')
          .select('id')
          .eq('receiver_id', _userId)
          .eq('is_read', false);
      state = (data as List).length;
    } catch (_) {}
  }

  void markAllRead() => state = 0;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final unreadCountProvider =
    StateNotifierProvider.family<UnreadCountNotifier, int, String>(
  (ref, userId) => UnreadCountNotifier(userId),
);
