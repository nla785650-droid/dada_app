import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class ChatThread {
  const ChatThread({
    required this.id,
    required this.name,
    this.avatarEmoji = '💬',
    this.avatarUrl,
    required this.lastMessage,
    required this.time,
    this.unread = 0,
  });

  final String id;
  final String name;
  final String avatarEmoji;
  final String? avatarUrl;
  final String lastMessage;
  final String time;
  final int unread;
}

class ChatThreadsNotifier extends StateNotifier<List<ChatThread>> {
  ChatThreadsNotifier() : super(_seed);

  static final List<ChatThread> _seed = [
    const ChatThread(
      id: 'user_sakura',
      name: '小樱',
      avatarEmoji: '🌸',
      lastMessage: '好的，那我们约好了！期待见面～',
      time: '刚刚',
      unread: 2,
    ),
    const ChatThread(
      id: 'user_star',
      name: '星野摄影工作室',
      avatarEmoji: '📸',
      lastMessage: '已收到您的预约，请等待确认',
      time: '10分钟前',
      unread: 0,
    ),
    const ChatThread(
      id: 'user_suzumiya',
      name: '凉宫',
      avatarEmoji: '🎮',
      lastMessage: '今晚几点开始？',
      time: '1小时前',
      unread: 1,
    ),
    const ChatThread(
      id: 'user_ayanami',
      name: '绫波Cos',
      avatarEmoji: '🎭',
      lastMessage: '感谢您的好评！',
      time: '昨天',
      unread: 0,
    ),
  ];

  /// 会话内自己发文字：更新列表预览并置顶。
  void bumpThreadAsUser(String peerId, String preview) {
    final i = state.indexWhere((t) => t.id == peerId);
    if (i < 0) return;
    final t = state[i];
    final filtered = state.where((x) => x.id != peerId).toList();
    state = [
      ChatThread(
        id: t.id,
        name: t.name,
        avatarEmoji: t.avatarEmoji,
        avatarUrl: t.avatarUrl,
        lastMessage: preview,
        time: '刚刚',
        unread: t.unread,
      ),
      ...filtered,
    ];
  }

  /// 对方发来文字（模拟回复）：更新预览；[inForeground] 为 true 时不增加未读。
  void bumpThreadAsPeer(
    String peerId,
    String preview, {
    bool inForeground = false,
  }) {
    final i = state.indexWhere((t) => t.id == peerId);
    if (i < 0) return;
    final t = state[i];
    final filtered = state.where((x) => x.id != peerId).toList();
    final nextUnread =
        inForeground ? 0 : (t.unread + 1).clamp(0, 99);
    state = [
      ChatThread(
        id: t.id,
        name: t.name,
        avatarEmoji: t.avatarEmoji,
        avatarUrl: t.avatarUrl,
        lastMessage: preview,
        time: '刚刚',
        unread: nextUnread,
      ),
      ...filtered,
    ];
  }

  void clearUnread(String peerId) {
    state = [
      for (final t in state)
        t.id == peerId
            ? ChatThread(
                id: t.id,
                name: t.name,
                avatarEmoji: t.avatarEmoji,
                avatarUrl: t.avatarUrl,
                lastMessage: t.lastMessage,
                time: t.time,
                unread: 0,
              )
            : t,
    ];
  }

  void addOrBumpMatchThread({
    required String id,
    required String name,
    String? imageUrl,
  }) {
    final emoji = name.isNotEmpty ? '✨' : '💬';
    final filtered = state.where((t) => t.id != id).toList();
    state = [
      ChatThread(
        id: id,
        name: name,
        avatarEmoji: emoji,
        avatarUrl: imageUrl,
        lastMessage: '你们互相喜欢了对方，打个招呼吧～',
        time: '刚刚',
        unread: 1,
      ),
      ...filtered,
    ];
  }
}

final chatThreadsProvider =
    StateNotifierProvider<ChatThreadsNotifier, List<ChatThread>>(
  (ref) => ChatThreadsNotifier(),
);
