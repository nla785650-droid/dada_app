import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/provider_application_model.dart';

// ──────────────────────────────────────────────────────────────
// ProviderRegistry：达人注册统一入口
//
// 职责：
//   1. 编排多图上传（批量、带进度回调）
//   2. 构建 JSONB provider_config（合并动态字段）
//   3. 原子写入 provider_applications 表
//   4. 更新 profiles 表的 audit_status → 'pending'
//   5. 失败时回滚（删除已上传图片，避免存储桶垃圾文件）
//
// 设计模式：Command Pattern（将复杂业务流程封装为单一可逆操作）
// ──────────────────────────────────────────────────────────────

class ProviderRegistry {
  ProviderRegistry._();

  static SupabaseClient get _db => Supabase.instance.client;

  // ════════════════════════════════════════════
  // 主入口：统一处理达人入驻全流程
  // ════════════════════════════════════════════

  static Future<ProviderRegistryResult> register({
    required String userId,
    required ProviderType providerType,

    // 通用字段
    required String region,
    required double pricePerHour,
    required String selfIntro,

    // Cos 委托专属
    int? heightCm,
    List<String> skilledCharacters = const [],
    List<File> cosPhotoFiles = const [],
    List<File> lifePhotoFiles = const [],

    // 摄影陪拍专属
    String? cameraGear,
    List<String> styleTags = const [],
    List<File> portfolioFiles = const [],

    // 社交陪玩专属
    List<String> personalTags = const [],
    String? serviceScope,

    // 进度回调
    void Function(RegistryPhase phase, double progress)? onProgress,
  }) async {
    // 上传期间记录已上传的文件路径，用于失败回滚
    final uploadedPaths = <String>[];

    try {
      // ── Phase 1: 上传图片 ──
      onProgress?.call(RegistryPhase.uploadingPhotos, 0.0);

      final cosPhotoUrls = await _uploadBatch(
        files: cosPhotoFiles,
        bucket: 'portfolios',
        folder: '$userId/cos',
        uploadedPaths: uploadedPaths,
        onProgress: (p) => onProgress?.call(RegistryPhase.uploadingPhotos, p * 0.4),
      );

      final lifePhotoUrls = await _uploadBatch(
        files: lifePhotoFiles,
        bucket: 'portfolios',
        folder: '$userId/life',
        uploadedPaths: uploadedPaths,
        onProgress: (p) => onProgress?.call(RegistryPhase.uploadingPhotos, 0.4 + p * 0.2),
      );

      final portfolioUrls = await _uploadBatch(
        files: portfolioFiles,
        bucket: 'portfolios',
        folder: '$userId/portfolio',
        uploadedPaths: uploadedPaths,
        onProgress: (p) => onProgress?.call(RegistryPhase.uploadingPhotos, 0.6 + p * 0.2),
      );

      // ── Phase 2: 构建 JSONB provider_config ──
      onProgress?.call(RegistryPhase.submitting, 0.8);

      final providerConfig = _buildProviderConfig(
        providerType: providerType,
        pricePerHour: pricePerHour,
        region: region,
        heightCm: heightCm,
        skilledCharacters: skilledCharacters,
        cameraGear: cameraGear,
        styleTags: styleTags,
        personalTags: personalTags,
        serviceScope: serviceScope,
        cosPhotoUrls: cosPhotoUrls,
        lifePhotoUrls: lifePhotoUrls,
        portfolioUrls: portfolioUrls,
      );

      // ── Phase 3: 原子写入（使用 Supabase 事务 RPC）──
      // 注意：Supabase 不直接支持客户端事务，此处使用 RPC 在 DB 侧保证原子性
      // 实际生产：在 Supabase 中创建 register_provider(userId, ...) RPC 函数
      // 此处退化为顺序写入（第一步失败不执行第二步）

      // 写入 provider_applications
      await _db.from('provider_applications').insert({
        'user_id':            userId,
        'provider_type':      providerType.value,
        'region':             region,
        'price_per_hour':     pricePerHour,
        'self_intro':         selfIntro,
        'height_cm':          heightCm,
        'skilled_characters': skilledCharacters,
        'cos_photos':         cosPhotoUrls,
        'life_photos':        lifePhotoUrls,
        'camera_gear':        cameraGear,
        'style_tags':         styleTags,
        'portfolio_photos':   portfolioUrls,
        'personal_tags':      personalTags,
        'service_scope':      serviceScope,
        'extra_details':      providerConfig,
        'agreed_to_terms':    true,
        'agreed_at':          DateTime.now().toIso8601String(),
        'status':             'pending',
      });

      // 更新 profiles：标记为待审核
      await _db.from('profiles').update({
        'audit_status':    'pending',
        'provider_type':   providerType.value,
        'provider_config': providerConfig,
        // 同步作品集到 profile（用于首页展示）
        'portfolio_urls':  [...cosPhotoUrls, ...lifePhotoUrls, ...portfolioUrls],
        'applied_at':      DateTime.now().toIso8601String(),
        'updated_at':      DateTime.now().toIso8601String(),
      }).eq('id', userId);

      onProgress?.call(RegistryPhase.done, 1.0);

      return ProviderRegistryResult.success(
        applicationId: userId, // 简化：实际应返回 application.id
        uploadedCount: uploadedPaths.length,
      );
    } catch (e) {
      // ── 失败回滚：删除已上传文件 ──
      onProgress?.call(RegistryPhase.rollingBack, 0.0);
      await _rollback(uploadedPaths);

      return ProviderRegistryResult.failure(
        error: e.toString(),
        uploadedPaths: uploadedPaths,
      );
    }
  }

