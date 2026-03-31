import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/post_model.dart';
import 'pureget_image_audit.dart' show PureGetAuditTheme;

/// 瀑布流卡片：独立 State，点赞/收藏等仅在当前卡片 setState，不牵连整列表。
class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post, required this.index});

  final Post post;
  final int index;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _imageTapTimer;
  late AnimationController _heartAnim;
  bool _liked = false;
  bool _bookmarked = false;
  bool _shareActive = false;
  late int _likeCount;
  final List<String> _comments = [];

  static const _tapNavDelay = Duration(milliseconds: 320);

  static const _likeColor = Color(0xFFFF6B9D);
  static const _bookmarkColor = Color(0xFFFFC107);

  double get _imageHeight {
    final heights = [200.0, 160.0, 220.0, 180.0, 240.0];
    return heights[widget.index % heights.length];
  }

  (int, int) _memCachePx(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = MediaQuery.sizeOf(context).width;
    final colW = (w / 2 - 28).clamp(120.0, 420.0);
    final mw = (colW * dpr).round().clamp(180, kIsWeb ? 900 : 1200);
    final mh = (_imageHeight * dpr).round().clamp(200, kIsWeb ? 1100 : 1600);
    return (mw, mh);
  }

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _heartAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          _heartAnim.reset();
        }
      });
  }

  @override
  void dispose() {
    _imageTapTimer?.cancel();
    _heartAnim.dispose();
    super.dispose();
  }

  void _openPostDetail() {
    context.pushNamed(
      'postDetail',
      pathParameters: {'postId': widget.post.id},
      extra: widget.post,
    );
  }

  void _onCoverImageTap() {
    _imageTapTimer?.cancel();
    _imageTapTimer = Timer(_tapNavDelay, () {
      if (!mounted) return;
      _openPostDetail();
    });
  }

  void _onCoverImageDoubleTap() {
    _imageTapTimer?.cancel();
    if (!_liked) {
      setState(() {
        _liked = true;
        _likeCount += 1;
      });
    }
    if (_heartAnim.isAnimating) {
      _heartAnim.reset();
    }
    _heartAnim.forward(); // 已点赞时仍播放双击反馈动画
  }

  void _toggleLikeBar() {
    setState(() {
      if (_liked) {
        _liked = false;
        _likeCount = (_likeCount > 0) ? _likeCount - 1 : 0;
      } else {
        _liked = true;
        _likeCount += 1;
      }
    });
  }

  void _showBookmarkVaultToast() {
    final entry = OverlayEntry(
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 48),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: PureGetAuditTheme.accentCyan.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded,
                    color: PureGetAuditTheme.accentCyan, size: 22),
                const SizedBox(width: 10),
                const Flexible(
                  child: Text(
                    '已加入 PureGet 个人保险箱',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(entry);
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      entry.remove();
    });
  }

  void _toggleBookmark() {
    setState(() => _bookmarked = !_bookmarked);
    if (_bookmarked) {
      _showBookmarkVaultToast();
    }
  }

  Future<void> _openShareSheet() async {
    setState(() => _shareActive = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (mounted) setState(() => _shareActive = false);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PureGetShareSheet(postTitle: widget.post.title),
    );
  }

  Future<void> _openCommentSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _CommentSheet(
          existing: List<String>.from(_comments),
          onSend: (text) {
            if (!mounted) return;
            setState(() => _comments.insert(0, text));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('评论已发送，PureGet 正在审核内容安全…'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RepaintBoundary(
      child: Hero(
        tag: 'post_${widget.post.id}',
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCoverImage(),
                InkWell(
                  onTap: _openPostDetail,
                  child: _buildInfo(),
                ),
                _buildInteractionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    final bytes = widget.post.localCoverBytes;
    final Widget cover = bytes != null
        ? Image.memory(
            bytes,
            height: _imageHeight,
            width: double.infinity,
            fit: BoxFit.cover,
          )
        : CachedNetworkImage(
            imageUrl: widget.post.displayCoverImage,
            height: _imageHeight,
            width: double.infinity,
            fit: BoxFit.cover,
            memCacheWidth: _memCachePx(context).$1,
            memCacheHeight: _memCachePx(context).$2,
            maxWidthDiskCache: kIsWeb ? 1000 : 1400,
            maxHeightDiskCache: kIsWeb ? 1200 : 1800,
            placeholder: (_, __) => Shimmer.fromColors(
              baseColor: AppTheme.surfaceVariant,
              highlightColor: Colors.white,
              child: Container(
                height: _imageHeight,
                color: AppTheme.surfaceVariant,
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              height: _imageHeight,
              color: AppTheme.surfaceVariant,
              child: const Icon(
                Icons.image_not_supported_rounded,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onCoverImageTap,
      onDoubleTap: _onCoverImageDoubleTap,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          cover,
          Positioned(
            top: 10,
            left: 10,
            child: _CategoryChip(category: widget.post.category),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _heartAnim,
                builder: (_, __) {
                  final t = _heartAnim.value;
                  if (t == 0 && !_heartAnim.isAnimating) {
                    return const SizedBox.shrink();
                  }
                  final scale = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
                  final opacity = t < 0.42
                      ? 1.0
                      : (1.0 - ((t - 0.42) / 0.58).clamp(0.0, 1.0));
                  return Center(
                    child: Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFE91E63),
                          size: 84,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfo() {
    final name = widget.post.provider?.displayNameOrUsername ?? '搭哒用户';
    final avatarUrl = widget.post.provider?.avatarUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.post.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _AuthorAvatar(url: avatarUrl, name: name),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                widget.post.priceDisplay,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent.withValues(alpha: 0.95),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 底部固定高度互动栏，避免随正文变长短不齐
  Widget _buildInteractionBar() {
    return SizedBox(
      height: 44,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            Expanded(
              child: _InteractionIconButton(
                outlineIcon: Icons.favorite_border_rounded,
                filledIcon: Icons.favorite_rounded,
                isActive: _liked,
                activeColor: _likeColor,
                label: _likeCount > 0 ? '$_likeCount' : '',
                onTap: _toggleLikeBar,
              ),
            ),
            Expanded(
              child: _InteractionIconButton(
                outlineIcon: Icons.chat_bubble_outline_rounded,
                filledIcon: Icons.chat_bubble_rounded,
                isActive: _comments.isNotEmpty,
                activeColor: AppTheme.primary,
                label: _comments.isNotEmpty ? '${_comments.length}' : '',
                onTap: _openCommentSheet,
              ),
            ),
            Expanded(
              child: _InteractionIconButton(
                outlineIcon: Icons.bookmark_border_rounded,
                filledIcon: Icons.bookmark_rounded,
                isActive: _bookmarked,
                activeColor: _bookmarkColor,
                label: '',
                onTap: _toggleBookmark,
              ),
            ),
            Expanded(
              child: _InteractionIconButton(
                outlineIcon: Icons.send_outlined,
                filledIcon: Icons.send_rounded,
                isActive: _shareActive,
                activeColor: PureGetAuditTheme.accentCyan,
                label: '',
                onTap: _openShareSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 轻触缩放反馈 ──
class _InteractionIconButton extends StatefulWidget {
  const _InteractionIconButton({
    required this.outlineIcon,
    required this.filledIcon,
    required this.isActive,
    required this.activeColor,
    required this.label,
    required this.onTap,
  });

  final IconData outlineIcon;
  final IconData filledIcon;
  final bool isActive;
  final Color activeColor;
  final String label;
  final VoidCallback onTap;

  @override
  State<_InteractionIconButton> createState() => _InteractionIconButtonState();
}

class _InteractionIconButtonState extends State<_InteractionIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scale;

  @override
  void initState() {
    super.initState();
    _scale = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  Future<void> _pulse() async {
    await _scale.forward();
    await _scale.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final icon = widget.isActive ? widget.filledIcon : widget.outlineIcon;
    final color = widget.isActive
        ? widget.activeColor
        : AppTheme.onSurfaceVariant.withValues(alpha: 0.85);

    return InkWell(
      onTap: () {
        _pulse();
        widget.onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: AnimatedBuilder(
          animation: _scale,
          builder: (_, __) {
            final s = 1.0 - _scale.value * 0.12;
            return Transform.scale(
              scale: s,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20, color: color),
                  if (widget.label.isNotEmpty) ...[
                    const SizedBox(width: 3),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PureGetShareSheet extends StatelessWidget {
  const _PureGetShareSheet({required this.postTitle});

  final String postTitle;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: PureGetAuditTheme.panel.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: PureGetAuditTheme.accentCyan.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined,
                    color: PureGetAuditTheme.accentCyan, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'PureGet 已对分享内容进行隐私脱敏处理',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: PureGetAuditTheme.deepBlue,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ListTile(
            leading: Icon(Icons.photo_size_select_large_outlined,
                color: PureGetAuditTheme.accentCyan),
            title: const Text('生成分享长图（模拟）'),
            subtitle: Text(
              postTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(context);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('已生成脱敏长图（演示）'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.link_rounded,
                color: PureGetAuditTheme.accentCyan),
            title: const Text('复制安全链接（模拟）'),
            subtitle: const Text(
              '链接已脱敏，不含精确位置等敏感字段',
              style: TextStyle(fontSize: 12),
            ),
            onTap: () async {
              await Clipboard.setData(
                ClipboardData(
                  text:
                      'https://dada.app/share/${postTitle.hashCode.abs()}?pg=sanitized',
                ),
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('安全链接已复制'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _CommentSheet extends StatefulWidget {
  const _CommentSheet({required this.existing, required this.onSend});

  final List<String> existing;
  final void Function(String text) onSend;

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    widget.onSend(t);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final h = MediaQuery.sizeOf(context).height * 0.52;
    return SizedBox(
      height: h,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '评论',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: widget.existing.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无评论，做第一个吧～',
                        style: TextStyle(color: AppTheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: widget.existing.length,
                      itemBuilder: (_, i) => ListTile(
                        dense: true,
                        leading: const CircleAvatar(
                          radius: 18,
                          child: Icon(Icons.person_rounded, size: 20),
                        ),
                        title: Text(widget.existing[i]),
                      ),
                    ),
            ),
            const Divider(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: const InputDecoration(
                      hintText: '说点什么…',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _send,
                  child: const Icon(Icons.send_rounded, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({this.url, required this.name});

  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';

    if (url != null && url!.isNotEmpty) {
      return CircleAvatar(
        radius: 11,
        backgroundColor: AppTheme.surfaceVariant,
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: url!,
            width: 22,
            height: 22,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _initialFallback(initial),
          ),
        ),
      );
    }
    return _initialFallback(initial);
  }

  Widget _initialFallback(String initial) {
    return CircleAvatar(
      radius: 11,
      backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.category});

  final String category;

  Color get _bgColor {
    return switch (category) {
      'cosplay' => const Color(0xCCBB6BD9),
      'photo' => const Color(0xCC3498DB),
      'game' => const Color(0xCC2ECC71),
      _ => const Color(0xCC95A5A6),
    };
  }

  String get _label {
    return switch (category) {
      'cosplay' => 'Cos',
      'photo' => '摄影',
      'game' => '陪玩',
      _ => '其他',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
