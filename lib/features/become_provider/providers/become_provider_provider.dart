import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/provider_application_model.dart';

// ──────────────────────────────────────────
// 表单 State
// ──────────────────────────────────────────

enum SubmitStatus { idle, uploading, submitting, success, error }

class BecomeProviderState {
  const BecomeProviderState({
    this.currentStep = 0,
    this.selectedType,
    this.region,
    this.pricePerHour,
    this.selfIntro,
    // Cos 专属
    this.heightCm,
    this.skilledCharacters = const [],
    this.cosPhotoFiles = const [],
    this.cosPhotoUrls = const [],
    this.lifePhotoFiles = const [],
    this.lifePhotoUrls = const [],
    // 摄影专属
    this.cameraGear,
    this.styleTags = const [],
    this.portfolioFiles = const [],
    this.portfolioUrls = const [],
    // 陪玩专属
    this.personalTags = const [],
    this.serviceScope,
    // 协议
    this.agreedToTerms = false,
    this.agreedToPrivacy = false,
    this.agreedToSafety = false,
    // 提交状态
    this.submitStatus = SubmitStatus.idle,
    this.uploadProgress = 0.0,
    this.errorMessage,
    this.validationErrors = const {},
  });

  final int currentStep;
  final ProviderType? selectedType;

  final String? region;
  final double? pricePerHour;
  final String? selfIntro;

  // Cos 委托
  final int? heightCm;
  final List<String> skilledCharacters;
  final List<File> cosPhotoFiles;
  final List<String> cosPhotoUrls;
  final List<File> lifePhotoFiles;
  final List<String> lifePhotoUrls;

  // 摄影陪拍
  final String? cameraGear;
  final List<String> styleTags;
  final List<File> portfolioFiles;
  final List<String> portfolioUrls;

  // 社交陪玩
  final List<String> personalTags;
  final String? serviceScope;

  // 协议
  final bool agreedToTerms;
  final bool agreedToPrivacy;
  final bool agreedToSafety;

  // 提交
  final SubmitStatus submitStatus;
  final double uploadProgress;
  final String? errorMessage;
  final Map<String, String> validationErrors; // field -> message

  bool get isUploading => submitStatus == SubmitStatus.uploading;
  bool get isSubmitting => submitStatus == SubmitStatus.submitting;
  bool get isSuccess => submitStatus == SubmitStatus.success;
  bool get allTermsAgreed => agreedToTerms && agreedToPrivacy && agreedToSafety;

  /// 当前类型的上传图片总数
  int get totalPhotos {
    return switch (selectedType) {
      ProviderType.cosCommission => cosPhotoFiles.length + lifePhotoFiles.length,
      ProviderType.photography => portfolioFiles.length,
      _ => 0,
    };
  }

  BecomeProviderState copyWith({
    int? currentStep,
    ProviderType? selectedType,
    String? region,
    double? pricePerHour,
    String? selfIntro,
    int? heightCm,
    List<String>? skilledCharacters,
    List<File>? cosPhotoFiles,
    List<String>? cosPhotoUrls,
    List<File>? lifePhotoFiles,
    List<String>? lifePhotoUrls,
    String? cameraGear,
    List<String>? styleTags,
    List<File>? portfolioFiles,
    List<String>? portfolioUrls,
    List<String>? personalTags,
    String? serviceScope,
    bool? agreedToTerms,
    bool? agreedToPrivacy,
    bool? agreedToSafety,
    SubmitStatus? submitStatus,
    double? uploadProgress,
    String? errorMessage,
    Map<String, String>? validationErrors,
  }) =>
      BecomeProviderState(
        currentStep: currentStep ?? this.currentStep,
        selectedType: selectedType ?? this.selectedType,
        region: region ?? this.region,
        pricePerHour: pricePerHour ?? this.pricePerHour,
        selfIntro: selfIntro ?? this.selfIntro,
        heightCm: heightCm ?? this.heightCm,
        skilledCharacters: skilledCharacters ?? this.skilledCharacters,
        cosPhotoFiles: cosPhotoFiles ?? this.cosPhotoFiles,
        cosPhotoUrls: cosPhotoUrls ?? this.cosPhotoUrls,
        lifePhotoFiles: lifePhotoFiles ?? this.lifePhotoFiles,
        lifePhotoUrls: lifePhotoUrls ?? this.lifePhotoUrls,
        cameraGear: cameraGear ?? this.cameraGear,
        styleTags: styleTags ?? this.styleTags,
        portfolioFiles: portfolioFiles ?? this.portfolioFiles,
        portfolioUrls: portfolioUrls ?? this.portfolioUrls,
        personalTags: personalTags ?? this.personalTags,
        serviceScope: serviceScope ?? this.serviceScope,
        agreedToTerms: agreedToTerms ?? this.agreedToTerms,
        agreedToPrivacy: agreedToPrivacy ?? this.agreedToPrivacy,
        agreedToSafety: agreedToSafety ?? this.agreedToSafety,
        submitStatus: submitStatus ?? this.submitStatus,
        uploadProgress: uploadProgress ?? this.uploadProgress,
        errorMessage: errorMessage,
        validationErrors: validationErrors ?? this.validationErrors,
      );
}