  // ════════════════════════════════════════════
  // 批量上传辅助
  // ════════════════════════════════════════════

  static Future<List<String>> _uploadBatch({
    required List<File> files,
    required String bucket,
    required String folder,
    required List<String> uploadedPaths,
    void Function(double progress)? onProgress,
  }) async {
    if (files.isEmpty) return [];

    final urls = <String>[];
    for (var i = 0; i < files.length; i++) {
      final file = files[i];
      final ext = _fileExtension(file);
      final filename = '${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
      final path = '$folder/$filename';

      await _db.storage.from(bucket).upload(
        path,
        file,
        fileOptions: FileOptions(
          contentType: _mimeType(ext),
          upsert: false,
        ),
      );

      uploadedPaths.add('$bucket/$path'); // 记录路径用于回滚
      urls.add(_db.storage.from(bucket).getPublicUrl(path));
      onProgress?.call((i + 1) / files.length);
    }
    return urls;
  }

  // ════════════════════════════════════════════
  // 构建 provider_config JSONB
  // 此结构存储在 profiles.provider_config，
  // 避免频繁 ALTER TABLE 添加新字段
  // ════════════════════════════════════════════

  static Map<String, dynamic> _buildProviderConfig({
    required ProviderType providerType,
    required double pricePerHour,
    required String region,
    int? heightCm,
    List<String> skilledCharacters = const [],
    String? cameraGear,
    List<String> styleTags = const [],
    List<String> personalTags = const [],
    String? serviceScope,
    List<String> cosPhotoUrls = const [],
    List<String> lifePhotoUrls = const [],
    List<String> portfolioUrls = const [],
  }) {
    // 通用基础配置
    final base = <String, dynamic>{
      'price_per_hour':      pricePerHour,
      'region':              region,
      'schedule_buffer_hours': 2, // 服务结束后缓冲 2 小时不接单
      'max_daily_bookings':  3,   // 每日最多接 3 单（防超卖）
      'cancellation_policy': 'flexible', // flexible | moderate | strict
    };

    // 类型专属配置（深度合并）
    final typeConfig = switch (providerType) {
      ProviderType.cosCommission => {
          'height_cm':           heightCm,
          'skilled_characters':  skilledCharacters,
          'cos_photo_urls':      cosPhotoUrls,
          'life_photo_urls':     lifePhotoUrls,
          'accepts_custom_char': true, // 是否接受自定义角色
        },
      ProviderType.photography => {
          'camera_gear':         cameraGear,
          'style_tags':          styleTags,
          'portfolio_urls':      portfolioUrls,
          'includes_editing':    true,  // 是否含修图
          'delivery_days':       3,     // 出图周期（天）
        },
      ProviderType.companion => {
          'personal_tags':       personalTags,
          'service_scope':       serviceScope,
          'online_available':    true,
          'offline_available':   true,
        },
    };

    return {...base, ...typeConfig};
  }

