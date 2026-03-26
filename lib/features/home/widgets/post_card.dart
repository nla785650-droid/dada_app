import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/post_model.dart';

// ── PostCard 升级为 StatefulWidget ──
// 优化点：
//   1. RepaintBoundary：将每个卡片隔离为独立渲染层，
//      滚动时不触发同屏其他卡片的重绘（目标帧率 60/120fps）
//   2. AutomaticKeepAliveClientMixin：Tab 切换时保留卡片状态
//   3. 图片使用 CachedNetworkImage + 骨架屏占位
class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post, required this.index});

  final Post post;
  final int index;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard>
    with AutomaticKeepAliveClientMixin {
  // 保持活跃：防止滚动时 widget 被销毁重建导致图片闪烁
  @override
  bool get wantKeepAlive => true;

  double get _imageHeight {
    final heights = [200.0, 160.0, 220.0, 180.0, 240.0];
    return heights[widget.index % heights.length];
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // 必须调用，触发 keepAlive 机制

    // RepaintBoundary：将此卡片隔离为独立合成层
    // 滚动时只有进出视口的卡片重绘，其余卡片直接复用 GPU 缓存
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => context.push('/post/${widget.post.id}', extra: widget.post),
        child: Hero(
          tag: 'post_${widget.post.id}',
          child: Material(
            color: Colors.transparent,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCoverImage(),
                  _buildInfo(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    return Stack(
      children: [
        CachedNetworkImage(
          imageUrl: widget.post.displayCoverImage,
          height: _imageHeight,
          width: double.infinity,
          fit: BoxFit.cover,
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
        ),
        // 分类标签
        Positioned(
          top: 10,
          left: 10,
          child: _CategoryChip(category: widget.post.category),
        ),
      ],
    );
  }

  Widget _buildInfo() {
    final name = widget.post.provider?.displayNameOrUsername ?? '搭哒用户';
    final avatarUrl = widget.post.provider?.avatarUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
            errorWidget: (_, __, ___) =>
                _initialFallback(initial),
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
