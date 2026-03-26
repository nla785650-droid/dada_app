import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/camera_service.dart';
import '../providers/verification_provider.dart';

// PureGet 实人认证 · 深蓝色说明面板色值
const _pgPanel = Color(0xFF132F4C);
const _pgCyan = Color(0xFF29B6F6);
const _pgDeep = Color(0xFF0A1929);

/// 预览确认页 pop 时：是否需在认证页重新开相机 / 是否结束整段认证流程
enum _VerificationPreviewPopResult {
  /// 重新录制或仅关闭预览：回到认证页后重新初始化相机
  needResumeCamera,

  /// 认证成功等：关闭认证页（栈上一屏）
  finishAuthenticationFlow,
}

/// PureGet 摄像头权限说明：用户点击「确定」后再走系统权限申请（半屏 BottomSheet）
Future<bool> showPureGetCameraPermissionRationale(BuildContext context) async {
  final agreed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: true,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
          decoration: BoxDecoration(
            color: _pgPanel,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _pgCyan.withValues(alpha: 0.35)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_moon_rounded,
                        color: _pgCyan, size: 28),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'PureGet 安全认证',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '为了确保社交安全，PureGet 需要申请摄像头权限进行实人认证。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 15,
                    height: 1.55,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '摄像头仅在认证流程中使用，离开本页后将立即关闭，不会后台占用。',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.35),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('暂不'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: _pgCyan,
                          foregroundColor: _pgDeep,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          '确定',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return agreed == true;
}

