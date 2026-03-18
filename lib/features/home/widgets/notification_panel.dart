import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// NotificationPanel — 消息通知面板（Bottom Sheet）
//
// 通知类型：
//   · order   — 订单动态（新预约、核销、评价）
//   · like    — 有人喜欢了你
//   · system  — 系统公告
//   · review  — 收到评价
//
// 交互：
//   · 点击单条 → 跳转对应页面
//   · 左滑 / 点击删除 → 移除单条
//   · "全部已读" → 清除 badge
//   · 空状态插画
// ══════════════════════════════════════════════════════════════

// ── 通知数据模型 ──
class NotificationItem {
  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.time,
    this.isRead   = false,
    this.avatarUrl,
    this.route,
  });

  final String  id;
  final String  type;       // 'order' | 'like' | 'system' | 'review'
  final String  title;
  final String  body;
  final DateTime time;
  bool          isRead;
  final String? avatarUrl;
  final String? route;
}

// ── Mock 通知数据 ──
List<NotificationItem> _buildMockNotifications() => [
  NotificationItem(
    id:    'n1',
    type:  'order',
    title: '新预约订单 🎉',
    body:  '买家「凉月」预约了你的「汉服摄影 · 2小时」，请及时确认',
    time:  DateTime.now().subtract(const Duration(minutes: 5)),
    route: '/orders',
  ),
  NotificationItem(
    id:    'n2',
    type:  'like',
    title: '有人喜欢了你 ❤️',
    body:  '用户「星辰」在划一划中右滑了你，快去看看吧',
    time:  DateTime.now().subtract(const Duration(minutes: 23)),
    isRead: false,
  ),
  NotificationItem(
    id:    'n3',
    type:  'review',
    title: '收到新评价 ⭐',
    body:  '「摄影技术一流，构图很有想法，下次还会找你！」—— 匿名用户',
    time:  DateTime.now().subtract(const Duration(hours: 2)),
    isRead: false,
  ),
  NotificationItem(
    id:    'n4',
    type:  'order',
    title: '订单已核销 ✅',
    body:  '与买家「小樱」的「Cos委托」已完成核销，记得提交服务总结哦',
    time:  DateTime.now().subtract(const Duration(hours: 5)),
    isRead: true,
    route: '/orders',
  ),
  NotificationItem(
    id:    'n5',
    type:  'system',
    title: '平台公告 📢',
    body:  '搭哒 v2.0 正式上线！新增 AI 真人核验、安全守护等功能，点击查看详情',
    time:  DateTime.now().subtract(const Duration(days: 1)),
    isRead: true,
  ),
  NotificationItem(
    id:    'n6',
    type:  'like',
    title: '又有人喜欢了你 ❤️',
    body:  '用户「流光」在划一划中右滑了你',
    time:  DateTime.now().subtract(const Duration(days: 2)),
    isRead: true,
  ),
];

// ── 展示入口 ──
class NotificationPanel extends StatefulWidget {
  const NotificationPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context:           context,
      isScrollControlled: true,
      backgroundColor:   Colors.transparent,
      useRootNavigator:  true,
      builder:           (_) => const NotificationPanel(),
    );
  }

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  late final List<NotificationItem> _items = _buildMockNotifications();

  int get _unreadCount => _items.where((n) => !n.isRead).length;

  void _markAllRead() {
    HapticFeedback.lightImpact();
    setState(() {
      for (final item in _items) {
        item.isRead = true;
      }
    });
  }

  void _removeItem(String id) {
    setState(() => _items.removeWhere((n) => n.id == id));
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.78,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // ── 拖拽把手 ──
          _buildHandle(),

          // ── Header ──
          _buildHeader(),

          const Divider(height: 0.5, color: AppTheme.divider),

          // ── 通知列表 ──
          Expanded(
            child: _items.isEmpty
                ? _EmptyNotification()
                : ListView.separated(
                    padding: EdgeInsets.only(
                        bottom: mq.padding.bottom + 16),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 0.5, indent: 68,
                            color: AppTheme.divider),
                    itemBuilder: (context, i) => _NotificationTile(
                      item:     _items[i],
                      onTap:    () => _onTap(_items[i]),
                      onDelete: () => _removeItem(_items[i].id),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 36, height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Row(
        children: [
          const Text(
            '消息通知',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface,
            ),
          ),
          if (_unreadCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_unreadCount',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const Spacer(),
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text(
                '全部已读',
                style: TextStyle(fontSize: 13, color: AppTheme.primary),
              ),
            ),
        ],
      ),
    );
  }

  void _onTap(NotificationItem item) {
    HapticFeedback.lightImpact();
    setState(() => item.isRead = true);
    // 实际项目中通过 GoRouter 跳转
    // if (item.route != null) context.push(item.route!);
    Navigator.of(context).pop();
  }
}

// ── 单条通知卡片（支持左滑删除）──
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  final NotificationItem item;
  final VoidCallback      onTap;
  final VoidCallback      onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction:        DismissDirection.endToStart,
      onDismissed:      (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppTheme.error,
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图标
              _TypeIcon(type: item.type, isRead: item.isRead),
              const SizedBox(width: 12),
              // 内容
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                              color: AppTheme.onSurface,
                            ),
                          ),
                        ),
                        Text(
                          _formatTime(item.time),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1)  return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours   < 24) return '${diff.inHours}小时前';
    if (diff.inDays    < 7)  return '${diff.inDays}天前';
    return '${t.month}/${t.day}';
  }
}

// ── 类型图标 ──
class _TypeIcon extends StatelessWidget {
  const _TypeIcon({required this.type, required this.isRead});

  final String type;
  final bool   isRead;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      'order'  => (Icons.receipt_long_rounded,       AppTheme.primary),
      'like'   => (Icons.favorite_rounded,            AppTheme.accent),
      'review' => (Icons.star_rounded,                const Color(0xFFF59E0B)),
      'system' => (Icons.campaign_rounded,            const Color(0xFF3498DB)),
      _        => (Icons.notifications_rounded,       AppTheme.onSurfaceVariant),
    };

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        // 未读红点
        if (!isRead)
          Positioned(
            top: -2, right: -2,
            child: Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}

// ── 空状态 ──
class _EmptyNotification extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔔', style: TextStyle(fontSize: 56)),
          SizedBox(height: 12),
          Text(
            '暂无消息通知',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '当有新订单、喜欢或评价时，会在这里通知你',
            style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