// ──────────────────────────────────────────
// Notifier
// ──────────────────────────────────────────

class BecomeProviderNotifier extends StateNotifier<BecomeProviderState> {
  BecomeProviderNotifier() : super(const BecomeProviderState());

  static const _uuid = Uuid();

  // ── 步骤导航 ──

  void selectType(ProviderType type) {
    state = state.copyWith(selectedType: type, currentStep: 1);
  }

  void goToStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  bool goNext() {
    final errors = _validateCurrentStep();
    if (errors.isNotEmpty) {
      state = state.copyWith(validationErrors: errors);
      return false;
    }
    state = state.copyWith(
      currentStep: state.currentStep + 1,
      validationErrors: {},
    );
    return true;
  }

  void goBack() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  // ── 字段更新 ──

  void setRegion(String v) => state = state.copyWith(region: v);
  void setPrice(String v) =>
      state = state.copyWith(pricePerHour: double.tryParse(v));
  void setSelfIntro(String v) => state = state.copyWith(selfIntro: v);
  void setHeightCm(String v) =>
      state = state.copyWith(heightCm: int.tryParse(v));
  void setCameraGear(String v) => state = state.copyWith(cameraGear: v);
  void setServiceScope(String v) => state = state.copyWith(serviceScope: v);

  void toggleStyleTag(String tag) {
    final tags = List<String>.from(state.styleTags);
    tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
    state = state.copyWith(styleTags: tags);
  }

  void togglePersonalTag(String tag) {
    final tags = List<String>.from(state.personalTags);
    tags.contains(tag) ? tags.remove(tag) : tags.add(tag);
    state = state.copyWith(personalTags: tags);
  }

  void addSkilledCharacter(String c) {
    if (c.trim().isEmpty) return;
    final list = List<String>.from(state.skilledCharacters)..add(c.trim());
    state = state.copyWith(skilledCharacters: list);
  }

  void removeSkilledCharacter(int i) {
    final list = List<String>.from(state.skilledCharacters)..removeAt(i);
    state = state.copyWith(skilledCharacters: list);
  }

  // ── 图片文件管理 ──

  void addCosPhotos(List<File> files) {
    final list = List<File>.from(state.cosPhotoFiles)..addAll(files);
    state = state.copyWith(cosPhotoFiles: list);
  }

  void removeCosPhoto(int i) {
    final list = List<File>.from(state.cosPhotoFiles)..removeAt(i);
    state = state.copyWith(cosPhotoFiles: list);
  }

  void addLifePhotos(List<File> files) {
    final list = List<File>.from(state.lifePhotoFiles)..addAll(files);
    state = state.copyWith(lifePhotoFiles: list);
  }

  void removeLifePhoto(int i) {
    final list = List<File>.from(state.lifePhotoFiles)..removeAt(i);
    state = state.copyWith(lifePhotoFiles: list);
  }

  void addPortfolioFiles(List<File> files) {
    final list = List<File>.from(state.portfolioFiles)..addAll(files);
    state = state.copyWith(portfolioFiles: list);
  }

  void removePortfolioFile(int i) {
    final list = List<File>.from(state.portfolioFiles)..removeAt(i);
    state = state.copyWith(portfolioFiles: list);
  }

  // ── 协议 ──

  void setAgreedToTerms(bool v) => state = state.copyWith(agreedToTerms: v);
  void setAgreedToPrivacy(bool v) => state = state.copyWith(agreedToPrivacy: v);
  void setAgreedToSafety(bool v) => state = state.copyWith(agreedToSafety: v);

  // ── 校验 ──

