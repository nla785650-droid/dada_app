import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// PublishCenterScreen：发布中心（中间 Tab）
//
// 功能分区：
//   · 发布动态（分享内容/作品）
//   · 发布需求（买家发出委托需求）
//   · 管理档期（达人排班）
//   · 进行中的行程（达人专属：快速入口安全中心）
// ══════════════════════════════════════════════════════════════

// Mock：是否为达人（生产环境从 Supabase profiles 读取）
final _isProviderMock = true;

class PublishCenterScreen extends ConsumerStatefulWidget {
  const PublishCenterScreen({super.key});

  @override
  ConsumerState<PublishCenterScreen> createState() =>
      _PublishCenterScreenState();
}

class _PublishCenterScreenState extends ConsumerState<PublishCenterScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _enterCtrl;
  late Animation<double> _enterScale;
  late Animation<double> _enterOpacity;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _enterScale = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOutCubic),
    );
    _enterOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _enterCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: AnimatedBuilder(
        animation: _enterCtrl,
        builder: (_, child) => FadeTransition(
          opacity: _enterOpacity,
          child: ScaleTransition(scale: _enterScale, child: child),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverHeader(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 达人专属：进行中行程入口
                    if (_isProviderMock) ...[
                      _ActiveTripBanner(),
                      const SizedBox(height: 16),
                    ],

                    // 主发布卡片区
                    _buildPublishGrid(context),
                    const SizedBox(height: 20),

                    // 快捷工具区
                    _buildQuickTools(context),
                    const SizedBox(height: 20),

                    // 近期动态预览
                    _buildRecentActivity(),

                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 80,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      expandedHeight: 100,
      backgroundColor: AppTheme.surface,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.of(context).padding.top + 12, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (b) =>
                            AppTheme.primaryGradient.createShader(b),
                        child: const Text(
                          '发布中心',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      const Text(
                        '分享你的才华，开始接单赚钱',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  // AI 实验室入口
                  GestureDetector(
                    onTap: () => context.push('/ai-lab'),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFA78BFA)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('🧪', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: AppTheme.divider),
      ),
    );
  }

  Widget _buildPublishGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: '我要发布'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: _PublishCard(
                icon: '✨',
                title: '发布动态',
                subtitle: '分享作品、日常、Cos成果',
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF9B7FE8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: () => _showPublishSheet(context, '发布动态'),
                isLarge: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  _PublishCard(
                    icon: '📋',
                    title: '发布需求',
                    subtitle: '找达人帮你完成委托',
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B9D), Color(0xFFFF8E53)],
                    ),
                    onTap: () => _showPublishSheet(context, '发布需求'),
                    isLarge: false,
                  ),
                  const SizedBox(height: 10),
                  _PublishCard(
                    icon: '📅',
                    title: '管理档期',
                    subtitle: '编辑可接单时间',
                    gradient: const LinearGradient(
                      colors: [Color(0xFF11998E), Color(0xFF38EF7D)],
                    ),
                    onTap: () => _showScheduleManager(context),
                    isLarge: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickTools(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: '快捷工具'),
        const SizedBox(height: 12),
        Row(
          children: [
            _QuickTool(
              icon: Icons.bar_chart_rounded,
              label: '数据看板',
              color: const Color(0xFF3498DB),
              onTap: () => context.push('/dashboard'),
            ),
            _QuickTool(
              icon: Icons.receipt_long_rounded,
              label: '我的订单',
              color: AppTheme.primary,
              onTap: () => context.push('/orders'),
            ),
            _QuickTool(
              icon: Icons.rate_review_rounded,
              label: '收到的评价',
              color: const Color(0xFFF59E0B),
              onTap: () => context.push('/provider-reviews'),
            ),
            _QuickTool(
              icon: Icons.storefront_rounded,
              label: '服务管理',
              color: AppTheme.success,
              onTap: () => context.push('/onboarding'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionTitle(title: '近期动态'),
            TextButton(
              onPressed: () {},
              child: const Text('全部',
                  style: TextStyle(fontSize: 12, color: AppTheme.primary)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 近期动态列表（mock）
        ..._mockActivities.map((a) => _ActivityRow(activity: a)),
      ],
    );
  }

  void _showPublishSheet(BuildContext context, String type) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PublishFormSheet(type: type),
    );
  }

  void _showScheduleManager(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ScheduleManagerSheet(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 达人进行中行程横幅
// ══════════════════════════════════════════════════════════════

class _ActiveTripBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Mock 进行中的行程数据（始终展示）

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        context.push('/fulfillment/mock-booking-active?role=provider');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D2137), Color(0xFF1A3A5C)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // 脉冲盾牌
            _PulsingIcon(),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        '进行中的行程',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 8),
                      _LiveBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🌸 小樱 · 汉服摄影 · 已到达',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.5)),
              ),
              child: const Text(
                '安全中心 →',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 46, height: 46,
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(
            alpha: 0.1 + _ctrl.value * 0.15,
          ),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: const Icon(Icons.shield_rounded,
            color: AppTheme.primary, size: 24),
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: AppTheme.error),
          SizedBox(width: 3),
          Text(
            'LIVE',
            style: TextStyle(
              color: AppTheme.error,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 发布卡片
// ══════════════════════════════════════════════════════════════

class _PublishCard extends StatelessWidget {
  const _PublishCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    required this.isLarge,
  });

  final String icon;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final VoidCallback onTap;
  final bool isLarge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      child: Container(
        height: isLarge ? 160 : 74,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withValues(alpha: 0.3),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isLarge
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.center,
          children: [
            if (isLarge) Text(icon, style: const TextStyle(fontSize: 32)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isLarge)
                  Row(
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                if (isLarge) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── 快捷工具 ──
class _QuickTool extends StatelessWidget {
  const _QuickTool({
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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.2)),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 近期动态 ──
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});
  final _Activity activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: activity.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(activity.icon, color: activity.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(activity.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                Text(activity.subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.onSurfaceVariant)),
              ],
            ),
          ),
          Text(activity.time,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 发布表单 BottomSheet
// ══════════════════════════════════════════════════════════════

class _PublishFormSheet extends StatelessWidget {
  const _PublishFormSheet({required this.type});
  final String type;

  @override
  Widget build(BuildContext context) {
    final isDynamic = type == '发布动态';
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // 把手
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            type,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // 图片上传区
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.divider,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded,
                              size: 32, color: AppTheme.primary),
                          SizedBox(height: 8),
                          Text('点击添加图片/视频',
                              style: TextStyle(color: AppTheme.primary)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: isDynamic
                          ? '分享你的故事、作品或心情...'
                          : '描述你的需求，越详细越好...',
                      filled: true,
                      fillColor: AppTheme.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      hintStyle: const TextStyle(
                          color: AppTheme.onSurfaceVariant),
                    ),
                  ),
                  if (!isDynamic) ...[
                    const SizedBox(height: 14),
                    TextField(
                      decoration: InputDecoration(
                        hintText: '预算（元）',
                        filled: true,
                        fillColor: AppTheme.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.attach_money_rounded,
                            color: AppTheme.onSurfaceVariant),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.mediumImpact();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$type已发布 ✨'),
                            backgroundColor: AppTheme.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: Text(
                        '发布$type',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 档期管理 BottomSheet
// ══════════════════════════════════════════════════════════════

class _ScheduleManagerSheet extends StatelessWidget {
  const _ScheduleManagerSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            '管理档期',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            '设置你的可接单时间，买家可在该时段预约你',
            style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 12),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Divider(color: AppTheme.divider),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // 快速生成档期按钮
                _ScheduleQuickAction(
                  icon: Icons.auto_awesome_rounded,
                  title: '智能生成本周档期',
                  subtitle: '系统根据历史习惯自动填充',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('本周档期已生成 ✅'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                _ScheduleQuickAction(
                  icon: Icons.block_rounded,
                  title: '设置休息日',
                  subtitle: '选择不接单的日期',
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 10),
                _ScheduleQuickAction(
                  icon: Icons.calendar_view_week_rounded,
                  title: '查看本周档期',
                  subtitle: '可视化时间格查看空余时段',
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text('完成',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleQuickAction extends StatelessWidget {
  const _ScheduleQuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.onSurfaceVariant, size: 18),
          ],
        ),
      ),
    );
  }
}

// ── 辅助组件 ──
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        color: AppTheme.onSurface,
      ),
    );
  }
}

// ── Mock 数据 ──
class _Activity {
  const _Activity({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.time,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String time;
}

final _mockActivities = [
  const _Activity(
    icon: Icons.favorite_rounded,
    title: '收到新的喜欢',
    subtitle: '用户「凉月」喜欢了你的作品',
    color: AppTheme.accent,
    time: '5分钟前',
  ),
  const _Activity(
    icon: Icons.receipt_long_rounded,
    title: '新预约订单',
    subtitle: '汉服摄影 · ¥350 · 3月22日 14:00',
    color: AppTheme.primary,
    time: '1小时前',
  ),
  const _Activity(
    icon: Icons.star_rounded,
    title: '收到5星好评',
    subtitle: '「摄影技术一流，非常专业👍」',
    color: const Color(0xFFF59E0B),
    time: '昨天',
  ),
];
