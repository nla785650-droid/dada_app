import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/storage_service.dart';

// ──────────────────────────────────────────
// State
// ──────────────────────────────────────────

enum VerificationStep { idle, recording, uploading, success, error }

class VerificationState {
  const VerificationState({
    this.step = VerificationStep.idle,
    this.progress = 0.0,
    this.recordingSeconds = 0,
    this.videoFile,
    this.videoUrl,
    this.errorMessage,
  });

  final VerificationStep step;
  final double progress;       // 上传进度 0.0~1.0
  final int recordingSeconds;  // 已录制秒数（0~5）
  final File? videoFile;
  final String? videoUrl;
  final String? errorMessage;

  bool get isRecording => step == VerificationStep.recording;
  bool get isUploading => step == VerificationStep.uploading;
  bool get isSuccess => step == VerificationStep.success;

  VerificationState copyWith({
    VerificationStep? step,
    double? progress,
    int? recordingSeconds,
    File? videoFile,
    String? videoUrl,
    String? errorMessage,
  }) {
    return VerificationState(
      step: step ?? this.step,
      progress: progress ?? this.progress,
      recordingSeconds: recordingSeconds ?? this.recordingSeconds,
      videoFile: videoFile ?? this.videoFile,
      videoUrl: videoUrl ?? this.videoUrl,
      errorMessage: errorMessage,
    );
  }
}

// ──────────────────────────────────────────
// Notifier
// ──────────────────────────────────────────

class VerificationNotifier extends StateNotifier<VerificationState> {
  VerificationNotifier() : super(const VerificationState());

  void setRecordingSeconds(int seconds) {
    state = state.copyWith(
      step: VerificationStep.recording,
      recordingSeconds: seconds,
    );
  }

  void setVideoFile(File file) {
    state = state.copyWith(videoFile: file);
  }

  Future<bool> uploadVerification(String userId) async {
    if (state.videoFile == null) return false;

    state = state.copyWith(
      step: VerificationStep.uploading,
      progress: 0.0,
    );

    try {
      // 模拟上传进度
      for (var i = 1; i <= 10; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        state = state.copyWith(progress: i / 10.0);
      }

      final url = await StorageService.uploadVerificationVideo(
        userId: userId,
        videoFile: state.videoFile!,
      );

      await StorageService.markUserVerified(
        userId: userId,
        videoUrl: url,
      );

      state = state.copyWith(
        step: VerificationStep.success,
        videoUrl: url,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        step: VerificationStep.error,
        errorMessage: '上传失败：$e',
      );
      return false;
    }
  }

  void reset() {
    state = const VerificationState();
  }
}

// ──────────────────────────────────────────
// Provider
// ──────────────────────────────────────────

final verificationProvider =
    StateNotifierProvider<VerificationNotifier, VerificationState>(
  (_) => VerificationNotifier(),
);
