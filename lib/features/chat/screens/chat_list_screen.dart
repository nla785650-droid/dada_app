import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/chat_threads_provider.dart';

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  static const _mockUserId = 'current_user';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(chatThreadsProvider);

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
      body: RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('聊天记录已同步')),
          );
        },
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: threads.length,
          separatorBuilder: (_, __) => const Divider(
            height: 1,
            indent: 76,
            color: AppTheme.divider,
          ),
          itemBuilder: (context, index) {
            final item = threads[index];
            return _ChatTile(
              item: item,
              onTap: () => context.pushNamed(
                'chatDetail',
                pathParameters: {'otherId': item.id},
                extra: {
                  'currentUserId': _mockUserId,
                  'otherUserName': item.name,
                  'otherUserAvatar': item.avatarUrl,
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.item, required this.onTap});

  final ChatThread item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: AppTheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: item.avatarUrl != null && item.avatarUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.avatarUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 120,
                  )
                : Center(
                    child: Text(
                      item.avatarEmoji,
                      style: const TextStyle(fontSize: 24),
                    ),
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
            style: const TextStyle(
                fontSize: 13, color: AppTheme.onSurfaceVariant),
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
        ),
      ),
    );
  }
}
