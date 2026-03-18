import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// ProviderReviewsScreen：达人收到的评价列表
//
// 功能：
//   · 顶部：总评分 + 评价数 + 星级分布
//   · Tab：全部 / 5星 / 4星及以下
//   · 评价卡片：头像、昵称/匿名、五维评分、文字、图片、时间、关联服务
//   · 支持达人回复（预留）
//   · 数据来源：reviews 表 (reviewee_id = 当前用户)
// ══════════════════════════════════════════════════════════════

class ProviderReviewsScreen extends StatefulWidget {
  const ProviderReviewsScreen({super.key});

  @override
  State<ProviderReviewsScreen> createState() => _ProviderReviewsScreenState();
}

class _ProviderReviewsScreenState extends State<ProviderReviewsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reviews = _mockReviews;

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        backgroundColor: AppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          '收到的评价',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: AppTheme.divider),
        ),
      ),
      body: Column(
        children: [
          // 评分概览头
          _SummaryHeader(reviews: reviews),
          const Divider(height: 0.5, color: AppTheme.divider),

          // Tab：全部 / 5星 / 4星及以下
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.onSurfaceVariant,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: '全部'),
              Tab(text: '5星'),
              Tab(text: '4星及以下'),
            ],
          ),

          // 评价列表
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ReviewsList(reviews: reviews),
                _ReviewsList(reviews: reviews.where((r) => r.rating >= 4.95).toList()),
                _ReviewsList(reviews: reviews.where((r) => r.rating < 4.95).toList()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 评分概览头 ──
class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.reviews});
  final List<_ReviewItem> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            '暂无评价',
            style: TextStyle(color: AppTheme.onSurfaceVariant),
          ),
        ),
      );
    }

    final avg = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    final star5 = reviews.where((r) => r.rating >= 4.95).length;
    final star4 = reviews.where((r) => r.rating >= 3.95 && r.rating < 4.95).length;
    final star3 = reviews.length - star5 - star4;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                avg.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              RatingBarIndicator(
                rating: avg,
                itemCount: 5,
                itemSize: 14,
                unratedColor: AppTheme.divider,
                itemBuilder: (_, __) => const Icon(
                  Icons.star_rounded,
                  color: Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${reviews.length} 条评价',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StarBar(label: '5星', count: star5, total: reviews.length),
                _StarBar(label: '4星', count: star4, total: reviews.length),
                _StarBar(label: '3星及以下', count: star3, total: reviews.length),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarBar extends StatelessWidget {
  const _StarBar({
    required this.label,
    required this.count,
    required this.total,
  });
  final String label;
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final rate = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: rate,
                backgroundColor: AppTheme.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                minHeight: 6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── 评价列表 ──
class _ReviewsList extends StatelessWidget {
  const _ReviewsList({required this.reviews});
  final List<_ReviewItem> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔍', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text(
              '暂无此类评价',
              style: TextStyle(color: AppTheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 80,
      ),
      physics: const BouncingScrollPhysics(),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _ReviewCard(item: reviews[i]),
    );
  }
}

// ── 评价卡片 ──
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.item});
  final _ReviewItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (item.bookingId != null) {
          context.push('/order/${item.bookingId}');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 头像
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: item.isAnonymous
                      ? Container(
                          width: 44,
                          height: 44,
                          color: AppTheme.surfaceVariant,
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: item.avatarUrl ?? 'https://picsum.photos/seed/avatar/100/100',
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: AppTheme.surfaceVariant,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.isAnonymous ? '匿名用户' : item.reviewerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.timeAgo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                RatingBarIndicator(
                  rating: item.rating,
                  itemCount: 5,
                  itemSize: 14,
                  unratedColor: AppTheme.divider,
                  itemBuilder: (_, __) => const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            if (item.serviceName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 12, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      item.serviceName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (item.amount != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        '¥${item.amount!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (item.comment != null && item.comment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                item.comment!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.onSurface,
                  height: 1.5,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (item.photoUrls != null && item.photoUrls!.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: item.photoUrls!.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, j) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: item.photoUrls![j],
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
            if (item.reply != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '我的回复：',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.reply!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '回复',
                    style: TextStyle(fontSize: 12, color: AppTheme.primary),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── 评价数据模型 ──
class _ReviewItem {
  const _ReviewItem({
    required this.id,
    required this.rating,
    required this.reviewerName,
    required this.timeAgo,
    this.comment,
    this.avatarUrl,
    this.serviceName,
    this.amount,
    this.photoUrls,
    this.reply,
    this.bookingId,
    this.isAnonymous = false,
  });

  final String id;
  final double rating;
  final String reviewerName;
  final String timeAgo;
  final String? comment;
  final String? avatarUrl;
  final String? serviceName;
  final double? amount;
  final List<String>? photoUrls;
  final String? reply;
  final String? bookingId;
  final bool isAnonymous;
}

// ── Mock 数据 ──
final _mockReviews = [
  const _ReviewItem(
    id: 'r1',
    rating: 5.0,
    reviewerName: '凉月',
    timeAgo: '2天前',
    comment: '摄影技术一流，构图很有想法，出片速度快，下次还会找你！',
    avatarUrl: 'https://picsum.photos/seed/u1/100/100',
    serviceName: '汉服摄影 · 2小时',
    amount: 350,
    bookingId: 'b1',
  ),
  const _ReviewItem(
    id: 'r2',
    rating: 4.8,
    reviewerName: '星辰',
    timeAgo: '5天前',
    comment: '非常专业的Coser，角色还原度高，现场气氛很好～',
    avatarUrl: 'https://picsum.photos/seed/u2/100/100',
    serviceName: 'Cos委托 · 漫展',
    amount: 280,
    photoUrls: ['https://picsum.photos/seed/r2a/200/200'],
    bookingId: 'b2',
  ),
  const _ReviewItem(
    id: 'r3',
    rating: 5.0,
    reviewerName: '匿名用户',
    timeAgo: '1周前',
    comment: '陪玩很耐心，技术在线，上分顺利！',
    serviceName: '王者陪玩 · 3局',
    amount: 90,
    isAnonymous: true,
    bookingId: 'b3',
    reply: '感谢认可，期待下次一起玩～',
  ),
  const _ReviewItem(
    id: 'r4',
    rating: 4.6,
    reviewerName: '小樱',
    timeAgo: '2周前',
    comment: '拍摄效果不错，就是当天天气有点阴，不过成片还是很满意的。',
    avatarUrl: 'https://picsum.photos/seed/u4/100/100',
    serviceName: '日系写真',
    amount: 220,
    photoUrls: [
      'https://picsum.photos/seed/r4a/200/200',
      'https://picsum.photos/seed/r4b/200/200',
    ],
    bookingId: 'b4',
  ),
  const _ReviewItem(
    id: 'r5',
    rating: 5.0,
    reviewerName: '流光',
    timeAgo: '3周前',
    comment: '超级满意！从妆造到拍摄一条龙，非常省心。',
    avatarUrl: 'https://picsum.photos/seed/u5/100/100',
    serviceName: '古风Cos · 全天',
    amount: 680,
    bookingId: 'b5',
  ),
];
