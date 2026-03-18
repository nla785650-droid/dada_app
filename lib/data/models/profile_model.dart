import 'package:flutter/foundation.dart';

@immutable
class Profile {
  const Profile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    this.bio,
    required this.role,
    this.categories,
    this.priceMin,
    this.priceMax,
    this.location,
    this.rating = 0,
    this.reviewCount = 0,
    this.isVerified = false,
    required this.createdAt,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String? bio;
  final String role; // 'user' | 'provider'
  final List<String>? categories;
  final double? priceMin;
  final double? priceMax;
  final String? location;
  final double rating;
  final int reviewCount;
  final bool isVerified;
  final DateTime createdAt;

  bool get isProvider => role == 'provider';

  String get displayNameOrUsername => displayName ?? username;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      role: json['role'] as String? ?? 'user',
      categories: (json['categories'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      priceMin: (json['price_min'] as num?)?.toDouble(),
      priceMax: (json['price_max'] as num?)?.toDouble(),
      location: json['location'] as String?,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      isVerified: json['is_verified'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'role': role,
      'categories': categories,
      'price_min': priceMin,
      'price_max': priceMax,
      'location': location,
      'rating': rating,
      'review_count': reviewCount,
      'is_verified': isVerified,
      'created_at': createdAt.toIso8601String(),
    };
  }

  Profile copyWith({
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? role,
    List<String>? categories,
    double? priceMin,
    double? priceMax,
    String? location,
  }) {
    return Profile(
      id: id,
      username: username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      categories: categories ?? this.categories,
      priceMin: priceMin ?? this.priceMin,
      priceMax: priceMax ?? this.priceMax,
      location: location ?? this.location,
      rating: rating,
      reviewCount: reviewCount,
      isVerified: isVerified,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Profile && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
