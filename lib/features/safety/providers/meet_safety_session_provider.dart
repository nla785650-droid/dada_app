import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 买家点击「确认见面」后进入的约见安全态（PureGet 沉浸式守护模拟）
class MeetSafetySessionState {
  const MeetSafetySessionState({
    this.active = false,
    this.bookingId,
    this.counterpartyName = '',
    this.counterpartyPureGetRef = '',
    this.arrivalCheckDue,
    this.pendingArrivalNudge = false,
  });

  final bool active;
  final String? bookingId;
  final String counterpartyName;
  /// 展示在「行程共享」文案中的对方 PureGet 信用档案编号（演示）
  final String counterpartyPureGetRef;
  final DateTime? arrivalCheckDue;
  /// 预定时间内未点「确认到达」时由定时器触发（由首页/浮层消费）
  final bool pendingArrivalNudge;

  MeetSafetySessionState copyWith({
    bool? active,
    String? bookingId,
    String? counterpartyName,
    String? counterpartyPureGetRef,
    DateTime? arrivalCheckDue,
    bool? pendingArrivalNudge,
    bool clearBooking = false,
  }) {
    return MeetSafetySessionState(
      active: active ?? this.active,
      bookingId: clearBooking ? null : (bookingId ?? this.bookingId),
      counterpartyName: counterpartyName ?? this.counterpartyName,
      counterpartyPureGetRef:
          counterpartyPureGetRef ?? this.counterpartyPureGetRef,
      arrivalCheckDue: arrivalCheckDue ?? this.arrivalCheckDue,
      pendingArrivalNudge: pendingArrivalNudge ?? this.pendingArrivalNudge,
    );
  }
}

class MeetSafetySessionNotifier extends StateNotifier<MeetSafetySessionState> {
  MeetSafetySessionNotifier() : super(const MeetSafetySessionState());

  Timer? _arrivalWatchTimer;

  void _cancelTimers() {
    _arrivalWatchTimer?.cancel();
    _arrivalWatchTimer = null;
  }

  /// 买家确认即将赴约：打开全局守护条与工具（应在达人已出发/待服务阶段触发）
  void activateMeetupGuard({
    required String bookingId,
    required String counterpartyName,
    String counterpartyPureGetRef = 'PG-VER-8821',
    Duration untilArrivalCheck = const Duration(minutes: 12),
  }) {
    _cancelTimers();
    final due = DateTime.now().add(untilArrivalCheck);
    state = MeetSafetySessionState(
      active: true,
      bookingId: bookingId,
      counterpartyName: counterpartyName,
      counterpartyPureGetRef: counterpartyPureGetRef,
      arrivalCheckDue: due,
      pendingArrivalNudge: false,
    );

    _arrivalWatchTimer = Timer(untilArrivalCheck, () {
      if (!state.active || state.bookingId != bookingId) return;
      state = state.copyWith(pendingArrivalNudge: true);
    });
  }

  /// 买家已在履约页完成「确认到达」：关闭守护（演示：与资金释放节点对齐）
  void completeAfterCustomerArrivalConfirmed() {
    _cancelTimers();
    state = const MeetSafetySessionState();
  }

  /// 用户主动结束守护 / 订单结束
  void deactivate() {
    _cancelTimers();
    state = const MeetSafetySessionState();
  }

  void clearArrivalNudge() {
    if (!state.pendingArrivalNudge) return;
    state = state.copyWith(pendingArrivalNudge: false);
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }
}

final meetSafetySessionProvider =
    StateNotifierProvider<MeetSafetySessionNotifier, MeetSafetySessionState>(
  (ref) => MeetSafetySessionNotifier(),
);
