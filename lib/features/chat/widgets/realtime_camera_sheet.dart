import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/services/camera_service.dart';

/// 实时拍摄底部弹出相机（卖家专用，禁止选择相册）
class RealtimeCameraSheet extends StatefulWidget {
  const RealtimeCameraSheet({super.key, required this.onPhotoTaken});

  /// 返回已合成水印的 File
  final Future<void> Function(File watermarkedPhoto) onPhotoTaken;

  @override
  State<RealtimeCameraSheet> createState() => _RealtimeCameraSheetState();
}

class _RealtimeCameraSheetState extends State<RealtimeCameraSheet>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _hasStartedCamera = false;  // 懒加载：仅用户点击「开始拍摄」后才初始化
  bool _isInitializing = true;
  bool _isTakingPhoto = false;
  bool _isFront = false;
  bool _hasError = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 不在此处初始化相机，等待用户点击「开始拍摄」
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// 用户点击「开始拍摄」时触发，懒加载相机
  Future<void> _onStartCamera() async {
    if (_hasStartedCamera) return;
    setState(() => _hasStartedCamera = true);
    await _initCamera();
  }

  Future<void> _initCamera() async {
    setState(() {
      _isInitializing = true;
      _hasError = false;
      _errorMsg = '';
    });

    try {
      final granted = await CameraService.requestCameraPermission();
      if (!granted) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMsg = '请允许浏览器访问相机以进行认证';
            _isInitializing = false;
          });
        }
        return;
      }

      await CameraService.ensureCamerasLoaded();
      final camera = _isFront
          ? CameraService.getFrontCamera()
          : CameraService.getBackCamera();

      if (camera == null) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMsg = '请允许浏览器访问相机以进行认证';
            _isInitializing = false;
          });
        }
        return;
      }

      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();

      // 禁止调用 setFlashMode/setTorchMode，避免 Web torchModeNotSupported

      if (mounted) {
        setState(() {
          _controller = controller;
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMsg = '请允许浏览器访问相机以进行认证';
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _toggleCamera() async {
    _isFront = !_isFront;
    await _controller?.dispose();
    _controller = null;
    await _initCamera();
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isTakingPhoto) return;

    setState(() => _isTakingPhoto = true);

    try {
      // 触发快门震动反馈
      HapticFeedback.mediumImpact();

      final xFile = await _controller!.takePicture();
      final originalFile = File(xFile.path);

      // 合成水印
      final watermarked = await CameraService.applyWatermark(originalFile);

      if (!mounted) return;
      Navigator.of(context).pop();

      // 发送给父组件
      await widget.onPhotoTaken(watermarked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('拍摄失败：$e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTakingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: _hasStartedCamera
            ? _buildCameraContent()
            : _buildStartLanding(context),
      ),
    );
  }

  /// 懒加载引导页：点击「开始拍摄」后才初始化相机
  Widget _buildStartLanding(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 40,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '实时拍摄',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '仅相机拍摄，自动加水印\n发出后不可撤回',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _onStartCamera,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text('开始拍摄'),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close, color: Colors.white, size: 26),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraContent() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ── 相机预览 / 错误提示 ──
        if (_hasError)
          _buildErrorView()
        else if (!_isInitializing && _controller != null)
          _buildPreview()
        else
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),

        // ── 顶部工具栏 ──
        _buildTopBar(context),

        // ── 防伪说明浮层 ──
        _buildWatermarkBadge(),

        // ── 快门按钮区 ──
        _buildShutterArea(),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.camera_alt_outlined,
                size: 48, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              _errorMsg.isNotEmpty ? _errorMsg : '请允许浏览器访问相机以进行认证',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () => _initCamera(),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return OverflowBox(
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller!.value.previewSize!.height,
          height: _controller!.value.previewSize!.width,
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: const Icon(Icons.close, color: Colors.white, size: 26),
            ),
            const Spacer(),
            // 警告：禁止从相册选择
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_rounded, size: 13, color: AppTheme.error),
                  SizedBox(width: 4),
                  Text(
                    '禁止从相册选择',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // 切换前后摄像头
            GestureDetector(
              onTap: _toggleCamera,
              child: const Icon(Icons.flip_camera_ios_rounded,
                  color: Colors.white, size: 26),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWatermarkBadge() {
    return Positioned(
      top: 64,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.verified_rounded, size: 13, color: Color(0xFFBB86FC)),
              SizedBox(width: 5),
              Text(
                '拍摄后将自动加盖  搭哒·实时拍摄  + 时间水印',
                style: TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShutterArea() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // 实时时间显示
          Text(
            _currentTimeStr(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 16),
          // 快门按钮
          GestureDetector(
            onTap: _isTakingPhoto ? null : _takePhoto,
            child: SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _isTakingPhoto ? 40 : 62,
                    height: _isTakingPhoto ? 40 : 62,
                    decoration: BoxDecoration(
                      color: _isTakingPhoto ? AppTheme.accent : Colors.white,
                      shape: _isTakingPhoto
                          ? BoxShape.rectangle
                          : BoxShape.circle,
                      borderRadius:
                          _isTakingPhoto ? BorderRadius.circular(8) : null,
                    ),
                    child: _isTakingPhoto
                        ? const Padding(
                            padding: EdgeInsets.all(14),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '仅相机拍摄  ·  自动加水印  ·  发出后不可撤回',
            style: TextStyle(color: Colors.white38, fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _currentTimeStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}  '
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
  }
}
