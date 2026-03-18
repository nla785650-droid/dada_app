import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/camera_service.dart';

// ══════════════════════════════════════════════════════════════
// ArrivalVerifySheet：实时核验相机底单
//
// 功能：
//   · 强制调用系统相机（禁止相册选择）
//   · 实时显示 GPS 位置文字水印叠加层
//   · 拍摄后自动合成水印（Logo + 时间戳 + 位置）
//   · 预览确认界面：支持重拍 / 确认提交
//   · 提交后照片标记 is_verified_shot = true（不可撤回）
// ══════════════════════════════════════════════════════════════

class ArrivalVerifySheet extends StatefulWidget {
  const ArrivalVerifySheet({
    super.key,
    required this.bookingId,
    required this.locationText,
    this.lat,
    this.lng,
    required this.onSubmit,
  });

  final String bookingId;
  final String locationText;
  final double? lat;
  final double? lng;
  final Future<void> Function(File watermarkedPhoto) onSubmit;

  @override
  State<ArrivalVerifySheet> createState() => _ArrivalVerifySheetState();
}

class _ArrivalVerifySheetState extends State<ArrivalVerifySheet>
    with SingleTickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _hasCaptured = false;
  bool _isProcessing = false;
  File? _capturedFile;
  File? _watermarkedFile;

  late AnimationController _shutterCtrl;
  late Animation<double> _shutterAnim;

  @override
  void initState() {
    super.initState();
    _shutterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _shutterAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shutterCtrl, curve: Curves.easeOut),
    );
    _initCamera();
  }

  Future<void> _initCamera() async {
    final granted = await CameraService.requestCameraPermission();
    if (!granted) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // 优先使用后置摄像头（实地打卡，后置更真实可信）
    final camera = CameraService.getBackCamera() ?? CameraService.getFrontCamera();
    if (camera == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final ctrl = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await ctrl.initialize();
      if (mounted) {
        setState(() {
          _controller = ctrl;
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('相机初始化失败: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _shutterCtrl.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────
  // 拍摄 + 水印合成
  // ────────────────────────────────────────

  Future<void> _capture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);

    // 快门闪白效果
    _shutterCtrl.forward().then((_) => _shutterCtrl.reverse());

    try {
      final xFile = await _controller!.takePicture();
      final rawFile = File(xFile.path);

      // 合成带位置信息的水印
      final watermarked = await CameraService.applyWatermarkWithLocation(
        imageFile: rawFile,
        locationText: widget.locationText,
      );

      if (mounted) {
        setState(() {
          _capturedFile = rawFile;
          _watermarkedFile = watermarked;
          _hasCaptured = true;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍摄失败: $e')),
        );
      }
    }
  }

  void _retake() {
    _capturedFile?.delete().ignore();
    _watermarkedFile?.delete().ignore();
    setState(() {
      _hasCaptured = false;
      _capturedFile = null;
      _watermarkedFile = null;
    });
  }

  Future<void> _confirm() async {
    if (_watermarkedFile == null) return;
    await widget.onSubmit(_watermarkedFile!);
    if (mounted) Navigator.pop(context);
  }

  // ────────────────────────────────────────
  // UI
  // ────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      height: mq.size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: _hasCaptured ? _buildPreview() : _buildCamera(mq),
      ),
    );
  }

  Widget _buildCamera(MediaQueryData mq) {
    if (_isInitializing || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 相机预览
        CameraPreview(_controller!),

        // 快门闪白遮罩
        AnimatedBuilder(
          animation: _shutterAnim,
          builder: (_, __) => Opacity(
            opacity: (1 - _shutterAnim.value) * 0.8,
            child: _shutterAnim.value > 0
                ? Container(color: Colors.white)
                : const SizedBox.shrink(),
          ),
        ),

        // 顶部提示条
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _TopInfoBar(locationText: widget.locationText),
        ),

        // 底部控制区
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _BottomControls(
            isProcessing: _isProcessing,
            onCapture: _isProcessing ? null : _capture,
          ),
        ),

        // 取消按钮
        Positioned(
          top: 48,
          left: 16,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        // 水印预览提示（右上角）
        Positioned(
          top: 48,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Color(0xFFBB86FC), size: 14),
                SizedBox(width: 4),
                Text(
                  '核验模式',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 水印照片预览
        if (_watermarkedFile != null)
          Image.file(_watermarkedFile!, fit: BoxFit.contain),

        // 顶部说明
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black87,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '核验照预览',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '照片已自动加载水印（时间 + 位置）。\n提交后不可撤回，将作为到达凭证。',
                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // 底部按钮组
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black87,
            padding: EdgeInsets.fromLTRB(
              24, 16, 24, MediaQuery.of(context).padding.bottom + 16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _retake,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('重新拍摄'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _confirm,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('确认提交'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── 顶部信息栏：实时位置 + 时间 ──
class _TopInfoBar extends StatefulWidget {
  const _TopInfoBar({required this.locationText});
  final String locationText;

  @override
  State<_TopInfoBar> createState() => _TopInfoBarState();
}

class _TopInfoBarState extends State<_TopInfoBar> {
  late String _timeStr;
  late Stream<String> _timeStream;

  @override
  void initState() {
    super.initState();
    _timeStr = _currentTime();
    // 每秒刷新时间显示
    _timeStream = Stream.periodic(const Duration(seconds: 1))
        .map((_) => _currentTime());
  }

  String _currentTime() =>
      DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 60, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<String>(
            stream: _timeStream,
            initialData: _timeStr,
            builder: (_, snap) => Text(
              snap.data ?? _timeStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, color: Color(0xFFFF6B9D), size: 14),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  widget.locationText,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 底部拍摄控件 ──
class _BottomControls extends StatelessWidget {
  const _BottomControls({
    required this.isProcessing,
    required this.onCapture,
  });

  final bool isProcessing;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        40, 30, 40, MediaQuery.of(context).padding.bottom + 32,
      ),
      child: Column(
        children: [
          Text(
            '禁止使用相册选择，确保照片真实性',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onCapture,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                color: isProcessing
                    ? Colors.white24
                    : Colors.white.withOpacity(0.95),
              ),
              child: isProcessing
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
