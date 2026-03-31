import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/service_execution_model.dart';
import '../providers/fulfillment_provider.dart';
import '../widgets/arrival_verify_sheet.dart';
import '../widgets/service_timeline.dart';
import '../widgets/trip_share_card.dart';
import '../widgets/virtual_dial_button.dart';
import '../../safety/providers/meet_safety_session_provider.dart';
import '../../safety/widgets/safety_control_panel.dart';
import '../../safety/providers/location_provider.dart';

// ══════════════════════════════════════════════════════════════
// FulfillmentScreen：服务履约主页面
//
// 布局：
//   · 顶部：Hero 封面图 + 订单信息卡（毛玻璃）
//   · 中部：ServiceTimeline 节点进度条
//   · 底部：动态操作区（根据角色 + 当前节点变化）
//     - 达人端：「打卡出发」「到达拍照核验」「开始/结束服务」
//     - 买家端：「确认到达」「联系达人」「行程分享」
// ══════════════════════════════════════════════════════════════

class FulfillmentScreen extends ConsumerStatefulWidget {
  const FulfillmentScreen({
    super.key,
    required this.bookingId,
    this.isProvider = false,
  });

  final String bookingId;
  final bool isProvider;

  @override
  ConsumerState<FulfillmentScreen> createState() => _FulfillmentScreenState();
}

