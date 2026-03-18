import 'dart:ui';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// ScannerScreen：卖家扫码核销页
//
// 功能：
//   · mobile_scanner 全屏摄像头预览
//   · 实时识别 QR 码，防止重复触发
//   · 调用 verify_booking RPC 完成后端核销
//   · 成功：confetti 彩纸 + 弹跳成功卡片
//   · 失败：红色错误反馈 + 重试
// ══════════════════════════════════════════════════════════════

class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final _scannerCtrl = MobileScannerController(
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  late ConfettiController _confettiCtrl;

  // 结果弹出动画
  late AnimationController _resultCtrl;
  late Animation<double> _resultScale;
  late Animation<double> _resultSlide;

  bool _isProcessing = false;
  _ScanResult? _result;

  @override
  void initState() {
    super.initState();

    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 4));

    _resultCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _resultScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _resultCtrl, curve: Curves.elasticOut),
    );
    _resultSlide = Tween<double>(begin: 80, end: 0).animate(
      CurvedAnimation(parent: _resultCtrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scannerCtrl.dispose();
    _confettiCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────
  // 扫码处理
  // ────────────────────────────────────────

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing || _result != null) return;

    final barcode = capture.barcodes.firstOrNull;
    final code = barcode?.rawValue;
    if (code == null || code.isEmpty) return;

    // 格式校验：核销码为 8 位大写字母数字
    if (!RegExp(r'^[A-Z0-9]{8}$').hasMatch(code.trim().toUpperCase())) {
      _showInvalidCode(code);
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      // 调用后端 RPC（核销逻辑完全在数据库执行，前端无法篡改）
      final response = await Supabase.instance.client
          .rpc('verify_booking', params: {'input_code': code.toUpperCase()});

      final json = response as Map<String, dynamic>;
      final success = json['success'] as bool? ?? false;
      final message = json['message'] as String? ?? '';

      if (success) {
        final amount = json['amount'];
        _showSuccess(
          message: message,
          amount: amount != null ? (amount as num).toDouble() : null,
        );
        HapticFeedback.heavyImpact();
      } else {
        _showFailure(message);
        HapticFeedback.vibrate();
      }
    } catch (e) {
      _showFailure('网络错误，请稍后重试');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showSuccess({required String message, double? amount}) {
    setState(() {
      _result = _ScanResult(
        isSuccess: true,
        message: message,
        amount: amount,
      );
    });
    _resultCtrl.forward();
    _confettiCtrl.play();
    // 暂停相机
    _scannerCtrl.stop();
  }

  void _showFailure(String message) {
    setState(() {
      _result = _ScanResult(isSuccess: false, message: message);
    });
    _resultCtrl.forward();
    _scannerCtrl.stop();
  }

  void _showInvalidCode(String code) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('无效格式：$code（核销码为 8 位大写字母数字）'),
        backgroundColor: AppTheme.error,
      ),
    );
  }

  void _retry() {
    _resultCtrl.reset();
    setState(() => _result = null);
    _scannerCtrl.start();
  }

  // ────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 相机预览 ──
          MobileScanner(
            controller: _scannerCtrl,
            onDetect: _onDetect,
          ),

          // ── 扫码框叠加层 ──
          if (_result == null) _ScanOverlay(isProcessing: _isProcessing),

          // ── 返回按钮 ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            child: _BackButton(onTap: () => Navigator.of(context).maybePop()),
          ),

          // ── 核销成功彩纸 ──
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 50,
              gravity: 0.3,
              colors: const [
                AppTheme.primary,
                AppTheme.accent,
                AppTheme.success,
                Color(0xFFFFC107),
                Colors.white,
              ],
            ),
          ),

          // ── 结果卡片 ──
          if (_result != null)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _resultCtrl,
                      builder: (_, __) => Transform.translate(
                        offset: Offset(0, _resultSlide.value),
                        child: Transform.scale(
                          scale: _resultScale.value,
                          child: _ResultCard(
                            result: _result!,
                            onRetry: _retry,
                            onDone: () => Navigator.of(context).maybePop(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 扫码框叠加层
// ══════════════════════════════════════════════════════════════

class _ScanOverlay extends StatefulWidget {
  const _ScanOverlay({required this.isProcessing});
  final bool isProcessing;

  @override
  State<_ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<_ScanOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxSize = size.width * 0.68;

    return Stack(
      children: [
        // 暗色遮罩（挖空中间）
        CustomPaint(
          size: size,
          painter: _OverlayPainter(boxSize: boxSize),
        ),

        // 扫码框
        Center(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final borderColor = widget.isProcessing
                  ? AppTheme.warning
                  : Color.lerp(
                      AppTheme.primary.withOpacity(0.6),
                      Colors.white,
                      _pulse.value,
                    )!;

              return SizedBox(
                width: boxSize,
                height: boxSize,
                child: Stack(
                  children: [
                    // 四角
                    ..._buildCorners(boxSize, borderColor),
                    // 扫描线
                    if (!widget.isProcessing)
                      AnimatedBuilder(
                        animation: _pulseCtrl,
                        builder: (_, __) => Positioned(
                          top: _pulse.value * (boxSize - 2),
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  AppTheme.primary.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (widget.isProcessing)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.warning,
                          strokeWidth: 3,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        // 提示文字
        Positioned(
          bottom: 140,
          left: 0,
          right: 0,
          child: Column(
            children: [
              Text(
                widget.isProcessing ? '核销中...' : '将买家二维码对准框内',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                '核销码将在后台验证，确保安全',
                style: TextStyle(color: Colors.white60, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCorners(double boxSize, Color color) {
    const cornerLength = 24.0;
    const cornerWidth = 3.5;
    const radius = 12.0;

    return [
      // 左上
      _Corner(left: 0, top: 0, hFlip: false, vFlip: false,
          length: cornerLength, width: cornerWidth, radius: radius, color: color),
      // 右上
      _Corner(right: 0, top: 0, hFlip: true, vFlip: false,
          length: cornerLength, width: cornerWidth, radius: radius, color: color),
      // 左下
      _Corner(left: 0, bottom: 0, hFlip: false, vFlip: true,
          length: cornerLength, width: cornerWidth, radius: radius, color: color),
      // 右下
      _Corner(right: 0, bottom: 0, hFlip: true, vFlip: true,
          length: cornerLength, width: cornerWidth, radius: radius, color: color),
    ];
  }
}

class _Corner extends StatelessWidget {
  const _Corner({
    this.left, this.right, this.top, this.bottom,
    required this.hFlip, required this.vFlip,
    required this.length, required this.width,
    required this.radius, required this.color,
  });

  final double? left, right, top, bottom;
  final bool hFlip, vFlip;
  final double length, width, radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left, right: right, top: top, bottom: bottom,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(hFlip ? -1.0 : 1.0, vFlip ? -1.0 : 1.0),
        child: SizedBox(
          width: length + radius,
          height: length + radius,
          child: CustomPaint(
            painter: _CornerPainter(
              length: length, strokeWidth: width,
              radius: radius, color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.length,
    required this.strokeWidth,
    required this.radius,
    required this.color,
  });

  final double length, strokeWidth, radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(0, length)
      ..lineTo(0, radius)
      ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
      ..lineTo(length, 0);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => old.color != color;
}

class _OverlayPainter extends CustomPainter {
  const _OverlayPainter({required this.boxSize});
  final double boxSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black54;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(center: center, width: boxSize, height: boxSize);

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => false;
}

// ══════════════════════════════════════════════════════════════
// 结果卡片
// ══════════════════════════════════════════════════════════════

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.onRetry,
    required this.onDone,
  });

  final _ScanResult result;
  final VoidCallback onRetry;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.82,
      padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: (result.isSuccess ? AppTheme.success : AppTheme.error)
                .withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 图标
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: (result.isSuccess ? AppTheme.success : AppTheme.error)
                  .withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              result.isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              color: result.isSuccess ? AppTheme.success : AppTheme.error,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),

          Text(
            result.isSuccess ? '核销成功！' : '核销失败',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: result.isSuccess ? AppTheme.success : AppTheme.error,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            result.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.onSurfaceVariant,
            ),
          ),

          if (result.isSuccess && result.amount != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.success.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.payments_rounded, color: AppTheme.success, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '¥${result.amount!.toStringAsFixed(2)} 即将结算到账',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          Row(
            children: [
              if (!result.isSuccess)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetry,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('重新扫码'),
                  ),
                ),
              if (!result.isSuccess) const SizedBox(width: 12),
              Expanded(
                flex: result.isSuccess ? 1 : 1,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: result.isSuccess ? AppTheme.success : AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    result.isSuccess ? '完成' : '返回',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black54,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24),
        ),
        child: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

// ── 数据类 ──
class _ScanResult {
  const _ScanResult({
    required this.isSuccess,
    required this.message,
    this.amount,
  });

  final bool isSuccess;
  final String message;
  final double? amount;
}
