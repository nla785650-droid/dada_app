import 'dart:typed_data';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/provider_summary.dart';

// ══════════════════════════════════════════════════════════════
// PostDetailPage：内容详情页
//
// Hero 动画：post_${post.id}（从瀑布流卡片进入）
// 出口：
//   · 点击发布者头像 / "预约" → ProviderProfileScreen
//   · 点击"❤️ 喜欢" → 本地计数动画
//   · 点击"💬 评论" → 评论浮层
// ══════════════════════════════════════════════════════════════

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({super.key, required this.post});

  final Post post;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen>
    with SingleTickerProviderStateMixin {
  int _currentImage = 0;
  bool _liked = false;
  int _likeCount = 0;

  // 点赞弹跳动画
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _likeCount = widget.post.likeCount;
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _heartScale = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _heartCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  Post get _post => widget.post;

  /// 轮播用网络图 URL（本机动态可为空，由 [Post.localCoverBytes] 承载封面）
  List<String> get _imageUrls {
    if (_post.images.isNotEmpty) return _post.images;
    if (_post.hasLocalCover) return const [];
    final u = _post.displayCoverImage;
    return u.isNotEmpty ? [u] : ['https://picsum.photos/seed/${_post.id}/400/560'];
  }

  void _toggleLike() {
    HapticFeedback.lightImpact();
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    _heartCtrl.forward(from: 0);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_liked ? '已点赞 ❤️' : '已取消点赞'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _goToProvider() {
    final provider = _post.provider;
    final coverUrl = _post.displayCoverImage.isNotEmpty
        ? _post.displayCoverImage
        : 'https://picsum.photos/seed/${_post.id}/400/560';
    final summary = ProviderSummary(
      id:        _post.providerId,
      name:      provider?.displayName ?? '达人',
      tag:       _post.categoryLabel,
      typeEmoji: _post.category == 'cosplay' ? '🎭' : _post.category == 'photo' ? '📸' : '🎮',
      imageUrl:  coverUrl,
      rating:    provider?.rating ?? 4.8,
      reviews:   provider?.reviewCount ?? 0,
      location:  _post.location ?? '',
      price:     _post.price.toInt(),
      tags:      _post.tags ?? [],
      avatarUrl: provider?.avatarUrl,
      portfolio: List<String>.from(_imageUrls),
      isVerified: provider?.isVerified ?? false,
    );
    context.pushNamed(
      'providerProfile',
      pathParameters: {'id': _post.providerId},
      extra: summary.toExtra(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final carouselH =
        (mq.size.width * 0.72).clamp(240.0, 480.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── 图片轮播 AppBar ──
          SliverAppBar(
            expandedHeight: carouselH,
            pinned: false,
            floating: false,
            backgroundColor: Colors.transparent,
            leading: _GlassBtn(
              icon: Icons.arrow_back_ios_rounded,
              onTap: () => Navigator.of(context).maybePop(),
            ),
            actions: [
              _GlassBtn(
                icon: Icons.ios_share_rounded,
                onTap: () {},
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _ImageCarousel(
                images: _imageUrls,
                localCoverBytes: _post.localCoverBytes,
                heroTag: 'post_${_post.id}',
                onPageChanged: (i) => setState(() => _currentImage = i),
                currentIndex: _currentImage,
              ),
            ),
          ),

          // ── 内容区域 ──
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 把手装饰
                    Center(
                      child: Container(
                        width: 36, height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.divider,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 发布者信息
                    _ProviderRow(post: _post, onTap: _goToProvider),
                    const SizedBox(height: 16),

                    // 价格 + 标题
                    _PriceTag(price: _post.price, unit: _post.priceUnit),
                    const SizedBox(height: 8),
                    Text(
                      _post.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.onSurface,
                        height: 1.3,
                      ),
                    ),

                    // 标签
                    if (_post.tags != null && _post.tags!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: _post.tags!.map((t) => _TagBubble(tag: t)).toList(),
                      ),
                    ],

                    // 描述
                    if (_post.description != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _post.description!,
                        style: const TextStyle(
                          color: AppTheme.onSurfaceVariant,
                          fontSize: 14,
                          height: 1.65,
                        ),
                      ),
                    ],

                    if (_imageUrls.length > 1) ...[
                      const SizedBox(height: 18),
                      const Text(
                        '服务样片',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 76,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageUrls.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 8),
                          itemBuilder: (_, i) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: CachedNetworkImage(
                                  imageUrl: _imageUrls[i],
                                  fit: BoxFit.cover,
                                  memCacheWidth: 240,
                                  memCacheHeight: 240,
                                  maxWidthDiskCache:
                                      kIsWeb ? 480 : 600,
                                  maxHeightDiskCache:
                                      kIsWeb ? 480 : 600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(color: AppTheme.divider),

                    // 互动数据栏
                    _InteractionBar(
                      likeCount: _likeCount,
                      liked: _liked,
                      heartScale: _heartScale,
                      onLike: _toggleLike,
                      onComment: () => _showCommentSheet(context),
                    ),

                    const Divider(color: AppTheme.divider),
                    const SizedBox(height: 8),

                    // 评论列表
                    _MockComments(providerId: _post.providerId),

                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 100,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // 底部预约 CTA
      bottomNavigationBar: _BottomBar(
        price: _post.price,
        priceUnit: _post.priceUnit,
        onBook: _goToProvider,
      ),
    );
  }

  void _showCommentSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentSheet(postId: _post.id),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 图片轮播
// ══════════════════════════════════════════════════════════════

class _ImageCarousel extends StatelessWidget {
  const _ImageCarousel({
    required this.images,
    this.localCoverBytes,
    required this.heroTag,
    required this.currentIndex,
    required this.onPageChanged,
  });

  final List<String> images;
  final Uint8List? localCoverBytes;
  final String heroTag;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;

  int get _pageCount {
    if (localCoverBytes != null && images.isEmpty) return 1;
    return images.length;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          onPageChanged: onPageChanged,
          itemCount: _pageCount,
          itemBuilder: (_, i) {
            if (localCoverBytes != null && images.isEmpty) {
              final mem = Image.memory(
                localCoverBytes!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              );
              return Hero(
                tag: heroTag,
                child: Material(color: Colors.transparent, child: mem),
              );
            }

            final img = CachedNetworkImage(
              imageUrl: images[i],
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              memCacheWidth: kIsWeb ? 1200 : null,
              memCacheHeight: kIsWeb ? 1600 : null,
              maxWidthDiskCache: kIsWeb ? 1400 : null,
              maxHeightDiskCache: kIsWeb ? 2000 : null,
            );
            if (i == 0) {
              return Hero(
                tag: heroTag,
                child: Material(color: Colors.transparent, child: img),
              );
            }
            return img;
          },
        ),

        if (_pageCount > 1)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${currentIndex + 1}/$_pageCount',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),

        // 底部页码点
        if (_pageCount > 1)
          Positioned(
            bottom: 20,
            left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pageCount, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == currentIndex ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == currentIndex ? Colors.white : Colors.white54,
                  borderRadius: BorderRadius.circular(3),
                ),
              )),
            ),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 发布者信息行
// ══════════════════════════════════════════════════════════════

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.post, required this.onTap});
  final Post post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Hero(
            tag: 'avatar_${post.providerId}',
            child: CircleAvatar(
              radius: 22,
              backgroundImage: post.provider?.avatarUrl != null
                  ? NetworkImage(post.provider!.avatarUrl!)
                  : null,
              backgroundColor: AppTheme.surfaceVariant,
              child: post.provider?.avatarUrl == null
                  ? Text(
                      (post.provider?.displayName ?? '达').substring(0, 1),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  post.provider?.displayName ?? '达人 ${post.providerId.substring(0, 6)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: AppTheme.onSurface,
                  ),
                ),
                if (post.provider?.isVerified == true) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: Colors.blue.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '已实人认证',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
                if (post.location != null)
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 11, color: AppTheme.onSurfaceVariant),
                      Text(
                        post.location!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.primary),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '查看主页',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 互动栏（点赞 + 评论 + 分享）
// ══════════════════════════════════════════════════════════════

class _InteractionBar extends StatelessWidget {
  const _InteractionBar({
    required this.likeCount,
    required this.liked,
    required this.heartScale,
    required this.onLike,
    required this.onComment,
  });

  final int likeCount;
  final bool liked;
  final Animation<double> heartScale;
  final VoidCallback onLike;
  final VoidCallback onComment;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // 点赞
          GestureDetector(
            onTap: onLike,
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: heartScale,
                  builder: (_, __) => Transform.scale(
                    scale: heartScale.value,
                    child: Icon(
                      liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: liked ? AppTheme.accent : AppTheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '$likeCount',
                  style: TextStyle(
                    fontSize: 13,
                    color: liked ? AppTheme.accent : AppTheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          // 评论
          GestureDetector(
            onTap: onComment,
            child: const Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 20, color: AppTheme.onSurfaceVariant),
                SizedBox(width: 5),
                Text('评论',
                    style: TextStyle(
                        fontSize: 13, color: AppTheme.onSurfaceVariant)),
              ],
            ),
          ),

          const Spacer(),

          // 分享
          const Icon(Icons.ios_share_rounded,
              size: 20, color: AppTheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 模拟评论列表
// ══════════════════════════════════════════════════════════════

class _MockComments extends StatelessWidget {
  const _MockComments({required this.providerId});
  final String providerId;

  static final _comments = [
    ('🐣 小雨', '太美了！上次合作超级愉快，强烈推荐！', '2天前'),
    ('🌸 凉月', '这套汉服真的绝了，灵气十足✨', '3天前'),
    ('🎮 星海', '专业又有趣，下次还找你！', '1周前'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '评论 (${_comments.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ..._comments.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.surfaceVariant,
                    child: Text(c.$1.substring(0, 1),
                        style: const TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(c.$1,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(c.$3,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(c.$2,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppTheme.onSurface,
                                height: 1.4)),
                      ],
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 评论输入浮层
// ══════════════════════════════════════════════════════════════

class _CommentSheet extends StatelessWidget {
  const _CommentSheet({required this.postId});
  final String postId;

  @override
  Widget build(BuildContext context) {
    final textCtrl = TextEditingController();
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        left: 16, right: 16, top: 16,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Text('发表评论',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 12),
          TextField(
            controller: textCtrl,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: '留下你的想法...',
              filled: true,
              fillColor: AppTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('评论已发布 ✨')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
              ),
              child: const Text('发布',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 底部预约栏
// ══════════════════════════════════════════════════════════════

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.price,
    required this.priceUnit,
    required this.onBook,
  });

  final double price;
  final String priceUnit;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('服务起步价',
                  style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
              Text(
                '¥${price.toStringAsFixed(0)}/$priceUnit',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                onBook();
              },
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        '立即咨询 / 预约',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 小组件 ──

class _GlassBtn extends StatelessWidget {
  const _GlassBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 36, height: 36,
            color: Colors.black.withOpacity(0.25),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _PriceTag extends StatelessWidget {
  const _PriceTag({required this.price, required this.unit});
  final double price;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
      ),
      child: Text(
        '¥${price.toStringAsFixed(0)} / $unit',
        style: const TextStyle(
          color: AppTheme.accent,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TagBubble extends StatelessWidget {
  const _TagBubble({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '# $tag',
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
