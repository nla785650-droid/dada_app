import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/meet_safety_session_provider.dart';
import 'meet_safety_hub_sheet.dart';

/// 约见进行中：首页顶栏 + 红色 SOS + 脉冲雷达（不遮挡底导航中间发布钮过多）
class MeetSafetyLayer extends ConsumerStatefulWidget {
  const MeetSafetyLayer({super.key});

  @override
  ConsumerState<MeetSafetyLayer> createState() => _MeetSafetyLayerState();
}

class _MeetSafetyLayerState extends ConsumerState<MeetSafetyLayer>
    with SingleTickerProviderStateMixin {
  late AnimationController _radar;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
  }

  @override
  void dispose() {
    _radar.dispose();
    super.dispose();
  }

  void _syncRadar(bool active) {
    if (active) {
      if (!_radar.isAnimating) _radar.repeat();
    } else {
      _radar.stop();
      _radar.reset();
    }
  }

  static const _hidePaths = {'/login', '/signup', '/verify'};

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(meetSafetySessionProvider);
    final path = GoRouterState.of(context).uri.path;

    _syncRadar(session.active);

    if (!session.active || _hidePaths.contains(path)) {
      return const SizedBox.shrink();
    }

    final top = MediaQuery.paddingOf(context).top;
    final bottomInset = MediaQuery.paddingOf(context).bottom + 72;

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Positioned(
          top: top + 4,
          left: 10,
          right: 10,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showMeetSafetyHubSheet(context, ref),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6F00).withValues(alpha: 0.95),
                      const Color(0xFFE53935).withValues(alpha: 0.92),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE53935).withValues(alpha: 0.45),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      height: 40,
                      child: AnimatedBuilder(
                        animation: _radar,
                        builder: (_, __) {
                          final t = _radar.value;
                          return CustomPaint(
                            painter: _RadarPulsePainter(progress: t),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'PureGet 约见守护',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'PureGet 正在实时守护您的行程，已接入后台审计。',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 11.5,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (session.pendingArrivalNudge) ...[
                            const SizedBox(height: 4),
                            Text(
                              '仍未检测到「确认到达」，请确认您是否安全？',
                              style: TextStyle(
                                color: Colors.yellow.shade100,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Colors.white70),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 16,
          bottom: bottomInset + 52,
          child: _SosFab(onPressed: () => _onSos(context, ref)),
        ),
      ],
    );
  }

  Future<void> _onSos(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF3E2723),
        title: const Row(
          children: [
            Icon(Icons.sos_rounded, color: Colors.white, size: 28),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '一键报警 · PureGet',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Text(
          '将拨打 110，并模拟向 PureGet 云端上报：实时坐标、对方实人摘要与 10 秒环境录音（演示）。',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确认求助'),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;

    await _simulateSosEvidenceCapture(context);

    final uri = Uri.parse('tel:110');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法唤起拨号，请手动拨打 110')),
      );
    }
  }

  /// SOS 时短暂唤醒相机逻辑留空：演示用 SnackBar；真机可在此挂载 CameraController 短录
  Future<void> _simulateSosEvidenceCapture(BuildContext context) async {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('PureGet：正在静默采集现场证据（相机仅在 SOS 流程唤醒，演示）…'),
        duration: Duration(seconds: 2),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!context.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
            '已上报：GPS 31.23°N 121.47°E · 对方 PG 实人档案 · 环境音上传完成（模拟）'),
        duration: Duration(seconds: 3),
        backgroundColor: Color(0xFFB71C1C),
      ),
    );
  }
}

class _SosFab extends StatelessWidget {
  const _SosFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.red.withValues(alpha: 0.6),
      shape: const CircleBorder(),
      color: Colors.red.shade700,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: const SizedBox(
          width: 60,
          height: 60,
          child: Center(
            child: Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadarPulsePainter extends CustomPainter {
  _RadarPulsePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final maxR = size.shortestSide / 2;
    for (var i = 0; i < 3; i++) {
      final t = (progress + i / 3) % 1.0;
      final r = maxR * (0.2 + 0.85 * t);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: (1 - t) * 0.55);
      canvas.drawCircle(c, r, paint);
    }
    final core = Paint()..color = Colors.white.withValues(alpha: 0.95);
    canvas.drawCircle(c, 5, core);
  }

  @override
  bool shouldRepaint(covariant _RadarPulsePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