class _FulfillmentScreenState extends ConsumerState<FulfillmentScreen> {
  bool _safetyPanelExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(fulfillmentProvider.notifier);
      notifier
        ..load(widget.bookingId, isProvider: widget.isProvider)
        ..subscribeRealtime(widget.bookingId);
    });
  }

  // 当订单进入"履约中"状态时，自动开启守护模式
  void _maybeActivateGuardian(ServiceExecution exec) {
    if (exec.currentNode == ServiceNode.arrived ||
        exec.currentNode == ServiceNode.inProgress) {
      final safety = ref.read(safetyProvider(widget.bookingId));
      if (!safety.isGuardianActive) {
        ref
            .read(safetyProvider(widget.bookingId).notifier)
            .startGuardian(widget.bookingId);
        // 自动展开安全面板
        if (!_safetyPanelExpanded) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => setState(() => _safetyPanelExpanded = true));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fulfillmentProvider);
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(context, state),
      body: state.isLoading
          ? _LoadingView()
          : state.execution == null
              ? _ErrorView(error: state.error)
              : _buildBody(context, state, mq),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, FulfillmentState state) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Container(
          margin: const EdgeInsets.only(left: 16),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black38,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
        ),
      ),
      title: state.execution != null
          ? Text(
              '服务履约',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
      actions: [
        if (state.execution != null)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => _showShareCard(context, state.execution!),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, FulfillmentState state, MediaQueryData mq) {
    final exec = state.execution!;

    // 在服务到达/进行中阶段自动激活安全守护
    _maybeActivateGuardian(exec);

    final safetyState = ref.watch(safetyProvider(widget.bookingId));
    final isGuardianActive = safetyState.isGuardianActive;

    return Stack(
      children: [
        // ── 主滚动内容 ──
        CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // 顶部 Hero 封面
            SliverToBoxAdapter(child: _HeroBanner(execution: exec)),

            // 节点进度条卡片
            SliverToBoxAdapter(
              child: _SectionCard(
                title: '服务进度',
                child: ServiceTimeline(
                  currentNode: exec.currentNode,
                  checkpoints: exec.checkpoints,
                  isProvider: exec.isProvider,
                ),
              ),
            ),

            // ── 安全守护中心卡片（到达后展示）──
            if (exec.currentNode == ServiceNode.arrived ||
                exec.currentNode == ServiceNode.inProgress)
              SliverToBoxAdapter(
                child: _SafetyHubCard(
                  bookingId:  widget.bookingId,
                  isProvider: widget.isProvider,
                  isExpanded: _safetyPanelExpanded,
                  isActive:   isGuardianActive,
                  onToggle:   () => setState(
                      () => _safetyPanelExpanded = !_safetyPanelExpanded),
                ),
              ),

            // 资金托管状态卡片
            SliverToBoxAdapter(
              child: _EscrowStatusCard(execution: exec),
            ),

            // 联系 / 安全工具卡片
            SliverToBoxAdapter(
              child: _SectionCard(
                title: '安全联系',
                child: Column(
                  children: [
                    if (exec.maskedPhone != null)
                      VirtualDialButton(
                        maskedPhone: exec.maskedPhone!,
                        bookingId: exec.bookingId,
                      ),
                    const SizedBox(height: 12),
                    _SafetyTipRow(),
                  ],
                ),
              ),
            ),

            // 底部留出操作栏高度
            SliverToBoxAdapter(
              child: SizedBox(height: 100 + mq.padding.bottom),
            ),
          ],
        ),

        // ── 底部固定操作栏 ──
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _ActionBar(
            state: state,
            isProvider: widget.isProvider,
            onAction: () => _handleAction(context, state),
            onCustomerConfirm: () => _handleCustomerConfirm(context, state),
            onConfirmMeetup: () => _handleConfirmMeetup(context, state),
            onShareTrip: state.execution == null
                ? null
                : () => _showShareCard(context, state.execution!),
          ),
        ),

        // ── 上传进度浮层 ──
        if (state.isSubmitting)
          _SubmittingOverlay(progress: state.uploadProgress),
      ],
    );
  }

  // ────────────────────────────────────────
  // 达人操作：打卡 / 到达拍照 / 开始服务 / 结束服务
  // ────────────────────────────────────────

  Future<void> _handleAction(BuildContext context, FulfillmentState state) async {
    final exec = state.execution;
    if (exec == null) return;

    final node = exec.currentNode;

    if (node == ServiceNode.finished) return;

    // arrived 节点：强制拍照核验
    if (node == ServiceNode.arrived) {
      final locationText = await _resolveLocationText();
      if (!context.mounted) return;
      _showArrivalCamera(context, exec, locationText);
      return;
    }

    // 其他节点：直接打卡（可附加位置）
    final locationText = await _resolveLocationText();
    await ref.read(fulfillmentProvider.notifier).advanceNode(
          locationText: locationText,
        );
  }

  // ────────────────────────────────────────
  // 买家确认到达
  // ────────────────────────────────────────

  Future<void> _handleCustomerConfirm(
      BuildContext context, FulfillmentState state) async {
    final exec = state.execution;
    if (exec == null) return;

    final arrivedCp = exec.checkpointFor(ServiceNode.arrived);
    if (arrivedCp == null || arrivedCp.confirmedByCustomer) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmArrivalDialog(
        photoUrl: arrivedCp.photoUrl,
        locationText: arrivedCp.locationText,
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref
          .read(fulfillmentProvider.notifier)
          .confirmArrival(arrivedCp.id);

      ref
          .read(meetSafetySessionProvider.notifier)
          .completeAfterCustomerArrivalConfirmed();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 已确认到达，服务开始！资金进入部分释放状态。'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    }
  }

  void _handleConfirmMeetup(BuildContext context, FulfillmentState state) {
    final exec = state.execution;
    if (exec == null) return;
    ref.read(meetSafetySessionProvider.notifier).activateMeetupGuard(
          bookingId: exec.bookingId,
          counterpartyName: exec.providerName,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已进入 PureGet 约见守护：返回首页可查看顶栏与 SOS'),
        backgroundColor: Color(0xFFFF6D00),
        duration: Duration(seconds: 3),
      ),
    );
  }

  // ────────────────────────────────────────
  // 显示到达相机核验底单
  // ────────────────────────────────────────

  void _showArrivalCamera(
      BuildContext context, ServiceExecution exec, String locationText) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (_) => ArrivalVerifySheet(
        bookingId: exec.bookingId,
        locationText: locationText,
        onSubmit: (File photo) async {
          ref.read(fulfillmentProvider.notifier).setPendingArrivalPhoto(
                photo,
                locationText,
              );
          await ref
              .read(fulfillmentProvider.notifier)
              .submitArrivalPhoto(lat: null, lng: null);
        },
      ),
    );
  }

  // 获取位置文字（生产环境接入 geolocator）
  Future<String> _resolveLocationText() async {
    // 生产：final pos = await Geolocator.getCurrentPosition();
    // 生产：reverse geocoding → 文字地址
    return '北京市朝阳区 · 三里屯太古里附近'; // mock
  }

  void _showShareCard(BuildContext context, ServiceExecution exec) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '行程分享',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 24),
            TripShareCard(execution: exec),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Hero Banner：顶部封面 + 毛玻璃订单信息
