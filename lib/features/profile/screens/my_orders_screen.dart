import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/orders_stream_provider.dart';

// ══════════════════════════════════════════════════════════════
// MyOrdersScreen：我的订单列表
//
// 数据：StreamProvider 实时订阅 Supabase bookings 表
// 状态：支付成功后立即出现，无需手动刷新
// ══════════════════════════════════════════════════════════════

class MyOrdersScreen extends ConsumerWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(myOrdersStreamProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('我的订单'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.onSurface,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.divider),
        ),
        actions: [
          // 实时状态指示器
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: _RealtimeDot(),
          ),
        ],
      ),
      body: ordersAsync.when(
        loading: () => _buildSkeletons(),
        error: (e, _) => _ErrorView(onRetry: () => ref.invalidate(myOrdersStreamProvider)),
        data: (orders) {
          if (orders.isEmpty) return _EmptyView();
          return _OrderList(orders: orders);
        },
      ),
    );
  }

  Widget _buildSkeletons() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({required this.orders});
  final List<OrderSummary> orders;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      itemCount: orders.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _OrderCard(order: orders[i]),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/order/${order.id}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶行
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.serviceName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(order: order),
              ],
            ),
            const SizedBox(height: 8),

            // 达人 + 时间
            Row(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 13, color: AppTheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  order.providerName,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.schedule_rounded,
                    size: 13, color: AppTheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${order.bookingDate}  ${order.startTime}-${order.endTime}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: AppTheme.divider, height: 1),
            ),

            // 底行
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '¥${order.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.accent,
                  ),
                ),
                Row(
                  children: [
                    // 已支付 → 出示二维码
                    if (order.isPaid)
                      _ActionBtn(
                        label: '🔑 出示核销码',
                        color: AppTheme.primary,
                        onTap: () => context.push('/order/${order.id}'),
                      ),
                    // 待支付 → 立即支付
                    if (order.isPending) ...[
                      const SizedBox(width: 8),
                      _ActionBtn(
                        label: '立即支付',
                        color: AppTheme.accent,
                        onTap: () => context.push(
                          '/payment/${order.id}',
                          extra: {
                            'amount':       order.amount,
                            'serviceName':  order.serviceName,
                            'providerName': order.providerName,
                          },
                        ),
                      ),
                    ],
                    // 已完成 → 写评价
                    if (order.isCompleted)
                      _ActionBtn(
                        label: '⭐ 写评价',
                        color: const Color(0xFFF59E0B),
                        onTap: () => context.push(
                          '/review/${order.id}',
                          extra: {
                            'providerName':  order.providerName,
                            'providerAvatar': order.providerAvatar ?? '',
                            'serviceName':   order.serviceName,
                            'amount':        order.amount,
                          },
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.order});
  final OrderSummary order;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: order.statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: order.statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              color: order.statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            order.statusLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: order.statusColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ── Realtime 状态指示 ──
class _RealtimeDot extends StatefulWidget {
  @override
  State<_RealtimeDot> createState() => _RealtimeDotState();
}

class _RealtimeDotState extends State<_RealtimeDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: Color.lerp(
                  AppTheme.success, AppTheme.success.withOpacity(0.3), _ctrl.value),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          const Text('实时同步',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
              )),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📋', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text(
            '还没有订单',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '去发现页找一位达人预约吧～',
            style: TextStyle(color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/discover'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('去发现', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppTheme.onSurfaceVariant),
          const SizedBox(height: 12),
          const Text('加载失败', style: TextStyle(color: AppTheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('重试')),
        ],
      ),
    );
  }
}
