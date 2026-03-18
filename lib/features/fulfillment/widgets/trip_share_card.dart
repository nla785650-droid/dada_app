import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/service_execution_model.dart';

// ══════════════════════════════════════════════════════════════
// TripShareCard：拍立得风格行程状态分享卡
//
// 视觉设计：
//   · 白色卡片 + 底部留白（拍立得特征）
//   · 内容区：达人信息 + 当前节点状态 + 服务时间 + 订单号
//   · 节点状态条：彩色渐变进度展示
//   · 右下角防伪印章（圆形盖章效果）
//   · 长按 / 点击"生成图片"可截图分享
// ══════════════════════════════════════════════════════════════

class TripShareCard extends StatefulWidget {
  const TripShareCard({
    super.key,
    required this.execution,
  });

  final ServiceExecution execution;

  @override
  State<TripShareCard> createState() => _TripShareCardState();
}

class _TripShareCardState extends State<TripShareCard>
    with SingleTickerProviderStateMixin {
  final _repaintKey = GlobalKey();
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _shimmer = CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  String get _shortBookingId =>
      '#${widget.execution.bookingId.substring(0, 8).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── 卡片主体（拍立得风格）──
          RepaintBoundary(
            key: _repaintKey,
            child: _PolaroidCard(
              execution: widget.execution,
              shimmer: _shimmer,
              shortBookingId: _shortBookingId,
            ),
          ),

          const SizedBox(height: 24),

          // ── 操作按钮组 ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(
                icon: Icons.copy_rounded,
                label: '复制订单号',
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _shortBookingId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('订单号已复制'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
              const SizedBox(width: 16),
              _ActionButton(
                icon: Icons.ios_share_rounded,
                label: '分享行程',
                isPrimary: true,
                onTap: () => _shareCard(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareCard(BuildContext context) async {
    // 截图逻辑（需要 share_plus 插件实现真实分享）
    // 此处仅做 UI 反馈，实际分享由调用者接入 share_plus
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('生成分享图片中...（接入 share_plus 插件后可真实分享）'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// ── 拍立得卡片本体 ──
class _PolaroidCard extends StatelessWidget {
  const _PolaroidCard({
    required this.execution,
    required this.shimmer,
    required this.shortBookingId,
  });

  final ServiceExecution execution;
  final Animation<double> shimmer;
  final String shortBookingId;

  @override
  Widget build(BuildContext context) {
    final nodes = ServiceNode.values;
    final currentIdx = nodes.indexOf(execution.currentNode);

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 照片区（渐变色模拟现场感）──
          _PhotoArea(execution: execution, shimmer: shimmer),

          // ── 信息区 ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 达人信息行
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: execution.providerAvatar.isNotEmpty
                          ? NetworkImage(execution.providerAvatar)
                          : null,
                      backgroundColor: AppTheme.surfaceVariant,
                      child: execution.providerAvatar.isEmpty
                          ? Text(execution.providerName.substring(0, 1),
                              style: const TextStyle(fontSize: 14))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          execution.providerName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          execution.serviceName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // 防伪印章
                    _SecurityStamp(),
                  ],
                ),

                const SizedBox(height: 12),

                // 节点进度条
                _NodeProgressBar(
                  nodes: nodes,
                  currentIdx: currentIdx,
                ),

                const SizedBox(height: 8),

                // 当前状态文字
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: execution.currentNode.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: execution.currentNode.color.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        execution.currentNode.emoji,
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        execution.currentNode.description,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: execution.currentNode.color,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 时间和订单号
                Row(
                  children: [
                    Text(
                      '${DateFormat('M月d日').format(execution.bookingDate)} '
                      '${execution.startTime}~${execution.endTime}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      shortBookingId,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.onSurfaceVariant,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 拍立得底部留白（特征性白边）
          Container(height: 32),
        ],
      ),
    );
  }
}

// ── 照片区：渐变色背景 + 动态光晕 ──
class _PhotoArea extends StatelessWidget {
  const _PhotoArea({required this.execution, required this.shimmer});

  final ServiceExecution execution;
  final Animation<double> shimmer;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      child: SizedBox(
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 渐变背景（模拟现场氛围）
            AnimatedBuilder(
              animation: shimmer,
              builder: (_, __) {
                return Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        execution.currentNode.color.withOpacity(0.7),
                        AppTheme.accent.withOpacity(0.6),
                        execution.currentNode.color.withOpacity(0.4),
                      ],
                      stops: [
                        0.0,
                        shimmer.value,
                        1.0,
                      ],
                    ),
                  ),
                );
              },
            ),

            // 中央大图标
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    execution.currentNode.emoji,
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    execution.currentNode.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),

            // 搭哒 Logo 水印（右上角）
            Positioned(
              top: 10,
              right: 12,
              child: Text(
                '搭哒',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 节点进度条 ──
class _NodeProgressBar extends StatelessWidget {
  const _NodeProgressBar({required this.nodes, required this.currentIdx});

  final List<ServiceNode> nodes;
  final int currentIdx;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(nodes.length, (i) {
        final isCompleted = i <= currentIdx;
        final isCurrent = i == currentIdx;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: isCurrent ? 4 : 3,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? nodes[i].color
                        : AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i < nodes.length - 1) const SizedBox(width: 2),
            ],
          ),
        );
      }),
    );
  }
}

// ── 防伪印章 ──
class _SecurityStamp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.3,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primary.withOpacity(0.6),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '搭哒',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: AppTheme.primary.withOpacity(0.7),
                letterSpacing: 1,
              ),
            ),
            Text(
              'VERIFIED',
              style: TextStyle(
                fontSize: 6,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary.withOpacity(0.7),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 操作按钮 ──
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary ? null : Border.all(color: AppTheme.divider),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isPrimary ? Colors.white : AppTheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isPrimary ? Colors.white : AppTheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
