import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../booking/providers/order_provider.dart';

// ══════════════════════════════════════════════════════════════
// OrdersStreamProvider：我的订单 StreamProvider
//
// 使用 Supabase realtime stream 订阅 bookings 表
// 支付成功后无需手动刷新，订单列表实时更新
// ══════════════════════════════════════════════════════════════

// 订单摘要（用于列表展示，比 OrderDetail 更轻量）
class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.status,
    required this.amount,
    required this.serviceName,
    required this.providerName,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    this.verificationCode,
    this.providerAvatar,
  });

  final String id;
  final String status;
  final double amount;
  final String serviceName;
  final String providerName;
  final String? providerAvatar;
  final String bookingDate;
  final String startTime;
  final String endTime;
  final DateTime createdAt;
  final String? verificationCode;

  bool get isPaid => status == 'paid' || status == 'partially_released';
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';
  bool get isCancelled => status == 'cancelled' || status == 'expired';

  String get statusLabel => switch (status) {
        'pending'            => '待支付',
        'paid'               => '已支付·待核销',
        'confirmed'          => '已确认',
        'partially_released' => '服务中',
        'in_progress'        => '服务中',
        'completed'          => '已完成',
        'cancelled'          => '已取消',
        'expired'            => '已过期',
        _                    => status,
      };

  Color get statusColor {
    return switch (status) {
      'pending'   => const Color(0xFFF59E0B),
      'paid'      => const Color(0xFF6366F1),
      'completed' => const Color(0xFF10B981),
      'cancelled' || 'expired' => const Color(0xFFEF4444),
      _           => const Color(0xFF9CA3AF),
    };
  }

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final post = json['posts'] as Map<String, dynamic>? ?? {};
    final provider = json['provider'] as Map<String, dynamic>? ?? {};
    return OrderSummary(
      id:               json['id'] as String,
      status:           json['status'] as String? ?? 'pending',
      amount:           (json['amount'] as num? ?? 0).toDouble(),
      serviceName:      post['title'] as String? ?? '服务',
      providerName:     provider['display_name'] as String? ?? '达人',
      providerAvatar:   provider['avatar_url'] as String?,
      bookingDate:      json['booking_date'] as String? ?? '',
      startTime:        json['start_time'] as String? ?? '',
      endTime:          json['end_time'] as String? ?? '',
      createdAt:        DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      verificationCode: json['verification_code'] as String?,
    );
  }

  // 从支付成功后的 extra 创建（本地乐观更新，不等 Supabase 响应）
  factory OrderSummary.fromExtra(
    String bookingId,
    Map<String, dynamic> extra,
  ) =>
      OrderSummary(
        id:           bookingId,
        status:       'paid',
        amount:       (extra['amount'] as num? ?? 0).toDouble(),
        serviceName:  extra['serviceName'] as String? ?? '服务',
        providerName: extra['providerName'] as String? ?? '达人',
        bookingDate:  extra['slotDate'] != null
            ? _formatDate(DateTime.parse(extra['slotDate'] as String))
            : DateTime.now().toString().substring(0, 10),
        startTime:    extra['startTime'] as String? ?? '',
        endTime:      extra['endTime'] as String? ?? '',
        createdAt:    DateTime.now(),
      );

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

// ── Mock 数据（Supabase 离线时使用）──
final _mockOrders = [
  OrderSummary(
    id:           'mock-booking-001',
    status:       'paid',
    amount:       350,
    serviceName:  '🎭 精品Coser | 汉服古风',
    providerName: '小樱',
    bookingDate:  '2026-03-20',
    startTime:    '14:00',
    endTime:      '17:00',
    createdAt:    DateTime.now().subtract(const Duration(hours: 2)),
    verificationCode: 'AB12CD34',
  ),
  OrderSummary(
    id:           'mock-booking-002',
    status:       'pending',
    amount:       180,
    serviceName:  '📸 摄影陪拍 | 日系写真',
    providerName: '星野',
    bookingDate:  '2026-03-22',
    startTime:    '10:00',
    endTime:      '12:00',
    createdAt:    DateTime.now().subtract(const Duration(hours: 5)),
  ),
  OrderSummary(
    id:           'mock-booking-003',
    status:       'completed',
    amount:       120,
    serviceName:  '🎮 王者荣耀陪玩',
    providerName: '凉宫',
    bookingDate:  '2026-03-15',
    startTime:    '20:00',
    endTime:      '22:00',
    createdAt:    DateTime.now().subtract(const Duration(days: 2)),
    verificationCode: 'XZ98WQ76',
  ),
];

// ── StreamProvider（Supabase Realtime）──
final myOrdersStreamProvider =
    StreamProvider.autoDispose<List<OrderSummary>>((ref) {
  final client = Supabase.instance.client;
  final userId = client.auth.currentUser?.id;

  // 未登录则返回 mock 数据流（开发演示）
  if (userId == null) {
    return Stream.value(_mockOrders);
  }

  // Supabase realtime stream 订阅，含关联查询
  return client
      .from('bookings')
      .stream(primaryKey: ['id'])
      .eq('customer_id', userId)
      .order('created_at', ascending: false)
      .map((data) => data.map((json) {
            try {
              return OrderSummary.fromJson(json);
            } catch (_) {
              return null;
            }
          })
          .whereType<OrderSummary>()
          .toList());
});

// ── 给 OrderDetail 使用的 mock 转换 ──
extension OrderSummaryToDetail on OrderSummary {
  OrderDetail toDetail() => OrderDetail(
        id:           id,
        status:       status,
        amount:       amount,
        serviceName:  serviceName,
        providerName: providerName,
        providerAvatar: providerAvatar ?? '',
        bookingDate:  bookingDate,
        startTime:    startTime,
        endTime:      endTime,
        createdAt:    createdAt,
        verificationCode: verificationCode,
      );
}
