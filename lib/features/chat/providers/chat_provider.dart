import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../shared/services/storage_service.dart';
import 'chat_threads_provider.dart';

// ──────────────────────────────────────────
// 扩展消息类型（支持实时拍照）
// ──────────────────────────────────────────

/// 消息的呈现类型
enum MessageType {
  text,         // 普通文字
  photoRequest, // 买家发出的实时拍照请求
  realtimePhoto,// 卖家回复的加水印实时照片（不可撤回）
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.type,
    this.text,
    this.photoUrl,
    this.isRead = false,
    this.isIrrevocable = false,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final MessageType type;
  final String? text;
  final String? photoUrl; // 实时照片 URL（带水印）
  final bool isRead;
  final bool isIrrevocable; // 实时照片不允许撤回
  final DateTime createdAt;

  bool isSentBy(String uid) => senderId == uid;

  /// 模拟从 DB 消息内容字段解析 type
  static MessageType parseType(String content) {
    if (content.startsWith('[PHOTO_REQUEST]')) return MessageType.photoRequest;
    if (content.startsWith('[REALTIME_PHOTO]')) return MessageType.realtimePhoto;
    return MessageType.text;
  }
}

// ──────────────────────────────────────────
// State
// ──────────────────────────────────────────

class ChatState {
  const ChatState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.photoRequestPending = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final bool photoRequestPending; // 是否有待处理的拍照请求
  final String? error;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? photoRequestPending,
    String? error,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
      photoRequestPending: photoRequestPending ?? this.photoRequestPending,
      error: error,
    );
  }
}

