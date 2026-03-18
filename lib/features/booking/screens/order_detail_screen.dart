import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/order_provider.dart';

// ══════════════════════════════════════════════════════════════
// OrderDetailScreen：订单详情 + 买家端二维码核销
//
// 核心联动：
//   · Realtime 监听 bookings.status
//   · 当卖家扫码核销后 status → 'completed'，
//     自动弹出"服务完成"提示并跳转评价页
// ══════════════════════════════════════════════════════════════

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _reviewNavigated = false;  // 防止重复跳转

  @override
  Widget build(BuildContext context) {
    final orderAsync = ref.watch(orderProvider(widget.bookingId));

    // 监听状态变化：completed → 跳评价页
    ref.listen<AsyncValue<OrderDetail>>(
      orderProvider(widget.bookingId),
      (prev, next) {
        next.whenData((order) {
          final wasCompleted = prev?.value?.isCompleted ?? false;
          if (order.isCompleted && !wasCompleted && !_reviewNavigated) {
            _reviewNavigated = true;
            _showCompletedAndNavigate(context, order);
          }
        });
      },
    );

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: orderAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppTheme.error),
              const SizedBox(height: 12),
              Text('$e', style: const TextStyle(color: AppTheme.onSurfaceVariant)),
              TextButton(
                onPressed: () => ref.invalidate(orderProvider(widget.bookingId)),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
        data: (order) => _buildContent(context, order),
      ),
    );
  }

  // 卖家扫码成功 → 弹出庆祝 Dialog → 跳转评价
  Future<void> _showCompletedAndNavigate(
      BuildContext context, OrderDetail order) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompletedDialog(
        providerName: order.providerName,
        amount: order.amount,
      ),
    );
    if (mounted) {
      context.go(
        '/review/${order.id}',
        extra: {
          'providerName':  order.providerName,
          'providerAvatar': order.providerAvatar,
          'serviceName':   order.serviceName,
          'amount':        order.amount,
        },
      );
    }
  }

  Widget _buildContent(BuildContext context, OrderDetail order) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── AppBar ──
        SliverAppBar(
          expandedHeight: 180,
          pinned: true,
          backgroundColor: AppTheme.primary,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary, AppTheme.accent],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.serviceName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.bookingDate}  ${order.startTime}~${order.endTime}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: () => ref.invalidate(orderProvider(widget.bookingId)),
            ),
          ],
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 状态 + 金额
                _StatusAmountCard(order: order),
                const SizedBox(height: 12),

                // 二维码区域（仅 paid 状态）
                if (order.isPaid && order.verificationCode != null)
                  _QrCodeCard(
                    verificationCode: order.verificationCode!,
                    isCompleted: order.isCompleted,
                  ),

                // 已完成状态
                if (order.isCompleted)
                  _CompletedCard(verifiedAt: order.verifiedAt),

                // 待支付 CTA
                if (order.isPending)
                  _PayCta(order: order),

                const SizedBox(height: 12),

                // 订单信息
                _OrderInfoCard(order: order),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 状态 + 金额卡
// ══════════════════════════════════════════════════════════════

class _StatusAmountCard extends StatelessWidget {
  const _StatusAmountCard({required this.order});
  final OrderDetail order;

