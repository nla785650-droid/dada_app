import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/payment_provider.dart';

// ══════════════════════════════════════════════════════════════
// PaymentMockScreen：Apple Pay 风格支付确认页
//
// 视觉设计：
//   · 底部 Sheet 样式（高度 60% 屏幕）
//   · 渐变按钮 + 金属质感卡号展示
//   · 支付中：Lottie 风格 Loading（纯 Flutter 动画）
//   · 支付成功：圆圈展开动效 + Hero 跳转订单详情
// ══════════════════════════════════════════════════════════════

class PaymentMockScreen extends ConsumerStatefulWidget {
  const PaymentMockScreen({
    super.key,
    required this.bookingId,
    required this.amount,
    required this.serviceName,
    required this.providerName,
    this.slotId,
    this.postId,
    this.providerId,
  });

  final String bookingId;
  final double amount;
  final String serviceName;
  final String providerName;
  // 时间轴预约新流程：若有 slotId 则调用 create_booking_with_lock
  final String? slotId;
  final String? postId;
  final String? providerId;

  @override
  ConsumerState<PaymentMockScreen> createState() => _PaymentMockScreenState();
}

class _PaymentMockScreenState extends ConsumerState<PaymentMockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _successCtrl;
  late Animation<double> _successScale;
  late Animation<double> _successOpacity;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _successScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
    );
    _successOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _onPay() async {
    HapticFeedback.mediumImpact();
    bool success;

    // 时间轴预约新流程（有 slotId）→ 原子创建订单+锁档期
    if (widget.slotId != null) {
      success = await ref.read(paymentProvider.notifier).payWithSlot(
        slotId:     widget.slotId!,
        postId:     widget.postId ?? 'unknown',
        providerId: widget.providerId ?? 'unknown',
        amount:     widget.amount,
      );
    } else {
      // 旧流程：更新已有 booking 状态
      success = await ref
          .read(paymentProvider.notifier)
          .pay(widget.bookingId, widget.amount);
    }

    if (success && mounted) {
      _successCtrl.forward();
      HapticFeedback.heavyImpact();

      // 2 秒后跳转订单详情（优先使用 RPC 返回的新 bookingId）
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted) {
        final state = ref.read(paymentProvider);
        final targetId = state.paidBookingId ?? widget.bookingId;
        context.go('/order/$targetId');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentProvider);
    final mq = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black54,
      body: GestureDetector(
        onTap: () {
          if (!state.isLoading && !state.isSuccess) context.pop();
        },
        child: Stack(
          children: [
            // 背景毛玻璃
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),

            // 底部面板
            Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: () {}, // 阻止穿透
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    minHeight: mq.size.height * 0.52,
                    maxHeight: mq.size.height * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: state.isSuccess
                      ? _buildSuccessView(state)
                      : _buildPaymentForm(state, mq),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 支付表单 ──
  Widget _buildPaymentForm(PaymentState state, MediaQueryData mq) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 8, 24, mq.padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖拽把手
          Center(
            child: Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 搭哒 Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                child: const Text(
                  '搭哒支付',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.verified_rounded, color: AppTheme.primary, size: 18),
            ],
          ),

          const SizedBox(height: 32),

          // 金额展示
          Hero(
            tag: 'payment_amount_${widget.bookingId}',
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  const Text(
                    '待支付金额',
                    style: TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¥${widget.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 44,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 订单信息卡
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                _InfoRow(label: '服务项目', value: widget.serviceName),
                const SizedBox(height: 10),
                _InfoRow(label: '服务达人', value: widget.providerName),
                const SizedBox(height: 10),
                _InfoRow(label: '平台手续费', value: '已包含（10%）'),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: Colors.white12),
                ),
                _InfoRow(
                  label: '到账金额',
                  value: '¥${(widget.amount * 0.9).toStringAsFixed(2)}',
                  valueColor: AppTheme.success,
                ),
              ],
            ),
          ),

          // 虚拟卡
          const SizedBox(height: 16),
          _MockPaymentCard(),

          const SizedBox(height: 28),

          // 确认支付按钮
          SizedBox(
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: state.isLoading
                  ? _LoadingButton()
                  : _PayButton(onTap: _onPay),
            ),
          ),

          if (state.error != null) ...[
            const SizedBox(height: 12),
            Text(
              state.error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],

          const SizedBox(height: 12),
          const Text(
            '资金由搭哒平台托管，服务完成后自动结算',
            style: TextStyle(color: Colors.white30, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ── 支付成功视图 ──
  Widget _buildSuccessView(PaymentState state) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 32, 24, MediaQuery.of(context).padding.bottom + 32,
      ),
      child: AnimatedBuilder(
        animation: _successCtrl,
        builder: (_, __) => Opacity(
          opacity: _successOpacity.value,
          child: Transform.scale(
            scale: _successScale.value,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 成功圆圈
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.success,
                        AppTheme.success.withOpacity(0.4),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.success.withOpacity(0.4),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '支付成功！',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '¥${widget.amount.toStringAsFixed(2)} 已存入平台托管',
                  style: const TextStyle(color: Colors.white60, fontSize: 14),
                ),
                const SizedBox(height: 24),
                if (state.verificationCode != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '核销码已生成',
                          style: TextStyle(color: Colors.white60, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.verificationCode!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '正在跳转到订单详情...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 模拟支付卡 ──
class _MockPaymentCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2A3E), Color(0xFF1A1A2E)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '**** **** **** 8888',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '搭哒模拟支付 · 演示用途',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(
            Icons.radio_button_checked_rounded,
            color: Colors.white.withOpacity(0.3),
            size: 20,
          ),
        ],
      ),
    );
  }
}

class _PayButton extends StatelessWidget {
  const _PayButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primary, AppTheme.accent],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.face_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              '面容 ID 确认支付',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 12),
          Text(
            '支付处理中...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