  Map<String, String> _validateCurrentStep() {
    final errors = <String, String>{};
    if (state.currentStep == 1) {
      if ((state.region ?? '').trim().isEmpty) errors['region'] = '请填写所在地区';
      if (state.pricePerHour == null || state.pricePerHour! <= 0) {
        errors['price'] = '请填写合理的定价';
      }
      if ((state.selfIntro ?? '').trim().length < 10) {
        errors['selfIntro'] = '自我介绍至少需要10个字';
      }
      switch (state.selectedType) {
        case ProviderType.cosCommission:
          if (state.heightCm == null) errors['height'] = '请填写身高';
          if (state.cosPhotoFiles.isEmpty) errors['cosPhotos'] = '请至少上传1张Cos照';
          if (state.lifePhotoFiles.isEmpty) errors['lifePhotos'] = '请至少上传1张生活照';
        case ProviderType.photography:
          if ((state.cameraGear ?? '').isEmpty) errors['gear'] = '请填写设备型号';
          if (state.portfolioFiles.length < 6) {
            errors['portfolio'] = '作品集至少需要6张';
          }
        case ProviderType.companion:
          if (state.personalTags.isEmpty) errors['tags'] = '请至少添加1个个人标签';
          if ((state.serviceScope ?? '').trim().isEmpty) {
            errors['scope'] = '请填写服务范围';
          }
        case null:
          break;
      }
    }
    return errors;
  }

  Map<String, String> validateStep2() => _validateCurrentStep();

  // ── 提交 ──

  Future<bool> submit(String userId) async {
    if (!state.allTermsAgreed) return false;

    state = state.copyWith(
      submitStatus: SubmitStatus.uploading,
      uploadProgress: 0.0,
      errorMessage: null,
    );

    try {
      // 1. 批量上传图片至 Supabase Storage
      final cosUrls = await _uploadFiles(
        files: state.cosPhotoFiles,
        folder: 'portfolios/$userId/cos',
        progressBase: 0.0,
        progressEnd: 0.3,
      );

      final lifeUrls = await _uploadFiles(
        files: state.lifePhotoFiles,
        folder: 'portfolios/$userId/life',
        progressBase: 0.3,
        progressEnd: 0.5,
      );

      final portfolioUrls = await _uploadFiles(
        files: state.portfolioFiles,
        folder: 'portfolios/$userId/portfolio',
        progressBase: 0.5,
        progressEnd: 0.8,
      );

      state = state.copyWith(
        cosPhotoUrls: cosUrls,
        lifePhotoUrls: lifeUrls,
        portfolioUrls: portfolioUrls,
        uploadProgress: 0.8,
        submitStatus: SubmitStatus.submitting,
      );

      // 2. 写入 provider_applications 表
      final application = ProviderApplication(
        userId: userId,
        providerType: state.selectedType!,
        region: state.region,
        pricePerHour: state.pricePerHour,
        selfIntro: state.selfIntro,
        heightCm: state.heightCm,
        skilledCharacters: state.skilledCharacters,
        cosPhotos: cosUrls,
        lifePhotos: lifeUrls,
        cameraGear: state.cameraGear,
        styleTags: state.styleTags,
        portfolioPhotos: portfolioUrls,
        personalTags: state.personalTags,
        serviceScope: state.serviceScope,
        agreedToTerms: true,
      );

      await Supabase.instance.client
          .from('provider_applications')
          .insert(application.toJson());

      // 3. 更新 profiles 表 verification_status
      await Supabase.instance.client.from('profiles').update({
        'verification_status': 'pending',
        'provider_type': state.selectedType!.value,
        'applied_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      state = state.copyWith(
        submitStatus: SubmitStatus.success,
        uploadProgress: 1.0,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        submitStatus: SubmitStatus.error,
        errorMessage: '提交失败，请稍后重试：$e',
      );
      return false;
    }
  }

  // ── 内部：批量上传文件 ──

  Future<List<String>> _uploadFiles({
    required List<File> files,
    required String folder,
    required double progressBase,
    required double progressEnd,
  }) async {
    if (files.isEmpty) return [];

    final urls = <String>[];
    final step = (progressEnd - progressBase) / files.length;

    for (var i = 0; i < files.length; i++) {
      final filename = '${_uuid.v4()}.jpg';
      final path = '$folder/$filename';

      await Supabase.instance.client.storage.from('portfolios').upload(
            path,
            files[i],
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: false,
            ),
          );

      final url = Supabase.instance.client.storage
          .from('portfolios')
          .getPublicUrl(path);
      urls.add(url);

      state = state.copyWith(
        uploadProgress: progressBase + step * (i + 1),
      );
    }
    return urls;
  }

  void reset() => state = const BecomeProviderState();
}

// ──────────────────────────────────────────
// Provider
// ──────────────────────────────────────────

final becomeProviderProvider =
    StateNotifierProvider<BecomeProviderNotifier, BecomeProviderState>(
  (_) => BecomeProviderNotifier(),
);
