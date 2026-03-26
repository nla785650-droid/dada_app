import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// PureGet 安全审计视觉规范：深蓝科技风，与主站粉紫社交区分
class PureGetAuditTheme {
  PureGetAuditTheme._();

  static const Color deepBlue = Color(0xFF0A1929);
  static const Color panel = Color(0xFF132F4C);
  static const Color accentCyan = Color(0xFF29B6F6);
  static const Color accentTeal = Color(0xFF26C6DA);
  static const Color scrim = Color(0xCC0A1929);
  static const Color textPrimary = Color(0xFFE3F2FD);
  static const Color textSecondary = Color(0xFF90CAF9);
  static const Color warningAmber = Color(0xFFFFB74D);
  static const Color warningOverlay = Color(0x99E65100);
  static const Color passGreen = Color(0xFF66BB6A);
}

/// 顶部扫描线动画层 + 文案 + 自定义进度环
class PureGetAuditingLayer extends StatelessWidget {
  const PureGetAuditingLayer({
    super.key,
    required this.scanProgress,
  });

  /// 0–1 循环，驱动扫描带纵向移动
  final Animation<double> scanProgress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (kIsWeb)
            Container(color: PureGetAuditTheme.scrim)
          else
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 1.2, sigmaY: 1.2),
              child: Container(
                color: PureGetAuditTheme.scrim,
              ),
            ),
          AnimatedBuilder(
            animation: scanProgress,
            builder: (context, _) {
              return CustomPaint(
                painter: _ScanBeamPainter(
                  t: scanProgress.value,
                  beamColor: PureGetAuditTheme.accentCyan,
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    strokeCap: StrokeCap.round,
                    color: PureGetAuditTheme.accentCyan,
                    backgroundColor:
                        PureGetAuditTheme.panel.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'PureGet 正在进行安全审计与真身鉴伪…',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: PureGetAuditTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    shadows: [
                      Shadow(
                        color: PureGetAuditTheme.accentCyan.withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Agent 实时分析 · 异步任务不阻塞界面',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: PureGetAuditTheme.textSecondary.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
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

class _ScanBeamPainter extends CustomPainter {
  _ScanBeamPainter({
    required this.t,
    required this.beamColor,
  });

  final double t;
  final Color beamColor;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * t;
    final h = size.height * 0.14;
    final rect = Rect.fromLTWH(0, (y - h / 2).clamp(0.0, size.height), size.width, h);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          beamColor.withValues(alpha: 0),
          beamColor.withValues(alpha: 0.45),
          beamColor.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, paint);

    final linePaint = Paint()
      ..color = beamColor.withValues(alpha: 0.85)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanBeamPainter oldDelegate) {
    return oldDelegate.t != t || oldDelegate.beamColor != beamColor;
  }
}

/// 审计通过后右上角勋章
class PureGetVerifiedBadge extends StatelessWidget {
  const PureGetVerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              PureGetAuditTheme.passGreen,
              PureGetAuditTheme.passGreen.withValues(alpha: 0.85),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: PureGetAuditTheme.passGreen.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: Colors.white, size: 18),
            SizedBox(width: 4),
            Text(
              'Verified',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 疑似伪造时的警示蒙层（可穿透看见底层图）
class PureGetSuspectTintLayer extends StatelessWidget {
  const PureGetSuspectTintLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.bottomCenter,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              PureGetAuditTheme.warningOverlay.withValues(alpha: 0.25),
              PureGetAuditTheme.warningOverlay.withValues(alpha: 0.65),
            ],
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.warning_amber_rounded,
                color: PureGetAuditTheme.warningAmber, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'PureGet：疑似 AI 生成 / 伪造特征',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.95),
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

/// Agent 思考日志（纯色深色条，非粉系）
class PureGetAgentLogPanel extends StatelessWidget {
  const PureGetAgentLogPanel({
    super.key,
    required this.line1,
    required this.line2,
    required this.line3,
  });

  final String line1;
  final String line2;
  final String line3;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: PureGetAuditTheme.deepBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: PureGetAuditTheme.accentCyan.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: PureGetAuditTheme.accentCyan.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded,
                  size: 18, color: PureGetAuditTheme.accentCyan),
              const SizedBox(width: 8),
              Text(
                'PureGet Agent',
                style: TextStyle(
                  color: PureGetAuditTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _logLine(line1),
          const SizedBox(height: 6),
          _logLine(line2),
          const SizedBox(height: 6),
          _logLine(line3, emphasis: true),
        ],
      ),
    );
  }

  Widget _logLine(String text, {bool emphasis = false}) {
    return Text(
      text.isEmpty ? ' ' : text,
      style: TextStyle(
        color: emphasis
            ? PureGetAuditTheme.accentTeal
            : PureGetAuditTheme.textSecondary,
        fontSize: emphasis ? 13 : 12,
        fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
        height: 1.4,
        fontFamily: 'monospace',
        fontFamilyFallback: const ['Roboto Mono', 'Courier'],
      ),
    );
  }
}

Future<void> showPureGetAigcWarningDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      backgroundColor: PureGetAuditTheme.panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: PureGetAuditTheme.warningAmber.withValues(alpha: 0.6),
        ),
      ),
      title: Row(
        children: [
          Icon(Icons.shield_moon_rounded,
              color: PureGetAuditTheme.warningAmber, size: 26),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'PureGet 安全提示',
              style: TextStyle(
                color: PureGetAuditTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: const Text(
        '检测到该图片具有明显的 AIGC 生成特征，可能违反社区真实性原则，请更换真实照片。',
        style: TextStyle(
          color: PureGetAuditTheme.textSecondary,
          height: 1.5,
          fontSize: 14,
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: PureGetAuditTheme.accentCyan,
            foregroundColor: PureGetAuditTheme.deepBlue,
          ),
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('我知道了'),
        ),
      ],
    ),
  );
}