  // ════════════════════════════════════════════
  // 回滚：删除已上传文件
  // ════════════════════════════════════════════

  static Future<void> _rollback(List<String> uploadedPaths) async {
    for (final fullPath in uploadedPaths) {
      try {
        final parts = fullPath.split('/');
        final bucket = parts.first;
        final path = parts.sublist(1).join('/');
        await _db.storage.from(bucket).remove([path]);
      } catch (_) {
        // 回滚失败不阻断流程，由定时任务清理孤儿文件
      }
    }
  }

  // ════════════════════════════════════════════
  // 工具函数
  // ════════════════════════════════════════════

  static String _fileExtension(File file) {
    final ext = file.path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'heic'].contains(ext) ? ext : 'jpg';
  }

  static String _mimeType(String ext) {
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'           => 'image/png',
      'webp'          => 'image/webp',
      'heic'          => 'image/heic',
      _               => 'image/jpeg',
    };
  }

  // ════════════════════════════════════════════
  // 查询：是否已有待审核或已通过的申请
  // ════════════════════════════════════════════

  static Future<ProviderApplicationStatus> checkApplicationStatus(
      String userId) async {
    final data = await _db
        .from('provider_applications')
        .select('status, submitted_at')
        .eq('user_id', userId)
        .order('submitted_at', ascending: false)
        .limit(1);

    if ((data as List).isEmpty) return ProviderApplicationStatus.none;

    return switch (data.first['status'] as String) {
      'pending'  => ProviderApplicationStatus.pending,
      'approved' => ProviderApplicationStatus.approved,
      'rejected' => ProviderApplicationStatus.rejected,
      _          => ProviderApplicationStatus.none,
    };
  }

  // ════════════════════════════════════════════
  // 管理员审核（供后台管理页面调用）
  // ════════════════════════════════════════════

  static Future<void> approveApplication(
    String applicationId,
    String userId,
  ) async {
    // 更新申请表
    await _db.from('provider_applications').update({
      'status':      'approved',
      'reviewed_at': DateTime.now().toIso8601String(),
    }).eq('id', applicationId);

    // 激活达人身份
    await _db.from('profiles').update({
      'audit_status': 'approved',
      'is_provider':  true,
      'approved_at':  DateTime.now().toIso8601String(),
    }).eq('id', userId);

    // 发送系统通知
    await _db.from('messages').insert({
      'sender_id':   userId, // 系统通知用自身 ID（可替换为平台账号）
      'receiver_id': userId,
      'msg_type':    'system',
      'content':     '🎉 恭喜！你的达人入驻申请已通过审核，现在可以开始接单啦～',
    });
  }

  static Future<void> rejectApplication(
    String applicationId,
    String userId, {
    required String reason,
  }) async {
    await _db.from('provider_applications').update({
      'status':           'rejected',
      'rejection_reason': reason,
      'reviewed_at':      DateTime.now().toIso8601String(),
    }).eq('id', applicationId);

    await _db.from('profiles').update({
      'audit_status':     'rejected',
      'rejection_reason': reason,
    }).eq('id', userId);

    await _db.from('messages').insert({
      'sender_id':   userId,
      'receiver_id': userId,
      'msg_type':    'system',
      'content':     '很遗憾，你的达人入驻申请未通过审核。原因：$reason\n你可以修改后重新提交申请。',
    });
  }
}

