import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ══════════════════════════════════════════════════════════════
// 订单状态 Provider（含 Realtime 监听）
// ══════════════════════════════════════════════════════════════

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.status,
    required this.amount,
    required this.serviceName,
    required this.providerName,
    required this.providerAvatar,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.createdAt,
    this.verificationCode,
    this.verifiedAt,
    this.paymentMethod,
  });

  final String id;
  final String status;
  final double amount;
  final String serviceName;
  final String providerName;
  final String providerAvatar;
  final String bookingDate;
  final String startTime;
  final String endTime;
  final DateTime createdAt;
  final String? verificationCode;
  final DateTime? verifiedAt;
  final String? paymentMethod;

  bool get isPaid => status == 'paid' || status == 'partially_released';
  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';

  String get statusLabel => switch (status) {
        'pending'            => '待支付',
        'paid'               => '已支付',
        'confirmed'          => '已确认',
        'partially_released' => '服务中',
        'in_progress'        => '服务中',
        'completed'          => '已完成',
        'cancelled'          => '已取消',
        'expired'            => '已过期',
        _                    => status,
      };

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final post = json['posts'] as Map<String, dynamic>? ?? {};
    final provider = json['provider'] as Map<String, dynamic>? ?? {};

    return OrderDetail(
      id:               json['id'] as String,
      status:           json['status'] as String? ?? 'pending',
      amount:           (json['amount'] as num).toDouble(),
      serviceName:      post['title'] as String? ?? '服务',
      providerName:     provider['display_name'] as String? ?? '达人',
      providerAvatar:   provider['avatar_url'] as String? ?? '',
      bookingDate:      json['booking_date'] as String,
      startTime:        json['start_time'] as String,
      endTime:          json['end_time'] as String,
      createdAt:        DateTime.parse(json['created_at'] as String),
      verificationCode: json['verification_code'] as String?,
      verifiedAt:       json['verified_at'] != null
                        ? DateTime.parse(json['verified_at'] as String)
                        : null,
      paymentMethod:    json['payment_method'] as String?,
    );
  }

  OrderDetail copyWith({String? status, String? verificationCode, DateTime? verifiedAt}) =>
      OrderDetail(
        id: id, amount: amount, serviceName: serviceName,
        providerName: providerName, providerAvatar: providerAvatar,
        bookingDate: bookingDate, startTime: startTime, endTime: endTime,
        createdAt: createdAt, paymentMethod: paymentMethod,
        status:           status ?? this.status,
        verificationCode: verificationCode ?? this.verificationCode,
        verifiedAt:       verifiedAt ?? this.verifiedAt,
      );
}

// ── Notifier ──
class OrderNotifier extends StateNotifier<AsyncValue<OrderDetail>> {
  OrderNotifier(this._bookingId) : super(const AsyncValue.loading()) {
    _load();
  }

  final String _bookingId;
  RealtimeChannel? _channel;

  static SupabaseClient get _db => Supabase.instance.client;

  Future<void> _load() async {
    try {
      final data = await _db.from('bookings').select('''
        id, status, amount, booking_date, start_time, end_time,
        created_at, verification_code, verified_at, payment_method,
        posts!bookings_post_id_fkey (title),
        provider:profiles!bookings_provider_id_fkey (display_name, avatar_url)
      ''').eq('id', _bookingId).single();

      state = AsyncValue.data(OrderDetail.fromJson(data));
      _subscribeRealtime();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = _db
        .channel('order_status_$_bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: _bookingId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            // 当买家端 Realtime 收到状态更新，直接更新本地状态
            state.whenData((current) {
              state = AsyncValue.data(current.copyWith(
                status:           record['status'] as String?,
                verificationCode: record['verification_code'] as String?,
                verifiedAt:       record['verified_at'] != null
                    ? DateTime.parse(record['verified_at'] as String)
                    : null,
              ));
            });
          },
        )
        .subscribe();
  }

  Future<void> refresh() => _load();

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

final orderProvider = StateNotifierProvider.autoDispose
    .family<OrderNotifier, AsyncValue<OrderDetail>, String>(
  (_, bookingId) => OrderNotifier(bookingId),
);
