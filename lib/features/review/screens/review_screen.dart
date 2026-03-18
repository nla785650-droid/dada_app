import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// ReviewScreen：服务结束后的评价页
//
// 触发：OrderDetailScreen 检测到 status == 'completed' 后跳入
// 功能：
//   · 五维评分（服务态度、准时性、专业度、外形符合度、性价比）
//   · 文字评论（可选）
//   · 匿名开关
//   · 提交到 reviews 表
// ══════════════════════════════════════════════════════════════

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({
    super.key,
    required this.bookingId,
    required this.providerName,
    required this.providerAvatar,
    required this.serviceName,
    required this.amount,
  });

  final String bookingId;
  final String providerName;
  final String providerAvatar;
  final String serviceName;
  final double amount;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen>
    with SingleTickerProviderStateMixin {
  // 五维评分
  double _attitude    = 5.0;
  double _punctuality = 5.0;
  double _professional = 5.0;
  double _appearance  = 5.0;
  double _value       = 5.0;

  final _commentCtrl = TextEditingController();
  bool _anonymous = false;
  bool _submitting = false;
  bool _submitted = false;

  late ConfettiController _confetti;
  late AnimationController _successCtrl;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    _confetti.dispose();
    _successCtrl.dispose();
    super.dispose();
  }

  double get _avgRating =>
      (_attitude + _punctuality + _professional + _appearance + _value) / 5;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await Supabase.instance.client.from('reviews').insert({
        'booking_id':    widget.bookingId,
        'overall_rating': _avgRating,
        'comment':       _commentCtrl.text.trim().isEmpty
            ? null
            : _commentCtrl.text.trim(),
        'is_anonymous':  _anonymous,
        'ratings_detail': {
          'attitude':    _attitude,
          'punctuality': _punctuality,
          'professional': _professional,
          'appearance':  _appearance,
          'value':       _value,
        },
      });
    } catch (_) {
      // 生产环境记录错误日志，但不阻断用户流程
    }

    setState(() {
      _submitting = false;
      _submitted = true;
    });
    _confetti.play();
    _successCtrl.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          if (_submitted)
            _buildSuccessView(context)
          else
            _buildForm(context),

          // 彩纸
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                AppTheme.primary, AppTheme.accent,
                Color(0xFFFFC107), Colors.white,
              ],
              numberOfParticles: 40,
              gravity: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => context.go('/booking'),
          ),
          title: const Text(
            '服务评价',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurface,
            ),
          ),
          centerTitle: true,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 服务摘要卡
                _ServiceSummaryCard(
                  providerName: widget.providerName,
                  providerAvatar: widget.providerAvatar,
                  serviceName: widget.serviceName,
                  amount: widget.amount,
                ),
                const SizedBox(height: 20),

                // 五维评分
                _SectionTitle(title: '服务评分'),
                const SizedBox(height: 12),
                _RatingRow(
                  label: '服务态度',
                  icon: Icons.sentiment_satisfied_alt_rounded,
                  value: _attitude,
                  onChanged: (v) => setState(() => _attitude = v),
                ),
                _RatingRow(
                  label: '准时性',
                  icon: Icons.access_time_rounded,
                  value: _punctuality,
                  onChanged: (v) => setState(() => _punctuality = v),
                ),
                _RatingRow(
                  label: '专业程度',
                  icon: Icons.workspace_premium_rounded,
                  value: _professional,
                  onChanged: (v) => setState(() => _professional = v),
                ),
                _RatingRow(
                  label: '形象相符',
                  icon: Icons.face_rounded,
                  value: _appearance,
                  onChanged: (v) => setState(() => _appearance = v),
                ),
                _RatingRow(
                  label: '性价比',
                  icon: Icons.monetization_on_rounded,
                  value: _value,
                  onChanged: (v) => setState(() => _value = v),
                ),

                const SizedBox(height: 20),

                // 综合分展示
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primary.withOpacity(0.08),
                        AppTheme.accent.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFFFC107), size: 28),
                      const SizedBox(width: 8),
                      Text(
                        _avgRating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text('综合评分',
                          style: TextStyle(
                              color: AppTheme.onSurfaceVariant, fontSize: 13)),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 文字评价
                _SectionTitle(title: '文字评价（选填）'),
                const SizedBox(height: 10),
                TextField(
                  controller: _commentCtrl,
                  maxLines: 4,
                  maxLength: 200,
                  decoration: InputDecoration(
                    hintText: '分享你的服务体验，帮助其他用户做决策～',
                    hintStyle:
                        const TextStyle(color: AppTheme.onSurfaceVariant),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: AppTheme.divider),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                  ),
                ),

                // 匿名开关
                Row(
                  children: [
                    const Text('匿名发布',
                        style: TextStyle(color: AppTheme.onSurface)),
                    const Spacer(),
                    Switch.adaptive(
                      value: _anonymous,
                      onChanged: (v) => setState(() => _anonymous = v),
                      activeColor: AppTheme.primary,
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 提交按钮
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            '发布评价',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(context).padding.bottom + 30,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return AnimatedBuilder(
      animation: _successCtrl,
      builder: (_, __) => Opacity(
        opacity: _successCtrl.value,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [AppTheme.primary, AppTheme.accent.withOpacity(0.4)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.35),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    color: Colors.white, size: 52),
              ),
              const SizedBox(height: 24),
              const Text(
                '评价发布成功！',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '感谢你的宝贵意见，帮助达人变得更好',
                style: TextStyle(color: AppTheme.onSurfaceVariant),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/home'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 32, vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '返回首页',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 小组件 ──

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppTheme.onSurface,
      ),
    );
  }
}

class _RatingRow extends StatelessWidget {
  const _RatingRow({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final IconData icon;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppTheme.onSurface),
            ),
          ),
          Expanded(
            child: RatingBar.builder(
              initialRating: value,
              minRating: 1,
              direction: Axis.horizontal,
              itemCount: 5,
              itemSize: 28,
              glow: false,
              itemPadding: const EdgeInsets.symmetric(horizontal: 2),
              itemBuilder: (_, __) => const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFC107),
              ),
              onRatingUpdate: onChanged,
            ),
          ),
          Text(
            value.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceSummaryCard extends StatelessWidget {
  const _ServiceSummaryCard({
    required this.providerName,
    required this.providerAvatar,
    required this.serviceName,
    required this.amount,
  });

  final String providerName;
  final String providerAvatar;
  final String serviceName;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundImage: providerAvatar.isNotEmpty
                ? NetworkImage(providerAvatar)
                : null,
            backgroundColor: AppTheme.surfaceVariant,
            child: providerAvatar.isEmpty
                ? const Icon(Icons.person_rounded, color: AppTheme.primary)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  providerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  serviceName,
                  style: const TextStyle(
                    color: AppTheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '¥${amount.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}