  Color get _statusColor => switch (order.status) {
        'pending'            => AppTheme.warning,
        'paid'               => AppTheme.primary,
        'confirmed'          => AppTheme.primary,
        'partially_released' => AppTheme.success,
        'in_progress'        => AppTheme.success,
        'completed'          => AppTheme.success,
        'cancelled'          => AppTheme.error,
        _                    => AppTheme.onSurfaceVariant,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      order.statusLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _statusColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  order.providerName,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Hero(
            tag: 'payment_amount_${order.id}',
            child: Material(
              color: Colors.transparent,
              child: Text(
                '¥${order.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// QR 码卡片（核心组件）
// ══════════════════════════════════════════════════════════════

class _QrCodeCard extends StatefulWidget {
  const _QrCodeCard({
    required this.verificationCode,
    required this.isCompleted,
  });

  final String verificationCode;
  final bool isCompleted;

  @override
  State<_QrCodeCard> createState() => _QrCodeCardState();
}

class _QrCodeCardState extends State<_QrCodeCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLine;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _scanLine = CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.15),
        ),
      ),
      child: Column(
        children: [
          // 标题
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 8),
              const Text(
                '服务核销码',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // QR 码
          Stack(
            alignment: Alignment.center,
            children: [
              // 圆角容器
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider, width: 1.5),
                ),
                child: QrImageView(
                  data: widget.verificationCode,
                  version: QrVersions.auto,
                  size: 180,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppTheme.primary,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppTheme.onSurface,
                  ),
                ),
              ),

              // 扫描线动画（仅在 active 状态显示）
              if (!widget.isCompleted)
                Positioned(
                  left: 20,
                  right: 20,
                  child: AnimatedBuilder(
                    animation: _scanLine,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, (_scanLine.value * 2 - 1) * 80),
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.transparent,
                              AppTheme.primary.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 已完成遮罩
              if (widget.isCompleted)
                Container(
                  width: 212,
                  height: 212,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppTheme.success,
                        size: 56,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '已核销',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // 核销码文字
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: widget.verificationCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('核销码已复制'), duration: Duration(seconds: 1)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.verificationCode,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.copy_rounded, size: 16, color: AppTheme.onSurfaceVariant),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          if (!widget.isCompleted)
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: AppTheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '见面后请向达人出示此码进行核销，核销完成后资金将自动结算给达人',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 已完成卡
// ══════════════════════════════════════════════════════════════

class _CompletedCard extends StatelessWidget {
  const _CompletedCard({this.verifiedAt});
  final DateTime? verifiedAt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.success.withOpacity(0.08),
            AppTheme.success.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.success.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.success.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.verified_rounded, color: AppTheme.success, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '服务已完成核销',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.success,
                ),
              ),
              if (verifiedAt != null)
                Text(
                  '核销时间：${verifiedAt!.month}/${verifiedAt!.day} '
                  '${verifiedAt!.hour}:${verifiedAt!.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 待支付 CTA
// ══════════════════════════════════════════════════════════════

class _PayCta extends StatelessWidget {
  const _PayCta({required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton(
        onPressed: () {
          context.push(
            '/payment/${order.id}',
            extra: {
              'amount': order.amount,
              'serviceName': order.serviceName,
              'providerName': order.providerName,
            },
          );
        },
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          backgroundColor: AppTheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text(
          '立即支付',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 订单详情信息卡
// ══════════════════════════════════════════════════════════════

class _OrderInfoCard extends StatelessWidget {
  const _OrderInfoCard({required this.order});
  final OrderDetail order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '订单详情',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _InfoRow('订单编号', '#${order.id.substring(0, 8).toUpperCase()}'),
          _InfoRow('服务达人', order.providerName),
          _InfoRow('预约日期', order.bookingDate),
          _InfoRow('服务时段', '${order.startTime} ~ ${order.endTime}'),
          _InfoRow('支付方式', order.paymentMethod ?? '待支付'),
          _InfoRow('创建时间', '${order.createdAt.month}/${order.createdAt.day} '
              '${order.createdAt.hour}:${order.createdAt.minute.toString().padLeft(2, '0')}'),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 服务完成庆祝弹窗（Realtime 检测到 completed 后弹出）
// ══════════════════════════════════════════════════════════════
class _CompletedDialog extends StatefulWidget {
  const _CompletedDialog({
    required this.providerName,
    required this.amount,
  });

  final String providerName;
  final double amount;

  @override
  State<_CompletedDialog> createState() => _CompletedDialogState();
}

class _CompletedDialogState extends State<_CompletedDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_rounded,
                    color: AppTheme.success,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '服务已完成！',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '感谢 ${widget.providerName} 的精彩服务\n¥${widget.amount.toStringAsFixed(0)} 已结算给达人',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      '去写评价 ⭐',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
