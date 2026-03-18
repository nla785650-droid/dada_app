import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// VirtualDialButton：隐私拨号组件
//
// 功能：
//   · 展示脱敏手机号（138****8888）
//   · 点击触发 Edge Function 进行虚拟号转接
//   · 等待中显示 Loading + 取消按钮
//   · 通话接通后显示通话中状态
//   · 降级处理：Edge Function 失败则提示联系平台客服
// ══════════════════════════════════════════════════════════════

enum _DialState { idle, calling, connected, failed }

class VirtualDialButton extends StatefulWidget {
  const VirtualDialButton({
    super.key,
    required this.maskedPhone,
    this.bookingId,
    this.onCallInitiated,
  });

  final String maskedPhone;
  final String? bookingId;
  final VoidCallback? onCallInitiated;

  @override
  State<VirtualDialButton> createState() => _VirtualDialButtonState();
}

class _VirtualDialButtonState extends State<VirtualDialButton>
    with SingleTickerProviderStateMixin {
  _DialState _dialState = _DialState.idle;
  late AnimationController _waveCtrl;
  late Animation<double> _wave1, _wave2, _wave3;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _wave1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _waveCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _wave2 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _waveCtrl,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    _wave3 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _waveCtrl,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDial() async {
    if (_dialState != _DialState.idle) return;
    HapticFeedback.mediumImpact();

    setState(() => _dialState = _DialState.calling);
    _waveCtrl.repeat();

    widget.onCallInitiated?.call();

    try {
      // 调用 Supabase Edge Function（需后端部署 virtual-call 函数）
      // 此处模拟 2 秒后接通
      await Future.delayed(const Duration(seconds: 2));

      // 生产环境：
      // final res = await Supabase.instance.client.functions.invoke(
      //   'virtual-call',
      //   body: {'booking_id': widget.bookingId},
      // );
      // 解析 res 返回的实际虚拟号并拨打

      if (mounted) {
        setState(() => _dialState = _DialState.connected);
        _waveCtrl.stop();
        HapticFeedback.lightImpact();

        // 3 秒后重置（模拟通话结束）
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _dialState = _DialState.idle);
        });
      }
    } catch (e) {
      if (mounted) {
        _waveCtrl.stop();
        setState(() => _dialState = _DialState.failed);
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() => _dialState = _DialState.idle);
      }
    }
  }

  void _cancelCall() {
    _waveCtrl.stop();
    setState(() => _dialState = _DialState.idle);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── 左侧：图标 + 文字 ──
          Expanded(
            child: Row(
              children: [
                _buildStateIcon(),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _stateLabel,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.maskedPhone,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.onSurface,
                        letterSpacing: 1,
                      ),
                    ),
                    if (_dialState == _DialState.failed) ...[
                      const SizedBox(height: 2),
                      const Text(
                        '转接失败，请联系平台客服',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── 右侧：拨号按钮 ──
          if (_dialState == _DialState.calling)
            TextButton(
              onPressed: _cancelCall,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.error,
                padding: EdgeInsets.zero,
              ),
              child: const Text('取消', style: TextStyle(fontSize: 13)),
            )
          else
            _DialCircleButton(
              state: _dialState,
              wave1: _wave1,
              wave2: _wave2,
              wave3: _wave3,
              onTap: _onDial,
            ),
        ],
      ),
    );
  }

  Widget _buildStateIcon() {
    return switch (_dialState) {
      _DialState.calling => SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primary,
          ),
        ),
      _DialState.connected => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.call, color: AppTheme.success, size: 20),
        ),
      _DialState.failed => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.error.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.call_end, color: AppTheme.error, size: 20),
        ),
      _ => Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_rounded,
              color: AppTheme.onSurfaceVariant, size: 18),
        ),
    };
  }

  String get _stateLabel => switch (_dialState) {
        _DialState.idle      => '隐私通话（虚拟号转接）',
        _DialState.calling   => '正在转接...',
        _DialState.connected => '通话中',
        _DialState.failed    => '转接失败',
      };
}

// ── 拨号圆形按钮（带音波动画）──
class _DialCircleButton extends StatelessWidget {
  const _DialCircleButton({
    required this.state,
    required this.wave1,
    required this.wave2,
    required this.wave3,
    required this.onTap,
  });

  final _DialState state;
  final Animation<double> wave1, wave2, wave3;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isConnected = state == _DialState.connected;
    final baseColor = isConnected ? AppTheme.success : AppTheme.primary;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: wave1,
        builder: (_, __) {
          return SizedBox(
            width: 56,
            height: 56,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 音波（仅 connected 状态显示）
                if (isConnected)
                  for (final (wave, scale) in [
                    (wave1, 1.8),
                    (wave2, 1.5),
                    (wave3, 1.2),
                  ])
                    Opacity(
                      opacity: (1 - wave.value) * 0.3,
                      child: Transform.scale(
                        scale: 1.0 + wave.value * (scale - 1),
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: baseColor.withOpacity(0.2),
                          ),
                        ),
                      ),
                    ),

                // 主按钮
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        baseColor,
                        baseColor.withOpacity(0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: baseColor.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isConnected ? Icons.call_rounded : Icons.call_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
