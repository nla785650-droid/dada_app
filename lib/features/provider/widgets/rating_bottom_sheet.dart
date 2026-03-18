import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/provider_summary.dart';

// ══════════════════════════════════════════════════════════════
// RatingBottomSheet：快速评分浮层
//
// 入口：
//   · DiscoverScreen ⭐ 按钮
//   · ProviderProfileScreen 星星按钮
// ══════════════════════════════════════════════════════════════

class RatingBottomSheet extends StatefulWidget {
  const RatingBottomSheet({super.key, required this.provider});

  final ProviderSummary provider;

  static Future<double?> show(
    BuildContext context, {
    required ProviderSummary provider,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RatingBottomSheet(provider: provider),
    );
  }

  @override
  State<RatingBottomSheet> createState() => _RatingBottomSheetState();
}

class _RatingBottomSheetState extends State<RatingBottomSheet>
    with SingleTickerProviderStateMixin {
  double _rating = 4.0;
  bool _submitted = false;
  late AnimationController _successCtrl;
  late Animation<double> _successScale;

  @override
  void initState() {
    super.initState();
    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _successScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _successCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    _successCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop(_rating);
  }

  String get _ratingLabel {
    if (_rating >= 5) return '完美无瑕 ✨';
    if (_rating >= 4) return '非常棒 👍';
    if (_rating >= 3) return '还不错 😊';
    if (_rating >= 2) return '一般般 😐';
    return '需要改进 😕';
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        padding: EdgeInsets.fromLTRB(
          24, 8, 24, MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 把手
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            if (_submitted)
              _buildSuccessView()
            else
              _buildRatingForm(),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 标题
        Text(
          '为 ${widget.provider.name} 打分',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.provider.tag,
          style: const TextStyle(color: Colors.white54, fontSize: 13),
        ),
        const SizedBox(height: 24),

        // 星级评分
        RatingBar.builder(
          initialRating: _rating,
          minRating: 1,
          direction: Axis.horizontal,
          itemCount: 5,
          itemSize: 44,
          glow: false,
          itemPadding: const EdgeInsets.symmetric(horizontal: 4),
          itemBuilder: (_, __) => const Icon(
            Icons.star_rounded,
            color: Color(0xFFFFC107),
          ),
          onRatingUpdate: (r) => setState(() => _rating = r),
        ),

        const SizedBox(height: 12),

        // 标签
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            _ratingLabel,
            key: ValueKey(_rating),
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        const SizedBox(height: 28),

        // 提交按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFC107),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: const Text(
              '提交评分',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return AnimatedBuilder(
      animation: _successCtrl,
      builder: (_, __) => Transform.scale(
        scale: _successScale.value,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFFFC107).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFC107),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '感谢你的评价！',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$_rating 星 · $_ratingLabel',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MatchSuccessOverlay：右滑喜欢后的"匹配成功"提示
// 作为 OverlayEntry 叠加在屏幕顶部，2秒后自动消失
// ══════════════════════════════════════════════════════════════

class MatchSuccessOverlay {
  static OverlayEntry? _entry;

  static void show(BuildContext context, {required String name}) {
    _entry?.remove();
    _entry = OverlayEntry(
      builder: (_) => _MatchBanner(
        name: name,
        onDismiss: () {
          _entry?.remove();
          _entry = null;
        },
      ),
    );
    Overlay.of(context).insert(_entry!);
  }
}

class _MatchBanner extends StatefulWidget {
  const _MatchBanner({required this.name, required this.onDismiss});
  final String name;
  final VoidCallback onDismiss;

  @override
  State<_MatchBanner> createState() => _MatchBannerState();
}

class _MatchBannerState extends State<_MatchBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();

    Future.delayed(const Duration(milliseconds: 2200), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 24,
      right: 24,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _opacity,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.accent, AppTheme.primary],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accent.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('💖', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          '匹配成功！',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '你喜欢了 ${widget.name}，快去聊聊吧～',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white70, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
