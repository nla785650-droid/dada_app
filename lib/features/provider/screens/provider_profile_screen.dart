import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/provider_summary.dart';
import '../widgets/rating_bottom_sheet.dart';
import '../widgets/service_timeline_calendar.dart';
import '../widgets/booking_confirm_sheet.dart';

// ══════════════════════════════════════════════════════════════
// ProviderProfileScreen：达人个人主页
//
// 入口：DiscoverScreen 卡片点击 → Hero 动画跳入
// 出口：
//   · 立即预约 → PaymentMockScreen
//   · 发消息   → ChatScreen
//   · ⭐ 评分  → RatingBottomSheet
// ══════════════════════════════════════════════════════════════

class ProviderProfileScreen extends StatefulWidget {
  const ProviderProfileScreen({
    super.key,
    required this.provider,
  });

  final ProviderSummary provider;

  @override
  State<ProviderProfileScreen> createState() => _ProviderProfileScreenState();
}

class _ProviderProfileScreenState extends State<ProviderProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeIn;
  bool _bookingLoading = false;
  AvailabilitySlot? _selectedSlot;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  ProviderSummary get _p => widget.provider;

  // ── 模拟作品集（生产环境从 portfolios 表查询）──
  List<String> get _portfolio {
    if (_p.portfolio.isNotEmpty) return _p.portfolio;
    return List.generate(
      6,
      (i) => 'https://picsum.photos/seed/${_p.id}_port$i/300/300',
    );
  }

  Future<void> _onBook() async {
    if (_selectedSlot != null) {
      // 用户已选档期 → 弹出确认浮层
      await BookingConfirmSheet.show(
        context: context,
        provider: _p,
        slot: _selectedSlot!,
      );
    } else {
      // 未选档期 → 提示滚动到日历选择
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('请先在下方档期日历中选择时间段'),
            ],
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildHeroBanner(context),
            SliverToBoxAdapter(child: _buildInfoSection()),
            SliverToBoxAdapter(child: _buildTagsSection()),
            SliverToBoxAdapter(child: _buildStatsRow()),
            // ── 档期时间轴（核心新功能）──
            SliverToBoxAdapter(child: _buildTimelineSection()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: const Text(
                  '作品集',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
              ),
            ),
            _buildPortfolioGrid(),
            SliverToBoxAdapter(
              child: SizedBox(
                height: MediaQuery.of(context).padding.bottom + 100,
              ),
            ),
          ],
        ),
      ),
      // 底部预约栏
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  // ── Hero Banner（卡片到详情的过渡动画）──
  Widget _buildHeroBanner(BuildContext context) {
    final bannerH =
        (MediaQuery.sizeOf(context).shortestSide * 0.92).clamp(300.0, 420.0);

    return SliverAppBar(
      expandedHeight: bannerH,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _GlassButton(
          icon: Icons.arrow_back_ios_rounded,
          onTap: () => Navigator.of(context).maybePop(),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: _GlassButton(
            icon: Icons.share_rounded,
            onTap: () {},
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Hero(
          tag: 'discover_${_p.id}',
          child: Material(
            color: Colors.transparent,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: _p.imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: kIsWeb
                      ? (MediaQuery.sizeOf(context).width *
                              MediaQuery.devicePixelRatioOf(context))
                          .round()
                          .clamp(600, 1400)
                      : null,
                  memCacheHeight: kIsWeb
                      ? (bannerH *
                              MediaQuery.devicePixelRatioOf(context))
                          .round()
                          .clamp(800, 2000)
                      : null,
                  maxWidthDiskCache: kIsWeb ? 1400 : null,
                  maxHeightDiskCache: kIsWeb ? 2000 : null,
                ),
                // 底部渐变
                const DecoratedBox(
                  decoration: BoxDecoration(gradient: AppTheme.cardGradient),
                ),
                // 验证标签
                Positioned(
                  top: MediaQuery.of(context).padding.top + 56,
                  right: 16,
                  child: _VerifiedBadge(isVerified: _p.isVerified),
                ),
                // 名称（在 Banner 未折叠时显示）
                Positioned(
                  bottom: 28,
                  left: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            _p.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_p.typeEmoji} ${_p.tag}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded,
                              size: 13, color: Colors.white70),
                          Text(
                            _p.location,
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 13),
                          ),
                          const SizedBox(width: 12),
                          RatingBarIndicator(
                            rating: _p.rating,
                            itemBuilder: (_, __) => const Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFC107)),
                            itemCount: 5,
                            itemSize: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _p.rating.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_p.bio != null && _p.bio!.isNotEmpty) ...[
            Text(
              _p.bio!,
              style: const TextStyle(
                  color: AppTheme.onSurfaceVariant, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 12),
          ] else ...[
            Text(
              '${_p.typeEmoji} 专业${_p.tag}，累计服务 ${_p.completedOrders} 次，好评率 99%。期待与你的相遇～',
              style: const TextStyle(
                  color: AppTheme.onSurfaceVariant, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildTagsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _p.tags.map((t) => _TagChip(label: t)).toList(),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          _StatCard(value: '${_p.reviews}', label: '评价'),
          const SizedBox(width: 10),
          _StatCard(value: '${_p.completedOrders}', label: '已完成'),
          const SizedBox(width: 10),
          _StatCard(value: _p.rating.toStringAsFixed(1), label: '综合评分'),
          const SizedBox(width: 10),
          _StatCard(value: '¥${_p.price}起', label: '服务定价'),
        ],
      ),
    );
  }

  Widget _buildTimelineSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 节标题
          Row(
            children: [
              Container(
                width: 3, height: 18,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppTheme.primary, AppTheme.accent],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                '预约档期',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              if (_selectedSlot != null)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    key: ValueKey(_selectedSlot!.id),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border:
                          Border.all(color: AppTheme.primary.withOpacity(0.4)),
                    ),
                    child: Text(
                      '✓ ${_selectedSlot!.timeRange}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 日历组件
          ServiceTimelineCalendar(
            provider: _p,
            onSlotSelected: (slot) {
              setState(() => _selectedSlot = slot);
              // 选中后轻震动提示
              if (slot != null) {
                ScaffoldMessenger.of(context).clearSnackBars();
              }
            },
          ),

          // 选中时显示快速预约提示条
          if (_selectedSlot != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _onBook,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.flash_on_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '已选：${_selectedSlot!.timeRange}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '¥${(_selectedSlot!.price ?? _p.price) * _selectedSlot!.durationHours} · ${_selectedSlot!.durationHours.toStringAsFixed(0)}小时 · 点击确认预约',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white70),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPortfolioGrid() {
    final items = _portfolio;
    final thumbPx = kIsWeb
        ? ((MediaQuery.sizeOf(context).width / 3) *
                MediaQuery.devicePixelRatioOf(context))
            .round()
            .clamp(200, 600)
        : null;

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: items[i],
              fit: BoxFit.cover,
              memCacheWidth: thumbPx,
              memCacheHeight: thumbPx,
              maxWidthDiskCache: kIsWeb ? 640 : null,
              maxHeightDiskCache: kIsWeb ? 640 : null,
              placeholder: (_, __) => Container(color: AppTheme.surfaceVariant),
            ),
          ),
          childCount: items.length,
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.divider, width: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12),
        ],
      ),
      child: Row(
        children: [
          // 评分按钮
          GestureDetector(
            onTap: () => RatingBottomSheet.show(context, provider: _p),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.star_rounded,
                  color: Color(0xFFFFC107), size: 24),
            ),
          ),
          const SizedBox(width: 10),
          // 消息按钮
          GestureDetector(
            onTap: () => context.push('/chat/dm/${_p.id}'),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.chat_bubble_rounded,
                  color: AppTheme.primary, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          // 预约按钮
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _bookingLoading
                  ? Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _onBook,
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
                        child: Center(
                          child: Text(
                            _selectedSlot != null ? '确认预约 ${_selectedSlot!.startTime}' : '选择时段并预约',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
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

// ──────────────────────────────────────
// 小组件
// ──────────────────────────────────────

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.icon, required this.onTap});
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
            width: 36,
            height: 36,
            color: Colors.black.withOpacity(0.28),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge({required this.isVerified});

  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    if (!isVerified) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          color: Colors.black.withOpacity(0.3),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, color: Colors.lightBlueAccent, size: 14),
              SizedBox(width: 4),
              Text('已认证',
                  style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
      ),
      child: Text(
        '# $label',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04), blurRadius: 6),
          ],
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.onSurface)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
