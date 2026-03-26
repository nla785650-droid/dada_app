import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/camera_service.dart';
import '../providers/chat_provider.dart';
import '../providers/chat_threads_provider.dart';
import '../widgets/realtime_camera_sheet.dart';

/// 聊天详情页（支持实时拍照请求）
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.currentUserId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserAvatar,
    this.isProvider = false, // 当前用户是否为卖家
  });

  final String currentUserId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final bool isProvider;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _showMoreActions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatThreadsProvider.notifier).clearUnread(widget.otherUserId);
    });
  }

  ChatNotifier get _notifier => ref.read(
        chatProvider(
          (
            currentUserId: widget.currentUserId,
            otherUserId: widget.otherUserId,
          ),
        ).notifier,
      );

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(
      chatProvider((
        currentUserId: widget.currentUserId,
        otherUserId: widget.otherUserId,
      )),
    );

    _scrollToBottom();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // 实时拍照请求横幅（卖家视角）
          if (chatState.photoRequestPending && widget.isProvider)
            _PhotoRequestBanner(
              onCapture: () => _openRealtimeCamera(context),
              onDismiss: _notifier.dismissPhotoRequest,
            ),
          // 消息列表（下拉刷新加载历史记录）
          Expanded(
            child: chatState.isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : RefreshIndicator(
                    color: AppTheme.primary,
                    onRefresh: () async {
                      await Future.delayed(const Duration(seconds: 1));
                      ref.invalidate(chatProvider((
                        currentUserId: widget.currentUserId,
                        otherUserId: widget.otherUserId,
                      )));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('历史记录已加载')),
                      );
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      itemCount: chatState.messages.length,
                      itemBuilder: (context, index) {
                        final msg = chatState.messages[index];
                        final isMine = msg.isSentBy(widget.currentUserId);
                        return _MessageBubble(
                          message: msg,
                          isMine: isMine,
                          otherName: widget.otherUserName,
                          otherAvatar: widget.otherUserAvatar,
                        );
                      },
                    ),
                  ),
          ),
          // 输入区
          _buildInputBar(context, chatState),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.glassBg,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                widget.otherUserAvatar ?? '🎭',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.otherUserName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                widget.isProvider ? '买家' : '卖家',
                style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz_rounded),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildInputBar(BuildContext context, ChatState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.glassBg,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // 扩展功能面板（买家才能发送拍照请求）
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 250),
              crossFadeState: _showMoreActions
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _MoreActionsPanel(
                isProvider: widget.isProvider,
                onPhotoRequest: () {
                  setState(() => _showMoreActions = false);
                  _notifier.sendPhotoRequest();
                },
                onRealtimeCapture: widget.isProvider
                    ? () {
                        setState(() => _showMoreActions = false);
                        _openRealtimeCamera(context);
                      }
                    : null,
              ),
            ),
            // 主输入行
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  // 更多功能按钮
                  GestureDetector(
                    onTap: () =>
                        setState(() => _showMoreActions = !_showMoreActions),
                    child: AnimatedRotation(
                      turns: _showMoreActions ? 0.125 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: AppTheme.onSurface),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 输入框
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _textController,
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (v) => _sendText(),
                        decoration: const InputDecoration(
                          hintText: '说点什么…',
                          hintStyle:
                              TextStyle(color: AppTheme.onSurfaceVariant),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 发送按钮
                  GestureDetector(
                    onTap: state.isSending ? null : _sendText,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: state.isSending
                          ? const Padding(
                              padding: EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendText() {
    final text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    _notifier.sendText(text);
  }

  Future<void> _openRealtimeCamera(BuildContext context) async {
    final hasPermission = await CameraService.requestCameraPermission();
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('需要相机权限才能进行实时拍摄'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RealtimeCameraSheet(
        onPhotoTaken: (File watermarkedPhoto) async {
          await _notifier.sendRealtimePhoto(watermarkedPhoto);
        },
      ),
    );
  }
}

// ──────────────────────────────────────────
// 消息气泡组件
// ──────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMine,
    required this.otherName,
    this.otherAvatar,
  });

  final ChatMessage message;
  final bool isMine;
  final String otherName;
  final String? otherAvatar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isMine) ...[
            _AvatarCircle(emoji: otherAvatar ?? '🎭'),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: _buildBubbleContent(context),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            _AvatarCircle(emoji: '🙋', isMe: true),
          ],
        ],
      ),
    );
  }

  Widget _buildBubbleContent(BuildContext context) {
    return switch (message.type) {
      MessageType.text => _TextBubble(
          text: message.text ?? '',
          isMine: isMine,
          time: _formatTime(message.createdAt),
        ),
      MessageType.photoRequest => _PhotoRequestBubble(isMine: isMine),
      MessageType.realtimePhoto => _RealtimePhotoBubble(
          photoUrl: message.photoUrl ?? '',
          isMine: isMine,
          time: _formatTime(message.createdAt),
        ),
    };
  }

  String _formatTime(DateTime dt) {
    return DateFormat('HH:mm').format(dt);
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.emoji, this.isMe = false});

  final String emoji;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isMe
            ? AppTheme.primary.withValues(alpha: 0.15)
            : AppTheme.surfaceVariant,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}

