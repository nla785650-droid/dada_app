import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// ProviderDashboardScreen：达人数据看板
//
// 功能：
//   · 核心指标卡片：曝光量、喜欢数、订单数、评价数
//   · 评分与收入概览
//   · 近 7 日趋势图（Mock）
//   · 数据来源：user_behaviors、user_likes、bookings、reviews
// ══════════════════════════════════════════════════════════════

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          '数据看板',
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
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).padding.bottom + 80,
        ),
        physics: const BouncingScrollPhysics(),
        children: [
          // 时间范围选择
          _TimeRangeChip(selected: '近7日'),
          const SizedBox(height: 20),

          // 核心指标 2x2 网格
          _StatsGrid(stats: _mockStats),
          const SizedBox(height: 20),

          // 评分 + 收入
          Row(
            children: [
              Expanded(
                child: _OverviewCard(
                  icon: Icons.star_rounded,
                  label: '平均评分',
                  value: '4.82',
                  sub: '共 42 条评价',
                  color: const Color(0xFFF59E0B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OverviewCard(
                  icon: Icons.payments_rounded,
                  label: '预估收入',
                  value: '¥8,420',
                  sub: '本月已完成',
                  color: AppTheme.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 趋势图
          _TrendSection(data: _mockTrendData),
          const SizedBox(height: 20),

          // 漏斗简要
          _FunnelCard(
            views: 12580,
            likes: 328,
            bookings: 96,
            completed: 78,
          ),
        ],
      ),
    );
  }
}

// ── Mock 数据 ──
final _mockStats = [
  _StatItem('曝光量', '12.5k', Icons.visibility_rounded, const Color(0xFF3498DB)),
  _StatItem('喜欢数', '328', Icons.favorite_rounded, AppTheme.accent),
  _StatItem('订单数', '96', Icons.receipt_long_rounded, AppTheme.primary),
  _StatItem('评价数', '42', Icons.rate_review_rounded, const Color(0xFFF59E0B)),
];

final _mockTrendData = [520, 680, 890, 720, 950, 1100, 1250];

// ── 时间范围 ──
class _TimeRangeChip extends StatelessWidget {
  const _TimeRangeChip({required this.selected});
  final String selected;

  @override
  Widget build(BuildContext context) {
    final options = ['近7日', '近30日', '近90日'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((o) {
          final isSel = o == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => HapticFeedback.selectionClick(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSel
                      ? AppTheme.primary.withValues(alpha: 0.15)
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSel ? AppTheme.primary : Colors.transparent,
                  ),
                ),
                child: Text(
                  o,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                    color: isSel ? AppTheme.primary : AppTheme.onSurface,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 指标项 ──
class _StatItem {
  const _StatItem(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

// ── 2x2 指标网格 ──
class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.stats});
  final List<_StatItem> stats;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: stats.map((s) => _StatCard(item: s)).toList(),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.item});
  final _StatItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              const Spacer(),
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: item.color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 概览卡片 ──
class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
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
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── 趋势图区域 ──
class _TrendSection extends StatelessWidget {
  const _TrendSection({required this.data});
  final List<int> data;

  @override
  Widget build(BuildContext context) {
    final maxVal = data.isEmpty ? 1 : data.reduce((a, b) => a > b ? a : b);
    const barWidth = 24.0;

    return Container(
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
          const Text(
            '曝光趋势',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(data.length, (i) {
                final h = maxVal > 0 ? (data[i] / maxVal * 90) + 10 : 10.0;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 600 + i * 80),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => Container(
                        width: barWidth,
                        height: h * v,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.5),
                              AppTheme.primary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ['一', '二', '三', '四', '五', '六', '日'][i],
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 转化漏斗 ──
class _FunnelCard extends StatelessWidget {
  const _FunnelCard({
    required this.views,
    required this.likes,
    required this.bookings,
    required this.completed,
  });

  final int views;
  final int likes;
  final int bookings;
  final int completed;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          const Text(
            '转化漏斗',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _FunnelRow('曝光', views, 1.0, const Color(0xFF3498DB)),
          _FunnelRow('喜欢', likes, likes / views, AppTheme.accent),
          _FunnelRow('预约', bookings, bookings / views, AppTheme.primary),
          _FunnelRow('完成', completed, completed / views, AppTheme.success),
        ],
      ),
    );
  }
}

class _FunnelRow extends StatelessWidget {
  const _FunnelRow(this.label, this.count, this.rate, this.color);
  final String label;
  final int count;
  final double rate;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: rate.clamp(0.0, 1.0),
                backgroundColor: color.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
