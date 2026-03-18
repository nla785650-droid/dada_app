import 'package:flutter/material.dart';

import '../../../data/models/service_execution_model.dart';
import '../../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// ServiceTimeline：节点化履约进度条
//
// 视觉设计：
//   · 垂直线条连接各节点，iOS 极简风格
//   · 已完成节点：实心圆 + 对钩 + 颜色高亮
//   · 当前节点：脉冲波纹动画 + 渐变描边
//   · 未来节点：空心圆 + 灰色哑光
//   · 每个节点右侧显示：标签、时间戳（如有）、位置文字（如有）
// ══════════════════════════════════════════════════════════════

class ServiceTimeline extends StatefulWidget {
  const ServiceTimeline({
    super.key,
    required this.currentNode,
    required this.checkpoints,
    this.isProvider = false,
    this.onNodeTap,
  });

  final ServiceNode currentNode;
  final List<BookingCheckpoint> checkpoints;
  final bool isProvider;
  final void Function(ServiceNode node)? onNodeTap;

  @override
  State<ServiceTimeline> createState() => _ServiceTimelineState();
}

class _ServiceTimelineState extends State<ServiceTimeline>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _pulseScale = Tween<double>(begin: 1.0, end: 2.2).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  BookingCheckpoint? _checkpointFor(ServiceNode node) {
    try {
      return widget.checkpoints.firstWhere((c) => c.node == node);
    } catch (_) {
      return null;
    }
  }

  bool _isCompleted(ServiceNode node) =>
      widget.checkpoints.any((c) => c.node == node);

  bool _isCurrent(ServiceNode node) => node == widget.currentNode;

  @override
  Widget build(BuildContext context) {
    final nodes = ServiceNode.values;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: List.generate(nodes.length, (i) {
          final node = nodes[i];
          final isLast = i == nodes.length - 1;
          return _TimelineRow(
            node: node,
            checkpoint: _checkpointFor(node),
            isCompleted: _isCompleted(node),
            isCurrent: _isCurrent(node),
            isLast: isLast,
            pulseScale: _pulseScale,
            pulseOpacity: _pulseOpacity,
            onTap: widget.onNodeTap != null ? () => widget.onNodeTap!(node) : null,
          );
        }),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.node,
    required this.checkpoint,
    required this.isCompleted,
    required this.isCurrent,
    required this.isLast,
    required this.pulseScale,
    required this.pulseOpacity,
    this.onTap,
  });

  final ServiceNode node;
  final BookingCheckpoint? checkpoint;
  final bool isCompleted;
  final bool isCurrent;
  final bool isLast;
  final Animation<double> pulseScale;
  final Animation<double> pulseOpacity;
  final VoidCallback? onTap;

  static const _nodeSize = 32.0;
  static const _lineWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 左侧：节点 + 连接线 ──
          SizedBox(
            width: _nodeSize + 8,
            child: Column(
              children: [
                _buildNode(),
                if (!isLast) _buildLine(),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // ── 右侧：内容区 ──
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24, top: 4),
              child: GestureDetector(
                onTap: isCurrent || isCompleted ? onTap : null,
                child: _buildContent(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode() {
    final color = isCompleted || isCurrent
        ? node.color
        : AppTheme.divider;

    return SizedBox(
      width: _nodeSize,
      height: _nodeSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 脉冲波纹（仅当前节点显示）
          if (isCurrent)
            AnimatedBuilder(
              animation: pulseScale,
              builder: (_, __) => Opacity(
                opacity: pulseOpacity.value,
                child: Transform.scale(
                  scale: pulseScale.value,
                  child: Container(
                    width: _nodeSize,
                    height: _nodeSize,
                    decoration: BoxDecoration(
                      color: node.color.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),

          // 节点圆圈
          Container(
            width: _nodeSize,
            height: _nodeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCompleted ? color : Colors.white,
              border: Border.all(
                color: color,
                width: isCurrent ? 2.5 : _lineWidth,
              ),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: node.color.withOpacity(0.35),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
              gradient: isCurrent
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        node.color.withOpacity(0.15),
                        node.color.withOpacity(0.05),
                      ],
                    )
                  : null,
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : Text(
                      node.emoji,
                      style: const TextStyle(fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLine() {
    final isNextActive = isCompleted; // 已完成节点后的线高亮

    return Expanded(
      child: Center(
        child: Container(
          width: _lineWidth,
          decoration: BoxDecoration(
            gradient: isNextActive
                ? LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [node.color, node.color.withOpacity(0.3)],
                  )
                : null,
            color: isNextActive ? null : AppTheme.divider,
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final textColor = isCompleted || isCurrent
        ? AppTheme.onSurface
        : AppTheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 节点标签行
        Row(
          children: [
            Text(
              node.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (isCurrent) ...[
              const SizedBox(width: 8),
              _CurrentBadge(color: node.color),
            ],
            if (isCompleted && checkpoint?.isVerifiedShot == true) ...[
              const SizedBox(width: 8),
              _VerifiedBadge(),
            ],
          ],
        ),

        const SizedBox(height: 2),

        // 描述文字
        Text(
          isCompleted
              ? (checkpoint?.locationText ?? node.description)
              : isCurrent
                  ? node.description
                  : node.description,
          style: TextStyle(
            fontSize: 12,
            color: AppTheme.onSurfaceVariant,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // 时间戳
        if (checkpoint != null) ...[
          const SizedBox(height: 2),
          Text(
            _formatTime(checkpoint!.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],

        // 到达节点：显示核验照缩略图
        if (checkpoint?.photoUrl != null &&
            checkpoint!.node == ServiceNode.arrived) ...[
          const SizedBox(height: 8),
          _ArrivalPhotoThumbnail(
            photoUrl: checkpoint!.photoUrl!,
            isConfirmed: checkpoint!.confirmedByCustomer,
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} $h:$m';
  }
}

class _CurrentBadge extends StatelessWidget {
  const _CurrentBadge({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        '进行中',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF39C12).withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_rounded, size: 10, color: Color(0xFFF39C12)),
          SizedBox(width: 2),
          Text(
            '已核验',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF39C12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrivalPhotoThumbnail extends StatelessWidget {
  const _ArrivalPhotoThumbnail({
    required this.photoUrl,
    required this.isConfirmed,
  });

  final String photoUrl;
  final bool isConfirmed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showFullPhoto(context),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              photoUrl,
              width: 80,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 80,
                height: 60,
                color: AppTheme.divider,
                child: const Icon(Icons.image_not_supported_outlined, size: 20),
              ),
            ),
          ),
          if (isConfirmed)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppTheme.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 10, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _showFullPhoto(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(photoUrl, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
