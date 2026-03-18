import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ══════════════════════════════════════════════════════════════
// PaymentState & Notifier
// ══════════════════════════════════════════════════════════════

enum PaymentStep { idle, processing, success, failed }

class PaymentState {
  const PaymentState({
    this.step = PaymentStep.idle,
    this.verificationCode,
    this.error,
    this.paidBookingId,
  });

  final PaymentStep step;
  final String? verificationCode;
  final String? error;
  final String? paidBookingId;

  bool get isLoading => step == PaymentStep.processing;
  bool get isSuccess => step == PaymentStep.success;

  PaymentState copyWith({
    PaymentStep? step,
    String? verificationCode,
    String? error,
    String? paidBookingId,
  }) =>
      PaymentState(
        step: step ?? this.step,
        verificationCode: verificationCode ?? this.verificationCode,
        error: error ?? this.error,
        paidBookingId: paidBookingId ?? this.paidBookingId,
      );
}

class PaymentNotifier extends StateNotifier<PaymentState> {
  PaymentNotifier() : super(const PaymentState());

  static SupabaseClient get _db => Supabase.instance.client;

  // ── 新流程：从时间轴选择时段后支付（原子创建订单+锁档期）──
  // 调用 create_booking_with_lock RPC，原子操作防并发双预订
  Future<bool> payWithSlot({
    required String slotId,
    required String postId,
    required String providerId,
    required double amount,
    String? notes,
  }) async {
    state = state.copyWith(step: PaymentStep.processing);
    try {
      await Future.delayed(const Duration(milliseconds: 1200));

      final result = await _db.rpc('create_booking_with_lock', params: {
        'p_slot_id':  slotId,
        'p_post_id':  postId,
        'p_amount':   amount,
        'p_notes':    notes,
      }) as Map<String, dynamic>?;

      if (result == null || result['success'] != true) {
        final msg = result?['message'] as String? ?? '预约失败，请重试';
        state = state.copyWith(step: PaymentStep.failed, error: msg);
        return false;
      }

      final bookingId = result['booking_id'] as String? ??
          'mock-booking-${DateTime.now().millisecondsSinceEpoch}';
      final code = result['verification_code'] as String?;

      state = state.copyWith(
        step: PaymentStep.success,
        verificationCode: code,
        paidBookingId: bookingId,
      );
      return true;
    } on PostgrestException catch (e) {
      // Supabase RPC 错误（如 RLS 拒绝）
      state = state.copyWith(
        step: PaymentStep.failed,
        error: '系统错误：${e.message}',
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        step: PaymentStep.failed,
        error: '支付失败，请重试',
      );
      return false;
    }
  }

  // ── 旧流程：更新已存在订单的支付状态（兼容 BookingScreen）──
  Future<bool> pay(String bookingId, double amount) async {
    state = state.copyWith(step: PaymentStep.processing);
    try {
      await Future.delayed(const Duration(milliseconds: 1200));

      // 生产环境：接入真实支付 SDK 回调，由后端 Webhook 写入状态
      try {
        await _db.from('bookings').update({
          'status':         'paid',
          'payment_method': 'mock',
          'paid_at':        DateTime.now().toIso8601String(),
        }).eq('id', bookingId);

        final result = await _db.rpc(
          'generate_verification_code',
          params: {'booking_id_input': bookingId},
        );
        final code = result as String?;

        state = state.copyWith(
          step: PaymentStep.success,
          verificationCode: code,
          paidBookingId: bookingId,
        );
      } catch (_) {
        // Supabase 未连接时的降级（演示模式）
        final mockCode = _generateMockCode();
        state = state.copyWith(
          step: PaymentStep.success,
          verificationCode: mockCode,
          paidBookingId: bookingId,
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        step: PaymentStep.failed,
        error: '支付失败：${e.toString().split('\n').first}',
      );
      return false;
    }
  }

  // 演示模式下本地生成 mock 核销码
  String _generateMockCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buf = StringBuffer();
    for (var i = 0; i < 8; i++) {
      buf.write(chars[DateTime.now().microsecond % chars.length]);
    }
    return buf.toString();
  }

  void reset() => state = const PaymentState();
}

final paymentProvider =
    StateNotifierProvider.autoDispose<PaymentNotifier, PaymentState>(
  (_) => PaymentNotifier(),
);
