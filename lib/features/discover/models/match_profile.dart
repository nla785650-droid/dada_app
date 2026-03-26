import 'package:flutter/foundation.dart';

/// 匹配滑卡用户信息（全屏 Tinder 数据源）
@immutable
class MatchProfile {
  const MatchProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.occupation,
    required this.distanceKm,
    required this.tagline,
    required this.tag,
    required this.typeEmoji,
    required this.imageUrl,
    required this.rating,
    required this.reviews,
    required this.location,
    required this.price,
    required this.tags,
    this.isDiversityPick = false,
    this.gender,
    this.heightCm,
    this.zodiac,
    this.mbti,
  });

  final String id;
  final String name;
  final int age;
  final String occupation;
  final int distanceKm;
  final String tagline;
  final String tag;
  final String typeEmoji;
  final String imageUrl;
  final double rating;
  final int reviews;
  final String location;
  final int price;
  final List<String> tags;
  final bool isDiversityPick;
  final String? gender;
  final int? heightCm;
  final String? zodiac;
  final String? mbti;
}

/// 滑卡方向
enum MatchSwipeDirection { like, pass }
