import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  final _mockChats = const [
    _ChatItem(
      name: '小樱',
      avatar: '🌸',
      lastMessage: '好的，那我们约好了！期待见面～',
      time: '刚刚',
      unread: 2,
    ),
    _ChatItem(
      name: '星野摄影工作室',
      avatar: '📸',
      lastMessage: '已收到您的预约，请等待确认',
      time: '10分钟前',
      unread: 0,
    ),
    _ChatItem(
      name: '凉宫',
      avatar: '🎮',
      lastMessage: '今晚几点开始？',
      time: '1小时前',
      unread: 1,
    ),
    _ChatItem(
      name: '绫波Cos',
      avatar: '🎭',
      lastMessage: '感谢您的好评！',
      time: '昨天',
      unread: 0,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('消息'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _mockChats.length,
        separatorBuilder: (_, __) => const Divider(
          height: 1,
          indent: 76,
          color: AppTheme.divider,
        ),
        itemBuilder: (context, index) {
          return _ChatTile(item: _mockChats[index]);
        },
      ),
    );
  }
}

class _ChatItem {
  const _ChatItem({
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.time,
    required this.unread,
  });

  final String name;
  final String avatar;
  final String lastMessage;
  final String time;
  final int unread;
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.item});

  final _ChatItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(item.avatar, style: const TextStyle(fontSize: 24)),
        ),
      ),
      title: Text(
        item.name,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppTheme.onSurface,
        ),
      ),
      subtitle: Text(
        item.lastMessage,
        style: const TextStyle(fontSize: 13, color: AppTheme.onSurfaceVariant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            item.time,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          if (item.unread > 0) ...[
            const SizedBox(height: 4),
            Container(
              width: 18,
              height: 18,
              decoration: const BoxDecoration(
                color: AppTheme.accent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${item.unread}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      onTap: () {},
    );
  }
}