/// 身份验真录制页面
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key, required this.userId});

  final String userId;

  @override
  ConsumerState<VerificationScreen> createState() =>
      _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Timer? _countdownTimer;
  int _remainingSeconds = 5;
  bool _hasStartedVerification = false;  // 仅点击「开始认证」后为 true
  bool _isInitializing = false;
  bool _hasError = false;
  String _errorMsg = '';

  static const _totalSeconds = 5;
  static const _gentleErrorMsg =
      '请允许浏览器访问相机以进行认证';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 按需初始化：不在这里调用 availableCameras / CameraController.initialize。
    // 仅当用户在本页点击「开始认证」并确认 PureGet 说明后，才在 _initCamera 中拉起相机硬件。
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _releaseCameraHardware();
    CameraService.resetCameraEnumerationCache();
    super.dispose();
  }

  void _releaseCameraHardware() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      c.dispose();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_hasStartedVerification) return;
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _countdownTimer?.cancel();
        _countdownTimer = null;
        if (_controller != null) {
          _releaseCameraHardware();
          if (mounted) setState(() {});
        }
        break;
      case AppLifecycleState.resumed:
        final route = ModalRoute.of(context);
        if (route?.isCurrent != true) return;
        if (_controller != null && _controller!.value.isInitialized) return;
        if (_hasError || _isInitializing) return;
        _initCamera();
        break;
      default:
        break;
    }
  }

  /// 用户点击「开始认证」→ PureGet 说明 BottomSheet → 确定后再初始化相机
  Future<void> _onStartVerification() async {
    if (_hasStartedVerification) return;
    final ok = await showPureGetCameraPermissionRationale(context);
    if (!ok || !mounted) return;
    setState(() => _hasStartedVerification = true);
    await _initCamera();
  }

  Future<void> _initCamera() async {
    if (_isInitializing) return;
    _releaseCameraHardware();

    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMsg = '';
    });

    try {
      final hasPermission =
          await CameraService.requestAllMediaPermissions();
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMsg = _gentleErrorMsg;
            _isInitializing = false;
          });
        }
        return;
      }

      await CameraService.ensureCamerasLoaded();
      final camera = CameraService.getFrontCamera();
      if (camera == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMsg = _gentleErrorMsg;
            _isInitializing = false;
          });
        }
        return;
      }

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      // 禁止调用 setFlashMode/setTorchMode，避免 Web 端 torchModeNotSupported
      // 曝光/对焦仅移动端可选调用，Web 跳过
      if (!kIsWeb) {
        try {
          await controller.setExposureMode(ExposureMode.auto);
          await controller.setFocusMode(FocusMode.auto);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitializing = false;
        });
      } else {
        await controller.dispose();
      }
    } catch (e) {
      _releaseCameraHardware();
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = _gentleErrorMsg;
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo) return;

    final notifier = ref.read(verificationProvider.notifier);
    notifier.setRecordingSeconds(0);

    try {
      await _controller!.startVideoRecording();
      _remainingSeconds = _totalSeconds;

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        _remainingSeconds--;
        notifier.setRecordingSeconds(_totalSeconds - _remainingSeconds);
        setState(() {});

        if (_remainingSeconds <= 0) {
          t.cancel();
          await _stopRecording();
        }
      });
    } catch (e) {
      _showError('录制失败：$e');
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;

    try {
      final xFile = await _controller!.stopVideoRecording();
      final videoFile = File(xFile.path);

      if (!mounted) return;
      ref.read(verificationProvider.notifier).setVideoFile(videoFile);

      // 进入预览前立即释放相机，避免预览叠加层下仍占用摄像头 / 指示灯常亮
      _releaseCameraHardware();
      if (mounted) setState(() {});

      final popResult = await Navigator.of(context).push<_VerificationPreviewPopResult>(
        MaterialPageRoute(
          builder: (_) => _VerificationPreviewScreen(
            userId: widget.userId,
            videoFile: videoFile,
          ),
        ),
      );

      if (!mounted) return;
      if (popResult == _VerificationPreviewPopResult.finishAuthenticationFlow) {
        Navigator.of(context).pop();
        return;
      }
      // 重新录制、返回预览、或其它需继续认证：重新按需初始化
      await _initCamera();
    } catch (e) {
      _showError('停止录制失败：$e');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verificationProvider);

    // 未点击「开始认证」：显示引导页，不触发相机
    if (!_hasStartedVerification) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            _buildStartVerificationLanding(),
            _buildTopBar(context),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!_isInitializing && !_hasError && _controller != null)
            _buildCameraPreview()
          else if (_isInitializing)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          else
            _buildErrorView(),

          _buildTopBar(context),

          if (!_isInitializing && !_hasError)
            _buildGuideText(state.isRecording),

          if (!_isInitializing && !_hasError) _buildFaceGuide(),

          if (!_isInitializing && !_hasError)
            _buildRecordButton(state),

          if (state.isUploading) _buildUploadingOverlay(state.progress),
        ],
      ),
    );
  }

  /// 引导页：仅当用户点击「开始认证」后才初始化相机
  Widget _buildStartVerificationLanding() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded,
                size: 44,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              '真身认证',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '录制 5 秒真实视频，获取银色徽章\n提升买家信任度',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _onStartVerification,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text('开始认证'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    return ClipRect(
      child: OverflowBox(
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller!.value.previewSize!.height,
            height: _controller!.value.previewSize!.width,
            child: CameraPreview(_controller!),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield_rounded,
                        size: 14, color: Color(0xFFBB86FC)),
                    SizedBox(width: 4),
                    Text(
                      '真身认证',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideText(bool isRecording) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 32,
      right: 32,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: Text(
          isRecording
              ? '请正视摄像头，自然眨眼，轻微转动头部'
              : '将面部置于框内\n点击按钮开始 5 秒真实录制',
          key: ValueKey(isRecording),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            height: 1.6,
            shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
          ),
        ),
      ),
    );
  }

  Widget _buildFaceGuide() {
    final size = MediaQuery.of(context).size;
    final guideSize = size.width * 0.68;

    return Center(
      child: SizedBox(
        width: guideSize,
        height: guideSize * 1.25,
        child: CustomPaint(
          painter: _FaceGuidePainter(
            isRecording: ref.watch(verificationProvider).isRecording,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordButton(VerificationState state) {
    final isRecording = state.isRecording;
    final progress = state.recordingSeconds / _totalSeconds;

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 40,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // 倒计时文字
          if (isRecording)
            Text(
              '${_remainingSeconds}s',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w900,
              ),
            ),
          const SizedBox(height: 16),
          // 录制按钮（带进度环）
          GestureDetector(
            onTap: isRecording ? null : _startRecording,
            child: SizedBox(
              width: 88,
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 进度环
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: CircularProgressIndicator(
                      value: isRecording ? progress : 0,
                      strokeWidth: 4,
                      backgroundColor: Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation(AppTheme.accent),
                    ),
                  ),
                  // 内圆按钮
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: isRecording ? 56 : 72,
                    height: isRecording ? 56 : 72,
                    decoration: BoxDecoration(
                      color: isRecording ? AppTheme.error : Colors.white,
                      shape: isRecording
                          ? BoxShape.rectangle
                          : BoxShape.circle,
                      borderRadius:
                          isRecording ? BorderRadius.circular(8) : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isRecording ? '录制中，请勿遮挡面部' : '点击开始录制',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadingOverlay(double progress) {
    return Container(
      color: Colors.black87,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_upload_rounded,
              size: 56, color: AppTheme.primary),
          const SizedBox(height: 20),
          const Text(
            '正在上传核验视频…',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 60),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white24,
              valueColor:
                  const AlwaysStoppedAnimation(AppTheme.primary),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(progress * 100).toInt()}%',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined,
                size: 56, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              _errorMsg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initCamera,
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────
// 人脸引导框绘制
// ──────────────────────────────────────────

class _FaceGuidePainter extends CustomPainter {
  const _FaceGuidePainter({required this.isRecording});

  final bool isRecording;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isRecording
          ? AppTheme.accent.withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(120));

    // 虚线椭圆轮廓（用线段模拟）
    const dashLen = 14.0;
    const gapLen = 8.0;
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double dist = 0;
      bool draw = true;
      while (dist < metric.length) {
        final len = draw ? dashLen : gapLen;
        if (draw) {
          canvas.drawPath(metric.extractPath(dist, dist + len), paint);
        }
        dist += len;
        draw = !draw;
      }
    }

    // 四角强调线
    final cornerPaint = Paint()
      ..color = isRecording ? AppTheme.accent : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const cornerLen = 24.0;
    const r = 20.0;

    // 左上
    canvas.drawLine(
        Offset(r, 0), Offset(r + cornerLen, 0), cornerPaint);
    canvas.drawLine(
        Offset(0, r), Offset(0, r + cornerLen), cornerPaint);
    // 右上
    canvas.drawLine(
        Offset(size.width - r, 0), Offset(size.width - r - cornerLen, 0), cornerPaint);
    canvas.drawLine(
        Offset(size.width, r), Offset(size.width, r + cornerLen), cornerPaint);
    // 左下
    canvas.drawLine(
        Offset(r, size.height), Offset(r + cornerLen, size.height), cornerPaint);
    canvas.drawLine(
        Offset(0, size.height - r), Offset(0, size.height - r - cornerLen), cornerPaint);
    // 右下
    canvas.drawLine(
        Offset(size.width - r, size.height),
        Offset(size.width - r - cornerLen, size.height),
        cornerPaint);
    canvas.drawLine(
        Offset(size.width, size.height - r),
        Offset(size.width, size.height - r - cornerLen),
        cornerPaint);
  }

  @override
  bool shouldRepaint(_FaceGuidePainter oldDelegate) =>
      oldDelegate.isRecording != isRecording;
}

// ──────────────────────────────────────────
// 视频预览 & 提交确认页
// ──────────────────────────────────────────

class _VerificationPreviewScreen extends ConsumerStatefulWidget {
  const _VerificationPreviewScreen({
    required this.userId,
    required this.videoFile,
  });

  final String userId;
  final File videoFile;

  @override
  ConsumerState<_VerificationPreviewScreen> createState() =>
      _VerificationPreviewScreenState();
}

class _VerificationPreviewScreenState
    extends ConsumerState<_VerificationPreviewScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(verificationProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(
                _VerificationPreviewPopResult.needResumeCamera,
              ),
        ),
        title: const Text(
          '确认核验视频',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.4), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 视频缩略图（使用占位图模拟）
                        Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              size: 64,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                        // 防伪标签
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_rounded,
                                    size: 12, color: Color(0xFFBB86FC)),
                                SizedBox(width: 4),
                                Text(
                                  '搭哒 · 真身核验',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // 说明卡片
            Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1), width: 0.5),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lock_rounded,
                          size: 16, color: Color(0xFFBB86FC)),
                      SizedBox(width: 6),
                      Text(
                        '核验说明',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '• 该视频仅用于身份真实性核验，加密存储\n'
                    '• 买家点击头像后可查看视频缩略图（不可下载）\n'
                    '• 认证通过后头像旁将显示「真身认证」银色徽章\n'
                    '• 平台承诺不对外分享核验视频',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.8,
                    ),
                  ),
                ],
              ),
            ),
            // 操作按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: state.isUploading
                  ? Column(
                      children: [
                        LinearProgressIndicator(
                          value: state.progress,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                          borderRadius: BorderRadius.circular(4),
                          minHeight: 6,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '上传中 ${(state.progress * 100).toInt()}%',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    )
                  : state.isSuccess
                      ? Column(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 48, color: AppTheme.success),
                            const SizedBox(height: 12),
                            const Text(
                              '认证成功！真身徽章已激活',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop(
                                  _VerificationPreviewPopResult
                                      .finishAuthenticationFlow,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: AppTheme.success,
                              ),
                              child: const Text('完成'),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.of(context).pop(
                                      _VerificationPreviewPopResult
                                          .needResumeCamera,
                                    ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white70,
                                  side: const BorderSide(
                                      color: Colors.white30, width: 1),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('重新录制'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: ElevatedButton(
                                onPressed: () => ref
                                    .read(verificationProvider.notifier)
                                    .uploadVerification(widget.userId),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                  backgroundColor: AppTheme.primary,
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.verified_rounded, size: 18),
                                    SizedBox(width: 6),
                                    Text(
                                      '提交认证',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
