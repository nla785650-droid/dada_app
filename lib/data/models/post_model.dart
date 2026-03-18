import 'package:flutter/foundation.dart';
import 'profile_model.dart';

@immutable
class Post {
  const Post({
    required this.id,
    required this.providerId,
    required this.title,
    this.description,
    required this.category,
    required this.images,
    this.coverImage,
    required this.price,
    this.priceUnit = '次',
    this.tags,
    this.location,
    this.isActive = true,
    this.viewCount = 0,
    this.likeCount = 0,
    required this.createdAt,
    this.provider,
  });

  final String id;
  final String providerId;
  final String title;
  final String? description;
  final String category; // 'cosplay' | 'photo' | 'game' | 'other'
  final List<String> images;
  final String? coverImage;
  final double price;
  final String priceUnit;
  final List<String>? tags;
  final String? location;
  final bool isActive;
  final int viewCount;
  final int likeCount;
  final DateTime createdAt;

  // 关联查询时附带的 provider 信息
  final Profile? provider;

  String get displayCoverImage =>
      coverImage ?? (images.isNotEmpty ? images.first : '');

  String get categoryLabel {
    return switch (category) {
      'cosplay' => 'Cosplay 委托',
      'photo' => '摄影陪拍',
      'game' => '社交陪玩',
      _ => '其他',
    };
  }

  String get priceDisplay => '¥${price.toStringAsFixed(0)}/$priceUnit';

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      providerId: json['provider_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      coverImage: json['cover_image'] as String?,
      price: (json['price'] as num).toDouble(),
      priceUnit: json['price_unit'] as String? ?? '次',
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList(),
      location: json['location'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      viewCount: json['view_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      provider: json['profiles'] != null
          ? Profile.fromJson(json['profiles'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider_id': providerId,
      'title': title,
      'description': description,
      'category': category,
      'images': images,
      'cover_image': coverImage,
      'price': price,
      'price_unit': priceUnit,
      'tags': tags,
      'location': location,
      'is_active': isActive,
      'view_count': viewCount,
      'like_count': likeCount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Post && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