// ──────────────────────────────────────────────────────────────
// 结果类型与状态枚举
// ──────────────────────────────────────────────────────────────

enum RegistryPhase {
  uploadingPhotos,  // 上传图片中
  submitting,       // 写入数据库
  done,             // 完成
  rollingBack,      // 失败回滚
}

enum ProviderApplicationStatus { none, pending, approved, rejected }

class ProviderRegistryResult {
  const ProviderRegistryResult._({
    required this.isSuccess,
    this.applicationId,
    this.uploadedCount,
    this.error,
    this.uploadedPaths,
  });

  factory ProviderRegistryResult.success({
    required String applicationId,
    required int uploadedCount,
  }) =>
      ProviderRegistryResult._(
        isSuccess: true,
        applicationId: applicationId,
        uploadedCount: uploadedCount,
      );

  factory ProviderRegistryResult.failure({
    required String error,
    List<String>? uploadedPaths,
  }) =>
      ProviderRegistryResult._(
        isSuccess: false,
        error: error,
        uploadedPaths: uploadedPaths,
      );

  final bool isSuccess;
  final String? applicationId;
  final int? uploadedCount;
  final String? error;
  final List<String>? uploadedPaths;
}

// ──────────────────────────────────────────────────────────────
// Riverpod Provider：达人注册提交状态
// ──────────────────────────────────────────────────────────────

class ProviderRegistryState {
  const ProviderRegistryState({
    this.phase,
    this.progress = 0.0,
    this.result,
    this.isSubmitting = false,
  });

  final RegistryPhase? phase;
  final double progress;
  final ProviderRegistryResult? result;
  final bool isSubmitting;

  bool get isSuccess => result?.isSuccess == true;
  bool get hasError => result?.isSuccess == false;

  ProviderRegistryState copyWith({
    RegistryPhase? phase,
    double? progress,
    ProviderRegistryResult? result,
    bool? isSubmitting,
  }) =>
      ProviderRegistryState(
        phase: phase ?? this.phase,
        progress: progress ?? this.progress,
        result: result ?? this.result,
        isSubmitting: isSubmitting ?? this.isSubmitting,
      );
}

class ProviderRegistryNotifier
    extends StateNotifier<ProviderRegistryState> {
  ProviderRegistryNotifier() : super(const ProviderRegistryState());

  Future<void> submit({
    required String userId,
    required ProviderType providerType,
    required String region,
    required double pricePerHour,
    required String selfIntro,
    int? heightCm,
    List<String> skilledCharacters = const [],
    List<File> cosPhotoFiles = const [],
    List<File> lifePhotoFiles = const [],
    String? cameraGear,
    List<String> styleTags = const [],
    List<File> portfolioFiles = const [],
    List<String> personalTags = const [],
    String? serviceScope,
  }) async {
    state = state.copyWith(isSubmitting: true, progress: 0.0);

    final result = await ProviderRegistry.register(
      userId: userId,
      providerType: providerType,
      region: region,
      pricePerHour: pricePerHour,
      selfIntro: selfIntro,
      heightCm: heightCm,
      skilledCharacters: skilledCharacters,
      cosPhotoFiles: cosPhotoFiles,
      lifePhotoFiles: lifePhotoFiles,
      cameraGear: cameraGear,
      styleTags: styleTags,
      portfolioFiles: portfolioFiles,
      personalTags: personalTags,
      serviceScope: serviceScope,
      onProgress: (phase, progress) {
        state = state.copyWith(phase: phase, progress: progress);
      },
    );

    state = state.copyWith(
      isSubmitting: false,
      result: result,
      progress: result.isSuccess ? 1.0 : state.progress,
    );
  }

  void reset() => state = const ProviderRegistryState();
}

final providerRegistryProvider = StateNotifierProvider<
    ProviderRegistryNotifier, ProviderRegistryState>(
  (_) => ProviderRegistryNotifier(),
);
