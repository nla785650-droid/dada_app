import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/provider_application_model.dart';
import '../../become_provider/screens/become_provider_screen.dart';
import '../../verification/screens/verification_screen.dart';
import '../../verification/widgets/verified_badge.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  // 模拟当前用户数据（接入 Supabase 后替换）
  static const _mockUserId = 'mock_user_123';
  static const _mockIsVerified = false;
  // 模拟当前入驻状态（接入后从 profiles 表读取）
  static const _mockVerificationStatus = VerificationStatus.unapplied;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverHeader(context),
          SliverToBoxAdapter(
            child: _buildStatsRow(),
          ),
          SliverToBoxAdapter(
            child: _buildMenuSection(),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 80,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppTheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // 渐变背景
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primary, AppTheme.accent],
                ),
              ),
            ),
            // 装饰圆
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            // 用户信息
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                children: [
                  // 头像（带真身认证徽章）
                  AvatarWithVerification(
                    avatarUrl: null,
                    isVerified: _mockIsVerified,
                    size: 72,
                    onTap: () {},
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                      const Text(
                        '搭哒用户',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '✨ 二次元爱好者',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 13,
                            ),
                          ),
                          if (_mockIsVerified) ...[
                            const SizedBox(width: 6),
                            const VerifiedBadge(size: 14, showLabel: true),
                          ],
                        ],
                      ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_rounded,
                      color: Colors.white,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        children: [
          Expanded(
            child: _StatItem(label: '关注', value: '128'),
          ),
          _Divider(),
          Expanded(
            child: _StatItem(label: '粉丝', value: '256'),
          ),
          _Divider(),
          Expanded(
            child: _StatItem(label: '订单', value: '12'),
          ),
          _Divider(),
          Expanded(
            child: _StatItem(label: '收藏', value: '89'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Builder(builder: (context) => Column(
      children: [
        _MenuGroupWithActions(
          title: '我的服务',
          items: [
            _MenuItemData(
              icon: Icons.receipt_long_rounded,
              label: '我的订单',
              color: AppTheme.primary,
              onTap: () => context.push('/orders'),
            ),
            _MenuItemData(
              icon: Icons.favorite_rounded,
              label: '我的收藏',
              color: AppTheme.accent,
              onTap: () => context.push('/likes'),
            ),
            _MenuItemData(
              icon: Icons.star_rounded,
              label: '我的评价',
              color: AppTheme.warning,
              onTap: () {},
            ),
          ],
        ),
        // ── 达人入驻入口 / 状态卡片 ──
        _ProviderStatusCard(
          status: _mockVerificationStatus,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  const BecomeProviderScreen(userId: _mockUserId),
            ),
          ),
        ),

        // 真身认证入口（未认证时显示）
        if (!_mockIsVerified)
          _VerificationEntryCard(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    const VerificationScreen(userId: _mockUserId),
              ),
            ),
          ),
        _MenuGroupWithActions(
          title: '成为服务方',
          items: [
            _MenuItemData(
              icon: Icons.add_business_rounded,
              label: '发布服务',
              color: AppTheme.success,
              onTap: () {},
            ),
            _MenuItemData(
              icon: Icons.bar_chart_rounded,
              label: '数据中心',
              color: const Color(0xFF3498DB),
              onTap: () {},
            ),
          ],
        ),
        _MenuGroupWithActions(
          title: '设置',
          items: [
            _MenuItemData(
              icon: Icons.notifications_rounded,
              label: '消息通知',
              color: AppTheme.onSurfaceVariant,
              onTap: () {},
            ),
            _MenuItemData(
              icon: Icons.security_rounded,
              label: '隐私设置',
              color: AppTheme.onSurfaceVariant,
              onTap: () {},
            ),
            _MenuItemData(
              icon: Icons.help_outline_rounded,
              label: '帮助与反馈',
              color: AppTheme.onSurfaceVariant,
              onTap: () {},
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error, width: 1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('退出登录'),
          ),
        ),
      ],
    ));
  }
}

// ── 达人入驻状态卡片 ──
class _ProviderStatusCard extends StatelessWidget {
  const _ProviderStatusCard({required this.status, required this.onTap});

  final VerificationStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (status == VerificationStatus.approved) {
      // 已通过：展示达人身份徽章
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.primary.withValues(alpha: 0.12),
              AppTheme.accent.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.25), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.star_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✅ 认证达人',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '你的服务正在平台展示，持续保持好评吧～',
                    style: TextStyle(
                        fontSize: 12, color: AppTheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.onSurfaceVariant),
          ],
        ),
      );
    }

    if (status == VerificationStatus.pending) {
      // 审核中：进度占位 UI
      return Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.hourglass_top_rounded,
                      size: 20, color: AppTheme.warning),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '入驻申请审核中',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      Text(
                        '预计 1-3 个工作日内完成',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    '审核中',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.warning,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // 进度条（假进度动画）
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                value: null, // 无限循环
                minHeight: 4,
                backgroundColor: AppTheme.divider,
                valueColor: AlwaysStoppedAnimation(AppTheme.warning),
              ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 12, color: AppTheme.onSurfaceVariant),
                SizedBox(width: 4),
                Text(
                  '审核通过后，你将收到站内消息通知',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (status == VerificationStatus.rejected) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.error.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: AppTheme.error.withValues(alpha: 0.25), width: 1),
          ),
          child: const Row(
            children: [
              Icon(Icons.cancel_outlined, color: AppTheme.error, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '入驻申请未通过',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.error,
                      ),
                    ),
                    Text(
                      '点击查看原因并重新申请',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: AppTheme.onSurfaceVariant),
            ],
          ),
        ),
      );
    }

    // unapplied：展示入口卡片
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primary, AppTheme.accent],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Center(
                child: Text('🌟', style: TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '成为搭哒达人',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '接单·赚钱·展示才华，立即入驻 ✨',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white70,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 真身认证入口卡片 ──
class _VerificationEntryCard extends StatelessWidget {
  const _VerificationEntryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              const Color(0xFF9B59B6).withValues(alpha: 0.08),
              const Color(0xFFFF6B9D).withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFF9B59B6).withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // 银色渐变盾牌图标
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFE8E8E8),
                    Color(0xFFA0A0B0),
                    Color(0xFFCCCCCC),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '完成真身认证',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    '录制 5 秒真实视频，获取银色「真身认证」徽章\n提升买家信任度，接单率提高 3 倍',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: AppTheme.divider,
    );
  }
}

class _MenuItemData {
  const _MenuItemData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
}

class _MenuGroupWithActions extends StatelessWidget {
  const _MenuGroupWithActions({required this.title, required this.items});

  final String title;
  final List<_MenuItemData> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              return Column(
                children: [
                  ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: items[i].color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(items[i].icon, size: 20, color: items[i].color),
                    ),
                    title: Text(
                      items[i].label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.onSurfaceVariant,
                      size: 20,
                    ),
                    onTap: items[i].onTap,
                  ),
                  if (i < items.length - 1)
                    const Divider(height: 1, indent: 64, color: AppTheme.divider),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
