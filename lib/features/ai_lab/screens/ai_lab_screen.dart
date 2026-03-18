import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// AILabScreen：AI 实验室占位页
//
// 功能规划（需配置 google_generative_ai API Key 后启用）：
//   · AI Coser 形象生成（输入角色描述生成参考图）
//   · 智能推荐达人（基于偏好标签）
//   · 服务日记生成（自动总结行程）
// ══════════════════════════════════════════════════════════════

class AILabScreen extends StatefulWidget {
  const AILabScreen({super.key});

  @override
  State<AILabScreen> createState() => _AILabScreenState();
}

class _AILabScreenState extends State<AILabScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  int _activeFeature = -1;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  final _features = const [
    _AiFeature(
      icon: Icons.auto_awesome_rounded,
      title: 'AI 形象生成',
      desc: '输入角色描述，AI 为你生成参考图',
      gradient: [Color(0xFF6C63FF), Color(0xFFA78BFA)],
      status: 'soon',
    ),
    _AiFeature(
      icon: Icons.psychology_rounded,
      title: '智能达人匹配',
      desc: '基于偏好 AI 推荐最适合你的达人',
      gradient: [Color(0xFFEC4899), Color(0xFFF97316)],
      status: 'soon',
    ),
    _AiFeature(
      icon: Icons.auto_stories_rounded,
      title: '服务日记生成',
      desc: '自动整理行程照片生成精美回忆',
      gradient: [Color(0xFF0EA5E9), Color(0xFF22D3EE)],
      status: 'soon',
    ),
    _AiFeature(
      icon: Icons.chat_bubble_outline_rounded,
      title: '智能破冰助手',
      desc: '根据达人风格生成开场白建议',
      gradient: [Color(0xFF10B981), Color(0xFF34D399)],
      status: 'beta',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── AppBar ──
          SliverAppBar(
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A0A3E), Color(0xFF0D0D1A)],
                  ),
                ),
              ),
            ),
            title: ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Color(0xFF818CF8), Color(0xFFA78BFA)],
              ).createShader(b),
              child: const Text(
                'AI 实验室',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: const Text(
                  '内测中',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          // ── 脉冲 Logo ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: _PulsingOrb(controller: _pulseCtrl),
            ),
          ),

          // ── 副标题 ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Column(
                children: [
                  const Text(
                    '由 Gemini 驱动的创作工具',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '搭哒正在将 AI 融入每一个委托环节\n让创意与连接更自然',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

          // ── 功能卡片 ──
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _FeatureCard(
                  feature: _features[i],
                  isActive: _activeFeature == i,
                  onTap: () => setState(() =>
                      _activeFeature = _activeFeature == i ? -1 : i),
                ),
                childCount: _features.length,
              ),
            ),
          ),

          // ── 底部 CTA ──
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                  16, 24, 16,
                  MediaQuery.of(context).padding.bottom + 100),
              child: Column(
                children: [
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  const Text(
                    '申请内测资格',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '留下你的联系方式，我们将优先通知你',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.4), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('申请已提交！内测开放时将第一时间通知你 🎉')),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6C63FF), Color(0xFFA78BFA)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6C63FF).withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          '✨ 申请内测',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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

// ── 脉冲光球 ──
class _PulsingOrb extends StatelessWidget {
  const _PulsingOrb({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 140,
      child: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, __) {
            final pulse = (math.sin(controller.value * 2 * math.pi) + 1) / 2;
            return Stack(
              alignment: Alignment.center,
              children: [
                // 外光晕
                Container(
                  width: 120 + pulse * 20,
                  height: 120 + pulse * 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF6C63FF).withOpacity(0.15 + pulse * 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                // 内核
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color.lerp(
                            const Color(0xFF818CF8),
                            const Color(0xFFA78BFA),
                            pulse)!,
                        const Color(0xFF6C63FF),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6C63FF).withOpacity(0.5),
                        blurRadius: 24 + pulse * 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 36),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── 功能卡片 ──
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.feature,
    required this.isActive,
    required this.onTap,
  });

  final _AiFeature feature;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isActive
              ? Colors.white.withOpacity(0.08)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? feature.gradient.first.withOpacity(0.5)
                : Colors.white.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: feature.gradient),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(feature.icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        feature.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: feature.status == 'beta'
                              ? const Color(0xFF10B981).withOpacity(0.2)
                              : Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          feature.status == 'beta' ? 'BETA' : '即将上线',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: feature.status == 'beta'
                                ? const Color(0xFF10B981)
                                : Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    feature.desc,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isActive ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
              color: Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AiFeature {
  const _AiFeature({
    required this.icon,
    required this.title,
    required this.desc,
    required this.gradient,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String desc;
  final List<Color> gradient;
  final String status; // 'soon' | 'beta'
}