// 普通文字气泡
class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.text,
    required this.isMine,
    required this.time,
  });

  final String text;
  final bool isMine;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMine ? AppTheme.primary : Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMine ? 18 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 18),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isMine ? Colors.white : AppTheme.onSurface,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          time,
          style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// 拍照请求气泡
class _PhotoRequestBubble extends StatelessWidget {
  const _PhotoRequestBubble({required this.isMine});

  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMine
            ? AppTheme.primary.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.accent.withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                child: const Icon(Icons.camera_alt_rounded,
                    size: 18, color: Colors.white),
              ),
              const SizedBox(width: 6),
              const Text(
                '实时拍照请求',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '对方请求你拍摄一张实时照片\n照片将加盖防伪水印，发送后不可撤回',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// 实时照片气泡（带防撤回标记）
class _RealtimePhotoBubble extends StatelessWidget {
  const _RealtimePhotoBubble({
    required this.photoUrl,
    required this.isMine,
    required this.time,
  });

  final String photoUrl;
  final bool isMine;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => _showFullScreen(context),
          child: Container(
            width: 200,
            height: 260,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片
                  photoUrl.isNotEmpty
                      ? Image.network(photoUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.broken_image_rounded,
                                size: 40, color: Colors.grey),
                          ))
                      : Container(color: Colors.grey[300]),
                  // 防伪底条（模拟水印显示区域）
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 5),
                      color: Colors.black.withValues(alpha: 0.6),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '搭哒 · 实时拍摄',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            time,
                            style: const TextStyle(
                              color: Color(0xFFBB86FC),
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // 不可撤回标记
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '🔒 不可撤回',
                        style: TextStyle(color: Colors.white, fontSize: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded,
                size: 10, color: AppTheme.onSurfaceVariant),
            const SizedBox(width: 2),
            Text(
              '实时拍摄 · 防伪认证 · $time',
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),
      ],
    );
  }

  void _showFullScreen(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullScreenPhoto(photoUrl: photoUrl),
      ),
    );
  }
}

class _FullScreenPhoto extends StatelessWidget {
  const _FullScreenPhoto({required this.photoUrl});

  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '实时拍摄照片',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        actions: [
          // 不提供下载按钮（防止截图以外的获取方式）
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: Colors.white70),
                    SizedBox(width: 4),
                    Text('不可下载',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          child: photoUrl.isNotEmpty
              ? Image.network(photoUrl, fit: BoxFit.contain)
              : const Icon(Icons.image, size: 80, color: Colors.white24),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 实时拍照请求横幅（卖家视角）
// ──────────────────────────────────────────

class _PhotoRequestBanner extends StatelessWidget {
  const _PhotoRequestBanner({
    required this.onCapture,
    required this.onDismiss,
  });

  final VoidCallback onCapture;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.12),
            AppTheme.primary.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppTheme.accent.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
            child: const Icon(Icons.camera_alt_rounded,
                size: 22, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '买家请求实时拍照',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                Text(
                  '点击拍摄，照片自动加水印后发出',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onCapture,
            style: TextButton.styleFrom(
              backgroundColor: AppTheme.accent,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('去拍摄',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                size: 18, color: AppTheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// 更多功能面板
// ──────────────────────────────────────────

class _MoreActionsPanel extends StatelessWidget {
  const _MoreActionsPanel({
    required this.isProvider,
    required this.onPhotoRequest,
    this.onRealtimeCapture,
  });

  final bool isProvider;
  final VoidCallback onPhotoRequest;
  final VoidCallback? onRealtimeCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
      child: Row(
        children: [
          if (!isProvider) ...[
            // 买家：发送拍照请求
            _ActionTile(
              icon: Icons.camera_alt_rounded,
              label: '请求实拍',
              color: AppTheme.accent,
              onTap: onPhotoRequest,
            ),
          ],
          if (isProvider && onRealtimeCapture != null) ...[
            // 卖家：直接拍摄
            _ActionTile(
              icon: Icons.add_a_photo_rounded,
              label: '实时拍摄',
              color: AppTheme.primary,
              onTap: onRealtimeCapture!,
            ),
          ],
          _ActionTile(
            icon: Icons.calendar_month_rounded,
            label: '查看档期',
            color: AppTheme.success,
            onTap: () {},
          ),
          _ActionTile(
            icon: Icons.receipt_long_rounded,
            label: '查看订单',
            color: AppTheme.warning,
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 20),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: color.withValues(alpha: 0.2), width: 1),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
