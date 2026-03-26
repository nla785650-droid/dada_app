// ProviderSummary：跨页面传递的达人摘要数据
// 用于 DiscoverScreen → ProviderProfileScreen 的 Hero 跳转
class ProviderSummary {
  const ProviderSummary({
    required this.id,
    required this.name,
    required this.tag,
    required this.typeEmoji,
    required this.imageUrl,
    required this.rating,
    required this.reviews,
    required this.location,
    required this.price,
    required this.tags,
    this.avatarUrl,
    this.portfolio = const [],
    this.bio,
    this.completedOrders = 0,
    this.isDiversityPick = false,
    this.isVerified = false,
  });

  final String id;
  final String name;
  final String tag;
  final String typeEmoji;
  final String imageUrl;    // 封面图（Hero 目标）
  final double rating;
  final int reviews;
  final String location;
  final int price;
  final List<String> tags;
  final String? avatarUrl;  // 头像（Hero 目标 avatar_{id}）
  final List<String> portfolio;
  final String? bio;
  final int completedOrders;
  final bool isDiversityPick;
  /// 实人认证（达人）
  final bool isVerified;

  Map<String, dynamic> toExtra() => {
        'id':              id,
        'name':            name,
        'tag':             tag,
        'typeEmoji':       typeEmoji,
        'imageUrl':        imageUrl,
        'rating':          rating,
        'reviews':         reviews,
        'location':        location,
        'price':           price,
        'tags':            tags,
        'avatarUrl':       avatarUrl,
        'portfolio':       portfolio,
        'bio':             bio,
        'completedOrders': completedOrders,
        'isVerified': isVerified,
      };

  factory ProviderSummary.fromExtra(Map<String, dynamic> e) => ProviderSummary(
        id:              e['id'] as String,
        name:            e['name'] as String,
        tag:             e['tag'] as String,
        typeEmoji:       e['typeEmoji'] as String? ?? '🎭',
        imageUrl:        e['imageUrl'] as String,
        rating:          (e['rating'] as num).toDouble(),
        reviews:         e['reviews'] as int,
        location:        e['location'] as String,
        price:           e['price'] as int,
        tags:            List<String>.from(e['tags'] as List),
        avatarUrl:       e['avatarUrl'] as String?,
        portfolio:       List<String>.from(e['portfolio'] as List? ?? []),
        bio:             e['bio'] as String?,
        completedOrders: e['completedOrders'] as int? ?? 0,
        isVerified: e['isVerified'] as bool? ?? false,
      );
}
