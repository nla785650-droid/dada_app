import 'package:flutter/foundation.dart';

/// 达人类型
enum ProviderType {
  cosCommission('cos_commission', 'Cos 委托', '🎭'),
  photography('photography', '摄影陪拍', '📸'),
  companion('companion', '社交陪玩', '🎮');

  const ProviderType(this.value, this.label, this.emoji);

  final String value;
  final String label;
  final String emoji;

  static ProviderType fromValue(String v) =>
      ProviderType.values.firstWhere((e) => e.value == v);
}

/// 审核状态
enum VerificationStatus {
  unapplied('unapplied', '未申请'),
  pending('pending', '审核中'),
  approved('approved', '已通过'),
  rejected('rejected', '已拒绝');

  const VerificationStatus(this.value, this.label);

  final String value;
  final String label;

  static VerificationStatus fromValue(String v) =>
      VerificationStatus.values.firstWhere((e) => e.value == v,
          orElse: () => VerificationStatus.unapplied);
}

@immutable
class ProviderApplication {
  const ProviderApplication({
    this.id,
    required this.userId,
    required this.providerType,
    this.region,
    this.pricePerHour,
    this.selfIntro,
    // Cos 委托
    this.heightCm,
    this.skilledCharacters = const [],
    this.cosPhotos = const [],
    this.lifePhotos = const [],
    // 摄影陪拍
    this.cameraGear,
    this.styleTags = const [],
    this.portfolioPhotos = const [],
    // 社交陪玩
    this.personalTags = const [],
    this.serviceScope,
    this.verificationVideo,
    // 状态
    this.status = VerificationStatus.pending,
    this.agreedToTerms = false,
    this.submittedAt,
  });

  final String? id;
  final String userId;
  final ProviderType providerType;

  final String? region;
  final double? pricePerHour;
  final String? selfIntro;

  // Cos 委托
  final int? heightCm;
  final List<String> skilledCharacters;
  final List<String> cosPhotos;
  final List<String> lifePhotos;

  // 摄影陪拍
  final String? cameraGear;
  final List<String> styleTags;
  final List<String> portfolioPhotos;

  // 社交陪玩
  final List<String> personalTags;
  final String? serviceScope;
  final String? verificationVideo;

  final VerificationStatus status;
  final bool agreedToTerms;
  final DateTime? submittedAt;

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'provider_type': providerType.value,
        'region': region,
        'price_per_hour': pricePerHour,
        'self_intro': selfIntro,
        'height_cm': heightCm,
        'skilled_characters': skilledCharacters,
        'cos_photos': cosPhotos,
        'life_photos': lifePhotos,
        'camera_gear': cameraGear,
        'style_tags': styleTags,
        'portfolio_photos': portfolioPhotos,
        'personal_tags': personalTags,
        'service_scope': serviceScope,
        'verification_video': verificationVideo,
        'status': status.value,
        'agreed_to_terms': agreedToTerms,
        'agreed_at': agreedToTerms ? DateTime.now().toIso8601String() : null,
      };

  factory ProviderApplication.fromJson(Map<String, dynamic> j) =>
      ProviderApplication(
        id: j['id'] as String?,
        userId: j['user_id'] as String,
        providerType: ProviderType.fromValue(j['provider_type'] as String),
        region: j['region'] as String?,
        pricePerHour: (j['price_per_hour'] as num?)?.toDouble(),
        selfIntro: j['self_intro'] as String?,
        heightCm: j['height_cm'] as int?,
        skilledCharacters: _strList(j['skilled_characters']),
        cosPhotos: _strList(j['cos_photos']),
        lifePhotos: _strList(j['life_photos']),
        cameraGear: j['camera_gear'] as String?,
        styleTags: _strList(j['style_tags']),
        portfolioPhotos: _strList(j['portfolio_photos']),
        personalTags: _strList(j['personal_tags']),
        serviceScope: j['service_scope'] as String?,
        verificationVideo: j['verification_video'] as String?,
        status: VerificationStatus.fromValue(j['status'] as String? ?? ''),
        agreedToTerms: j['agreed_to_terms'] as bool? ?? false,
        submittedAt: j['submitted_at'] != null
            ? DateTime.parse(j['submitted_at'] as String)
            : null,
      );

  static List<String> _strList(dynamic v) =>
      (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [];

  ProviderApplication copyWith({
    ProviderType? providerType,
    String? region,
    double? pricePerHour,
    String? selfIntro,
    int? heightCm,
    List<String>? skilledCharacters,
    List<String>? cosPhotos,
    List<String>? lifePhotos,
    String? cameraGear,
    List<String>? styleTags,
    List<String>? portfolioPhotos,
    List<String>? personalTags,
    String? serviceScope,
    String? verificationVideo,
    bool? agreedToTerms,
  }) =>
      ProviderApplication(
        id: id,
        userId: userId,
        providerType: providerType ?? this.providerType,
        region: region ?? this.region,
        pricePerHour: pricePerHour ?? this.pricePerHour,
        selfIntro: selfIntro ?? this.selfIntro,
        heightCm: heightCm ?? this.heightCm,
        skilledCharacters: skilledCharacters ?? this.skilledCharacters,
        cosPhotos: cosPhotos ?? this.cosPhotos,
        lifePhotos: lifePhotos ?? this.lifePhotos,
        cameraGear: cameraGear ?? this.cameraGear,
        styleTags: styleTags ?? this.styleTags,
        portfolioPhotos: portfolioPhotos ?? this.portfolioPhotos,
        personalTags: personalTags ?? this.personalTags,
        serviceScope: serviceScope ?? this.serviceScope,
        verificationVideo: verificationVideo ?? this.verificationVideo,
        status: status,
        agreedToTerms: agreedToTerms ?? this.agreedToTerms,
        submittedAt: submittedAt,
      );
}
