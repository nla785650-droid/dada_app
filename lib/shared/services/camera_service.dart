import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// 全局可用的相机列表，首次使用时延迟加载
List<CameraDescription> availableCameraList = [];
bool _camerasLoaded = false;

class CameraService {
  CameraService._();

  /// 延迟初始化相机列表：仅在首次需要相机时调用（用户点击「开始认证」等场景）
  /// Web 端使用 camera_web 标准流程，需在用户手势上下文中调用
  static Future<void> ensureCamerasLoaded() async {
    if (_camerasLoaded) return;
    availableCameraList = await availableCameras();
    _camerasLoaded = true;
  }

  // ──────────────────────────────────────────
  // 权限请求
  // ──────────────────────────────────────────

  static Future<bool> requestCameraPermission() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  static Future<bool> requestAllMediaPermissions() async {
    final results = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    return results.values.every((s) => s.isGranted);
  }

  // ──────────────────────────────────────────
  // 获取前置摄像头
  // ──────────────────────────────────────────

  static CameraDescription? getFrontCamera() {
    try {
      return availableCameraList.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
      );
    } catch (_) {
      return availableCameraList.isNotEmpty ? availableCameraList.first : null;
    }
  }

  static CameraDescription? getBackCamera() {
    try {
      return availableCameraList.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
    } catch (_) {
      return availableCameraList.isNotEmpty ? availableCameraList.first : null;
    }
  }

  // ──────────────────────────────────────────
  // 水印合成：在图片上叠加"搭哒 - 实时拍摄"+ 时间
  // ──────────────────────────────────────────

  static Future<File> applyWatermark(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) return imageFile;

    // 使用 Flutter Canvas 绘制水印
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(original.width.toDouble(), original.height.toDouble());

    // 绘制原图
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    canvas.drawImage(frame.image, Offset.zero, Paint());

    // 绘制半透明黑色底条
    final barH = size.height * 0.08;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - barH, size.width, barH),
      Paint()..color = const Color(0xCC000000),
    );

    // 绘制水印文字
    final now = DateTime.now();
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final textPainter1 = TextPainter(
      text: TextSpan(
        text: '搭哒 · 实时拍摄',
        style: TextStyle(
          color: Colors.white,
          fontSize: size.width * 0.04,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final textPainter2 = TextPainter(
      text: TextSpan(
        text: timeStr,
        style: TextStyle(
          color: const Color(0xFFCCCCCC),
          fontSize: size.width * 0.03,
          fontWeight: FontWeight.w400,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final padding = size.width * 0.04;
    textPainter1.paint(
      canvas,
      Offset(padding, size.height - barH + (barH - textPainter1.height) * 0.3),
    );
    textPainter2.paint(
      canvas,
      Offset(
          padding, size.height - barH + (barH - textPainter2.height) * 0.7 + textPainter1.height * 0.4),
    );

    // 绘制搭哒 Logo 标记（右侧）
    final logoPainter = TextPainter(
      text: TextSpan(
        text: '🔒 防伪',
        style: TextStyle(
          color: const Color(0xFFBB86FC),
          fontSize: size.width * 0.03,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: size.width);
    logoPainter.paint(
      canvas,
      Offset(
        size.width - logoPainter.width - padding,
        size.height - barH + (barH - logoPainter.height) / 2,
      ),
    );

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(original.width, original.height);
    final pngBytes = await uiImage.toByteData(format: ui.ImageByteFormat.png);

    // 写入临时文件
    final tempDir = await getTemporaryDirectory();
    final outFile = File(
        '${tempDir.path}/watermarked_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await outFile.writeAsBytes(pngBytes!.buffer.asUint8List());
    return outFile;
  }

  // ──────────────────────────────────────────
  // 增强水印：含位置信息（用于到达核验照）
  // 在原有水印基础上增加 GPS 位置文字第三行
  // ──────────────────────────────────────────

  static Future<File> applyWatermarkWithLocation({
    required File imageFile,
    required String locationText,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final original = img.decodeImage(bytes);
    if (original == null) return imageFile;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(original.width.toDouble(), original.height.toDouble());

    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    canvas.drawImage(frame.image, Offset.zero, Paint());

    // 底部半透明遮罩（稍高一些，容纳3行文字）
    final barH = size.height * 0.11;
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - barH, size.width, barH),
      Paint()..color = const Color(0xDD000000),
    );

    final now = DateTime.now();
    final timeStr = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    final padding = size.width * 0.04;
    final baseFontSize = size.width * 0.03;

    // 第1行：搭哒 · 实时拍摄（品牌）
    _drawText(
      canvas,
      text: '搭哒 · 实时核验',
      x: padding,
      y: size.height - barH + barH * 0.06,
      fontSize: baseFontSize * 1.3,
      color: Colors.white,
      fontWeight: FontWeight.w700,
      maxWidth: size.width * 0.7,
    );

    // 第2行：时间戳
    _drawText(
      canvas,
      text: timeStr,
      x: padding,
      y: size.height - barH + barH * 0.38,
      fontSize: baseFontSize,
      color: const Color(0xFFCCCCCC),
      maxWidth: size.width * 0.7,
    );

    // 第3行：位置文字
    _drawText(
      canvas,
      text: '📍 $locationText',
      x: padding,
      y: size.height - barH + barH * 0.64,
      fontSize: baseFontSize,
      color: const Color(0xFF90CAF9),
      maxWidth: size.width * 0.85,
    );

    // 右侧防伪标记
    _drawText(
      canvas,
      text: '🔒 防伪',
      x: size.width * 0.8,
      y: size.height - barH + barH * 0.25,
      fontSize: baseFontSize * 1.1,
      color: const Color(0xFFBB86FC),
      fontWeight: FontWeight.w700,
      maxWidth: size.width * 0.2,
    );

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(original.width, original.height);
    final pngBytes = await uiImage.toByteData(format: ui.ImageByteFormat.png);

    final tempDir = await getTemporaryDirectory();
    final outFile = File(
        '${tempDir.path}/verified_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await outFile.writeAsBytes(pngBytes!.buffer.asUint8List());
    return outFile;
  }

  static void _drawText(
    Canvas canvas, {
    required String text,
    required double x,
    required double y,
    required double fontSize,
    required Color color,
    FontWeight fontWeight = FontWeight.w400,
    double maxWidth = double.infinity,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    painter.paint(canvas, Offset(x, y));
  }

  // ──────────────────────────────────────────
  // 生成临时视频路径
  // ──────────────────────────────────────────

  static Future<String> getTempVideoPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/verify_${DateTime.now().millisecondsSinceEpoch}.mp4';
  }

  static Future<String> getTempImagePath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/realtime_${DateTime.now().millisecondsSinceEpoch}.jpg';
  }
}