// ──────────────────────────────────────────
// Notifier
// ──────────────────────────────────────────

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier({
    required this.ref,
    required this.currentUserId,
    required this.otherUserId,
  }) : super(const ChatState()) {
    ref.onDispose(() => _disposed = true);
    _loadMessages();
    _subscribeRealtime();
  }

  final Ref ref;
  final String currentUserId;
  final String otherUserId;
  bool _disposed = false;
  RealtimeChannel? _channel;
  static const _uuid = Uuid();

  // ── 加载历史消息（模拟） ──
  Future<void> _loadMessages() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 600));

    final mock = <ChatMessage>[
      ChatMessage(
        id: '1',
        senderId: otherUserId,
        receiverId: currentUserId,
        type: MessageType.text,
        text: '你好！看到你的主页了，想预约一次陪拍 📸',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      ChatMessage(
        id: '2',
        senderId: currentUserId,
        receiverId: otherUserId,
        type: MessageType.text,
        text: '好的！请问你想拍什么风格呢？',
        createdAt: DateTime.now().subtract(const Duration(minutes: 28)),
      ),
      ChatMessage(
        id: '3',
        senderId: otherUserId,
        receiverId: currentUserId,
        type: MessageType.text,
        text: '日系清新风，想确认一下你目前的状态',
        createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
      ),
    ];

    state = state.copyWith(messages: mock, isLoading: false);
  }

  // ── Supabase Realtime 订阅 ──
  void _subscribeRealtime() {
    final client = Supabase.instance.client;
    _channel = client
        .channel('chat_${currentUserId}_$otherUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: currentUserId,
          ),
          callback: (payload) {
            final newMsg = payload.newRecord;
            if (newMsg['sender_id'] != otherUserId) return;

            final content = newMsg['content'] as String? ?? '';
            final msgType = ChatMessage.parseType(content);
            final isPending = msgType == MessageType.photoRequest;

            final chatMsg = ChatMessage(
              id: newMsg['id'] as String,
              senderId: newMsg['sender_id'] as String,
              receiverId: newMsg['receiver_id'] as String,
              type: msgType,
              text: msgType == MessageType.text ? content : null,
              photoUrl: msgType == MessageType.realtimePhoto
                  ? content.replaceFirst('[REALTIME_PHOTO]', '').trim()
                  : null,
              isIrrevocable: msgType == MessageType.realtimePhoto,
              createdAt: DateTime.parse(newMsg['created_at'] as String),
            );

            state = state.copyWith(
              messages: [...state.messages, chatMsg],
              photoRequestPending:
                  isPending ? true : state.photoRequestPending,
            );
          },
        )
        .subscribe();
  }

  // ── 发送普通文字 ──
  Future<void> sendText(String text) async {
    if (text.trim().isEmpty) return;

    final msg = ChatMessage(
      id: _uuid.v4(),
      senderId: currentUserId,
      receiverId: otherUserId,
      type: MessageType.text,
      text: text.trim(),
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      messages: [...state.messages, msg],
      isSending: true,
    );

    ref.read(chatThreadsProvider.notifier).bumpThreadAsUser(
          otherUserId,
          text.trim(),
        );
    _scheduleDemoAutoReply();

    try {
      await Supabase.instance.client.from('messages').insert({
        'id': msg.id,
        'sender_id': currentUserId,
        'receiver_id': otherUserId,
        'content': text.trim(),
      });
    } catch (_) {
      // 乐观更新已在 UI 显示，网络失败可做重试提示
    } finally {
      state = state.copyWith(isSending: false);
    }
  }

  /// MVP：1 秒后模拟对方回复（与消息列表预览同步）
  void _scheduleDemoAutoReply() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_disposed) return;
      const replyText = '你好，很高兴认识你！';
      final reply = ChatMessage(
        id: _uuid.v4(),
        senderId: otherUserId,
        receiverId: currentUserId,
        type: MessageType.text,
        text: replyText,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(messages: [...state.messages, reply]);
      ref.read(chatThreadsProvider.notifier).bumpThreadAsPeer(
            otherUserId,
            replyText,
            inForeground: true,
          );
    });
  }

  // ── 买家发送实时拍照请求 ──
  Future<void> sendPhotoRequest() async {
    final msg = ChatMessage(
      id: _uuid.v4(),
      senderId: currentUserId,
      receiverId: otherUserId,
      type: MessageType.photoRequest,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(messages: [...state.messages, msg]);

    try {
      await Supabase.instance.client.from('messages').insert({
        'id': msg.id,
        'sender_id': currentUserId,
        'receiver_id': otherUserId,
        'content': '[PHOTO_REQUEST] 请求你拍一张实时照片以确认档期状态',
      });
    } catch (_) {}
  }

  // ── 卖家回复加水印的实时照片（不可撤回） ──
  Future<void> sendRealtimePhoto(File watermarkedFile) async {
    state = state.copyWith(isSending: true);

    try {
      final url = await StorageService.uploadRealtimePhoto(
        senderId: currentUserId,
        imageFile: watermarkedFile,
      );

      final msg = ChatMessage(
        id: _uuid.v4(),
        senderId: currentUserId,
        receiverId: otherUserId,
        type: MessageType.realtimePhoto,
        photoUrl: url,
        isIrrevocable: true,
        createdAt: DateTime.now(),
      );

      state = state.copyWith(
        messages: [...state.messages, msg],
        photoRequestPending: false,
        isSending: false,
      );

      await Supabase.instance.client.from('messages').insert({
        'id': msg.id,
        'sender_id': currentUserId,
        'receiver_id': otherUserId,
        'content': '[REALTIME_PHOTO] $url',
      });
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: '发送失败：$e',
      );
    }
  }

  void dismissPhotoRequest() {
    state = state.copyWith(photoRequestPending: false);
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}

// ──────────────────────────────────────────
// Provider Family（按对话对象区分）
// ──────────────────────────────────────────

final chatProvider = StateNotifierProvider.family<ChatNotifier, ChatState,
    ({String currentUserId, String otherUserId})>(
  (ref, ids) => ChatNotifier(
    ref: ref,
    currentUserId: ids.currentUserId,
    otherUserId: ids.otherUserId,
  ),
);
