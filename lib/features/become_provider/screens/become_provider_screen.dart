import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/become_provider_provider.dart';
import 'step1_type_selection.dart';
import 'step2_dynamic_form.dart';
import 'step3_agreement.dart';

/// 成为达人入驻主屏幕（三步 PageView）
class BecomeProviderScreen extends ConsumerStatefulWidget {
  const BecomeProviderScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<BecomeProviderScreen> createState() =>
      _BecomeProviderScreenState();
}

class _BecomeProviderScreenState extends ConsumerState<BecomeProviderScreen> {
  final _pageController = PageController();

  static const _stepTitles = ['选择达人类型', '填写资料', '确认协议'];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _animateToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(becomeProviderProvider);

    // 成功状态跳到结果页
    if (state.isSuccess) {
      return const _SuccessScreen();
    }

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Stack(
        children: [
          // ── 渐变背景装饰 ──
          Positioned(
            top: -80,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primary.withValues(alpha: 0.06),
              ),
            ),
          ),
          Column(
            children: [
              _buildAppBar(context, state),
              _buildStepIndicator(state.currentStep),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Step 1 - 类型选择
                    Step1TypeSelection(
                      onSelect: (type) {
                        ref
                            .read(becomeProviderProvider.notifier)
                            .selectType(type);
                        _animateToPage(1);
                      },
                    ),
                    // Step 2 - 动态表单
                    Step2DynamicForm(
                      onNext: () {
                        final ok = ref
                            .read(becomeProviderProvider.notifier)
                            .goNext();
                        if (ok) _animateToPage(2);
                      },
                      onBack: () {
                        ref
                            .read(becomeProviderProvider.notifier)
                            .goBack();
                        _animateToPage(0);
                      },
                    ),
                    // Step 3 - 协议 + 提交
                    Step3Agreement(
                      userId: widget.userId,
                      onBack: () {
                        ref
                            .read(becomeProviderProvider.notifier)
                            .goBack();
                        _animateToPage(1);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          // ── 上传中全屏遮罩 ──
          if (state.isUploading || state.isSubmitting)
            _UploadingOverlay(
              progress: state.uploadProgress,
              isSubmitting: state.isSubmitting,
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, BecomeProviderState state) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () => _showExitDialog(context),
            ),
            Expanded(
              child: Text(
                state.currentStep < _stepTitles.length
                    ? _stepTitles[state.currentStep]
                    : '成为达人',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            // 步骤标记
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${state.currentStep + 1} / 3',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int currentStep) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: List.generate(3, (i) {
          final done = i < currentStep;
          final active = i == currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: done || active
                          ? AppTheme.primary
                          : AppTheme.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: 6),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showExitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('确认退出？'),
        content: const Text('退出后已填写的内容将不会保存'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('继续填写'),
          ),
          TextButton(
            onPressed: () {
              ref.read(becomeProviderProvider.notifier).reset();
              Navigator.pop(context); // 关闭对话框
              Navigator.pop(context); // 关闭屏幕
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('退出'),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// 上传中全屏遮罩
// ──────────────────────────────────────────

class _UploadingOverlay extends StatelessWidget {
  const _UploadingOverlay({
    required this.progress,
    required this.isSubmitting,
  });

  final double progress;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        color: Colors.white.withValues(alpha: 0.85),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 动态图标
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  isSubmitting
                      ? Icons.cloud_done_rounded
                      : Icons.cloud_upload_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isSubmitting ? '正在提交申请…' : '正在上传图片…',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSubmitting
                  ? '即将完成，请稍候'
                  : '${(progress * 100).toInt()}%  已上传',
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 56),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppTheme.divider,
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.primary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 提交成功页
// ──────────────────────────────────────────

class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            // 成功动画图标
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppTheme.primary, AppTheme.accent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.35),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 36),
            const Text(
              '申请已提交！',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 48),
              child: Text(
                '我们将在 1-3 个工作日内完成审核\n审核结果将通过站内消息通知你',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.onSurfaceVariant,
                  height: 1.7,
                ),
              ),
            ),
            const SizedBox(height: 32),
            // 审核进度卡片
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    _ReviewStep(
                      icon: Icons.check_circle_rounded,
                      label: '申请已提交',
                      done: true,
                    ),
                    _ReviewDivider(),
                    _ReviewStep(
                      icon: Icons.manage_search_rounded,
                      label: '平台审核中',
                      done: false,
                      active: true,
                    ),
                    _ReviewDivider(),
                    _ReviewStep(
                      icon: Icons.verified_rounded,
                      label: '成为认证达人',
                      done: false,
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil(
                  (route) => route.isFirst,
                ),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  '返回首页',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    required this.icon,
    required this.label,
    required this.done,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 22,
          color: done
              ? AppTheme.success
              : active
                  ? AppTheme.primary
                  : AppTheme.divider,
        ),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active || done ? FontWeight.w600 : FontWeight.w400,
            color: active || done
                ? AppTheme.onSurface
                : AppTheme.onSurfaceVariant,
          ),
        ),
        if (active) ...[
          const SizedBox(width: 8),
          const SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppTheme.primary,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReviewDivider extends StatelessWidget {
  const _ReviewDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 10),
      child: SizedBox(
        height: 20,
        child: VerticalDivider(width: 2, color: AppTheme.divider),
      ),
    );
  }
}