// ══════════════════════════════════════════════════════════════

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.execution});
  final ServiceExecution execution;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 背景渐变（无封面图时的降级方案）
        Container(
          height: 240,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                execution.currentNode.color.withOpacity(0.8),
                AppTheme.primary.withOpacity(0.6),
              ],
            ),
          ),
        ),

        // 顶部安全区占位
        SizedBox(height: MediaQuery.of(context).padding.top + 60),

        // 订单信息毛玻璃卡片
        Positioned(
          bottom: 0,
          left: 16,
          right: 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: execution.providerAvatar.isNotEmpty
                          ? NetworkImage(execution.providerAvatar)
                          : null,
                      backgroundColor: Colors.white24,
                      child: execution.providerAvatar.isEmpty
                          ? Text(
                              execution.providerName.substring(0, 1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            execution.serviceName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${execution.providerName} · '
                            '${execution.startTime}~${execution.endTime}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: execution.currentNode.color.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: execution.currentNode.color.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        execution.currentNode.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // 让卡片露出底部
        const SizedBox(height: 240),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 资金托管状态卡片
// ══════════════════════════════════════════════════════════════

class _EscrowStatusCard extends StatelessWidget {
  const _EscrowStatusCard({required this.execution});
  final ServiceExecution execution;

  @override
  Widget build(BuildContext context) {
    final isPartialReleased = execution.arrivalConfirmed;

    return _SectionCard(
      title: '资金托管',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isPartialReleased
              ? AppTheme.success.withOpacity(0.06)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPartialReleased
                ? AppTheme.success.withOpacity(0.3)
                : AppTheme.divider,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  isPartialReleased
                      ? Icons.lock_open_rounded
                      : Icons.lock_rounded,
                  size: 20,
                  color: isPartialReleased ? AppTheme.success : AppTheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPartialReleased ? '资金部分释放' : '资金托管中',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isPartialReleased ? AppTheme.success : AppTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPartialReleased
                            ? '买家已确认到达，服务完成后全额打款给达人'
                            : '买家确认到达后资金自动部分释放，保障双方权益',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '¥${execution.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isPartialReleased ? AppTheme.success : AppTheme.onSurface,
                  ),
                ),
              ],
            ),

            // 进度条
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: isPartialReleased ? 0.5 : 0.1,
                backgroundColor: AppTheme.divider,
                valueColor: AlwaysStoppedAnimation(
                  isPartialReleased ? AppTheme.success : AppTheme.primary,
                ),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('支付完成', style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant)),
                Text(
                  isPartialReleased ? '到达确认' : '待确认',
                  style: TextStyle(
                    fontSize: 10,
                    color: isPartialReleased ? AppTheme.success : AppTheme.onSurfaceVariant,
                    fontWeight: isPartialReleased ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                const Text('服务完成', style: TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 底部操作栏
// ══════════════════════════════════════════════════════════════

class _ActionBar extends ConsumerWidget {
  const _ActionBar({
    required this.state,
    required this.isProvider,
    required this.onAction,
    required this.onCustomerConfirm,
    required this.onConfirmMeetup,
    this.onShareTrip,
  });

  final FulfillmentState state;
  final bool isProvider;
  final VoidCallback onAction;
  final VoidCallback onCustomerConfirm;
  final VoidCallback onConfirmMeetup;
  final VoidCallback? onShareTrip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exec = state.execution;
    if (exec == null) return const SizedBox.shrink();

    final node = exec.currentNode;
    final isFinished = node == ServiceNode.finished;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            border: Border(top: BorderSide(color: AppTheme.divider)),
          ),
          padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12,
          ),
          child: isProvider
              ? _providerActions(context, node, isFinished)
              : _customerActions(context, ref, exec, state),
        ),
      ),
    );
  }

  Widget _providerActions(BuildContext context, ServiceNode node, bool isFinished) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isFinished || state.isSubmitting ? null : onAction,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFinished ? AppTheme.success : node.color,
          disabledBackgroundColor: isFinished
              ? AppTheme.success.withOpacity(0.6)
              : AppTheme.divider,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: state.isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(node.emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Text(
                    isFinished ? '服务已完成' : node.actionLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (node == ServiceNode.arrived) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '拍照核验',
                        style: TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _customerActions(
    BuildContext context,
    WidgetRef ref,
    ServiceExecution exec,
    FulfillmentState state,
  ) {
    final arrivedCp = exec.checkpointFor(ServiceNode.arrived);
    final canConfirmArrival =
        arrivedCp != null && !arrivedCp.confirmedByCustomer;

    final meet = ref.watch(meetSafetySessionProvider);
    final meetForThisBooking =
        meet.active && meet.bookingId == exec.bookingId;
    final canConfirmMeetup = (exec.currentNode == ServiceNode.departed ||
            exec.currentNode == ServiceNode.aboutToDepart) &&
        !meetForThisBooking;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canConfirmMeetup) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isSubmitting ? null : onConfirmMeetup,
              icon: const Icon(Icons.how_to_reg_rounded, size: 20),
              label: const Text('确认见面'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3D00),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Row(
          children: [
            if (canConfirmArrival)
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: onCustomerConfirm,
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      size: 18),
                  label: const Text('确认达人已到达'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              )
            else
              Expanded(
                flex: 3,
                child: OutlinedButton.icon(
                  onPressed: () => _openChat(context),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('联系达人'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: OutlinedButton.icon(
                onPressed: onShareTrip,
                icon: const Icon(Icons.share_rounded, size: 16),
                label: const Text('分享行程'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _openChat(BuildContext context) {
    // 跳转聊天页面（接入 GoRouter）
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('跳转到聊天页面')),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 通用小组件
// ══════════════════════════════════════════════════════════════

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SafetyTipRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.onSurfaceVariant),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            '通话通过隐私号转接，双方真实号码不会泄露。通话记录保留14天用于安全保障。',
            style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 16),
          Text('加载中...', style: TextStyle(color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({this.error});
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
          const SizedBox(height: 12),
          Text(
            error ?? '加载失败',
            style: const TextStyle(color: AppTheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SubmittingOverlay extends StatelessWidget {
  const _SubmittingOverlay({required this.progress});
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '上传核验照片...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppTheme.divider,
                  color: AppTheme.primary,
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(progress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 确认到达对话框 ──
class _ConfirmArrivalDialog extends StatelessWidget {
  const _ConfirmArrivalDialog({this.photoUrl, this.locationText});
  final String? photoUrl;
  final String? locationText;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.location_on_rounded, color: AppTheme.warning, size: 22),
          SizedBox(width: 8),
          Text('确认达人已到达？', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (photoUrl != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                photoUrl!,
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 140,
                  color: AppTheme.divider,
                  child: const Center(child: Icon(Icons.image_not_supported_outlined)),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (locationText != null)
            Row(
              children: [
                const Icon(Icons.location_on_rounded, size: 14, color: AppTheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    locationText!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          const Text(
            '确认后将触发资金部分释放，请仔细查看核验照片。',
            style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('再看看'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.success,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('确认到达', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 安全守护中心卡片（可展开/折叠）
// ══════════════════════════════════════════════════════════════

class _SafetyHubCard extends ConsumerWidget {
  const _SafetyHubCard({
    required this.bookingId,
    required this.isProvider,
    required this.isExpanded,
    required this.isActive,
    required this.onToggle,
  });

  final String bookingId;
  final bool isProvider;
  final bool isExpanded;
  final bool isActive;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // 折叠/展开 Header
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isActive
                      ? [const Color(0xFF0D2137), const Color(0xFF1A3A5C)]
                      : [AppTheme.surfaceVariant, AppTheme.surfaceVariant],
                ),
                borderRadius: BorderRadius.vertical(
                  top: const Radius.circular(18),
                  bottom: isExpanded ? Radius.zero : const Radius.circular(18),
                ),
                border: Border.all(
                  color: isActive
                      ? AppTheme.primary.withValues(alpha: 0.4)
                      : AppTheme.divider,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isActive ? Icons.shield_rounded : Icons.shield_outlined,
                    color: isActive ? AppTheme.primary : AppTheme.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isActive ? '🛡️ 安全守护中心（守护中）' : '安全守护中心',
                      style: TextStyle(
                        color: isActive ? Colors.white : AppTheme.onSurface,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isActive)
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                        color: AppTheme.success, shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: isActive ? Colors.white : AppTheme.onSurfaceVariant,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // 展开内容
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isActive
                      ? AppTheme.primary.withValues(alpha: 0.3)
                      : AppTheme.divider,
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18),
                ),
              ),
              child: SafetyControlPanel(
                bookingId:   bookingId,
                isProvider:  isProvider,
                partnerName: isProvider ? '买家' : '达人',
              ),
            ),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 350),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}
