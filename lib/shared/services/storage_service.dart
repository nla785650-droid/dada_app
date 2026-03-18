import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  StorageService._();

  static SupabaseClient get _client => Supabase.instance.client;

  // ──────────────────────────────────────────
  // 上传核验视频
  // ──────────────────────────────────────────

  static Future<String> uploadVerificationVideo({
    required String userId,
    required File videoFile,
    void Function(double progress)? onProgress,
  }) async {
    final path = 'verifications/$userId/verify_${DateTime.now().millisecondsSinceEpoch}.mp4';

    await _client.storage.from('user-media').upload(
          path,
          videoFile,
          fileOptions: const FileOptions(
            contentType: 'video/mp4',
            upsert: true,
          ),
        );

    final url = _client.storage.from('user-media').getPublicUrl(path);
    return url;
  }

  // ──────────────────────────────────────────
  // 上传实时拍摄图片
  // ──────────────────────────────────────────

  static Future<String> uploadRealtimePhoto({
    required String senderId,
    required File imageFile,
  }) async {
    final path =
        'realtime/$senderId/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await _client.storage.from('user-media').upload(
          path,
          imageFile,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: false,
          ),
        );

    final url = _client.storage.from('user-media').getPublicUrl(path);
    return url;
  }

  // ──────────────────────────────────────────
  // 标记用户为已认证
  // ──────────────────────────────────────────

  static Future<void> markUserVerified({
    required String userId,
    required String videoUrl,
  }) async {
    await _client.from('profiles').update({
      'is_verified': true,
      'verification_video_url': videoUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }
}
