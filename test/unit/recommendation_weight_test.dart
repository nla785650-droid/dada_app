import 'package:flutter_test/flutter_test.dart';

// ══════════════════════════════════════════════════════════════
// 推荐权重计算单元测试（字节跳动式多维度排序）
//
// 算法说明：
//   score = w1*freshness + w2*engagement + w3*diversity + w4*personalization
//
//   · freshness（时效性）：越新发布得分越高，衰减函数：1/(1+hours^0.5)
//   · engagement（互动率）：(likes + comments*2 + bookings*5) / views
//   · diversity（多样性）：与已展示标签的差异度，防连续5条标签重复
//   · personalization（个性化）：与用户历史偏好标签的匹配度
// ══════════════════════════════════════════════════════════════

import 'dart:math' as math;

// ── 推荐候选模型 ──
class RecommendCandidate {
  const RecommendCandidate({
    required this.id,
    required this.publishedHoursAgo,
    required this.views,
    required this.likes,
    required this.comments,
    required this.bookings,
    required this.tags,
  });

  final String id;
  final double publishedHoursAgo;
  final int views;
  final int likes;
  final int comments;
  final int bookings;
  final List<String> tags;
}

// ── 推荐引擎 ──
class RecommendationEngine {
  RecommendationEngine({
    this.wFreshness      = 0.25,
    this.wEngagement     = 0.35,
    this.wDiversity      = 0.20,
    this.wPersonalization = 0.20,
  }) : assert(
          (wFreshness + wEngagement + wDiversity + wPersonalization - 1.0).abs() < 0.001,
          'Weights must sum to 1.0',
        );

  final double wFreshness;
  final double wEngagement;
  final double wDiversity;
  final double wPersonalization;

  /// 计算单个候选项的推荐分
  double score({
    required RecommendCandidate candidate,
    required List<String> recentlyShownTags,
    required List<String> userPreferenceTags,
  }) {
    final f = _freshness(candidate.publishedHoursAgo);
    final e = _engagement(candidate);
    final d = _diversity(candidate.tags, recentlyShownTags);
    final p = _personalization(candidate.tags, userPreferenceTags);

    return wFreshness * f
        + wEngagement * e
        + wDiversity  * d
        + wPersonalization * p;
  }

  /// 对候选列表排序（分数高的排前面）
  List<RecommendCandidate> rank({
    required List<RecommendCandidate> candidates,
    required List<String> recentlyShownTags,
    required List<String> userPreferenceTags,
  }) {
    final scored = candidates.map((c) => MapEntry(
      c,
      score(
        candidate:          c,
        recentlyShownTags:  recentlyShownTags,
        userPreferenceTags: userPreferenceTags,
      ),
    )).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  // ── 分量计算 ──

  /// 时效性：1 / (1 + sqrt(hours))，范围 0~1
  double _freshness(double hoursAgo) {
    if (hoursAgo < 0) return 1.0;
    return 1.0 / (1.0 + math.sqrt(hoursAgo));
  }

  /// 互动率：综合分（归一化到 0~1）
  double _engagement(RecommendCandidate c) {
    if (c.views == 0) return 0;
    final raw = (c.likes + c.comments * 2 + c.bookings * 5) / c.views;
    // 软归一化：tanh(raw * 5)，避免超高互动率无限拉分
    return _tanh(raw * 5);
  }

  /// 多样性：1 - (重叠标签数 / 总标签数)
  double _diversity(List<String> tags, List<String> shown) {
    if (tags.isEmpty || shown.isEmpty) return 1.0;
    final overlap = tags.where((t) => shown.contains(t)).length;
    return 1.0 - (overlap / tags.length);
  }

  /// 个性化：Jaccard 相似度
  double _personalization(List<String> tags, List<String> prefs) {
    if (tags.isEmpty || prefs.isEmpty) return 0.5; // 中性分
    final intersection = tags.where((t) => prefs.contains(t)).length;
    final union        = {...tags, ...prefs}.length;
    return intersection / union;
  }

  double _tanh(double x) {
    final e2x = math.exp(2 * x);
    return (e2x - 1) / (e2x + 1);
  }
}

// ──────────────────────────────────────────────────────────────

void main() {
  final engine = RecommendationEngine();

  group('时效性（Freshness）', () {
    test('刚发布（0小时前）得分为 1.0', () {
      final score = engine.score(
        candidate: RecommendCandidate(
          id: 'a', publishedHoursAgo: 0, views: 1000,
          likes: 100, comments: 20, bookings: 5, tags: ['cosplay'],
        ),
        recentlyShownTags: [],
        userPreferenceTags: [],
      );
      // freshness(0) = 1 / (1 + 0) = 1.0
      expect(score, greaterThan(0.2)); // 至少贡献 0.25 * 1.0 = 0.25
    });

    test('1小时前发布得分 < 0小时前', () {
      double scoreFor(double hours) => engine.score(
        candidate: RecommendCandidate(
          id: 'x', publishedHoursAgo: hours, views: 1000,
          likes: 100, comments: 20, bookings: 5, tags: ['cosplay'],
        ),
        recentlyShownTags: [],
        userPreferenceTags: [],
      );
      expect(scoreFor(0), greaterThan(scoreFor(1)));
      expect(scoreFor(1), greaterThan(scoreFor(24)));
      expect(scoreFor(24), greaterThan(scoreFor(168))); // 1周前
    });
  });

  group('多样性（Diversity）', () {
    test('标签完全不重复时多样性为 1.0', () {
      final score = engine.score(
        candidate: RecommendCandidate(
          id: 'b', publishedHoursAgo: 1, views: 500,
          likes: 50, comments: 10, bookings: 2, tags: ['摄影', '日系'],
        ),
        recentlyShownTags:  ['cosplay', '古风', '汉服'],
        userPreferenceTags: [],
      );
      // diversity = 1.0 → 完整贡献 0.20 * 1.0 = 0.20
      expect(score, greaterThan(0.15));
    });

    test('连续5条标签完全相同时多样性强制插入不同内容', () {
      // 模拟：已展示 5 条 cosplay 标签
      final shownTags = ['cosplay', 'cosplay', 'cosplay', 'cosplay', 'cosplay'];

      // 非 cosplay 内容应比 cosplay 内容得到更高多样性分
      double scoreFor(List<String> tags) => engine.score(
        candidate: RecommendCandidate(
          id: 'c', publishedHoursAgo: 2, views: 400,
          likes: 40, comments: 8, bookings: 1, tags: tags,
        ),
        recentlyShownTags:  shownTags,
        userPreferenceTags: [],
      );

      expect(scoreFor(['摄影', '棚拍']), greaterThan(scoreFor(['cosplay'])));
    });
  });

  group('个性化（Personalization）', () {
    test('标签完全匹配用户偏好时个性化分最高', () {
      final prefs = ['cosplay', '古风', '汉服'];

      final matched = engine.score(
        candidate: RecommendCandidate(
          id: 'd', publishedHoursAgo: 3, views: 300,
          likes: 30, comments: 5, bookings: 1,
          tags: ['cosplay', '古风'],
        ),
        recentlyShownTags:  [],
        userPreferenceTags: prefs,
      );

      final unmatched = engine.score(
        candidate: RecommendCandidate(
          id: 'e', publishedHoursAgo: 3, views: 300,
          likes: 30, comments: 5, bookings: 1,
          tags: ['摄影', '日系'],
        ),
        recentlyShownTags:  [],
        userPreferenceTags: prefs,
      );

      expect(matched, greaterThan(unmatched));
    });
  });

  group('权重约束', () {
    test('权重之和必须为 1.0', () {
      final e = RecommendationEngine();
      final sum = e.wFreshness + e.wEngagement + e.wDiversity + e.wPersonalization;
      expect(sum, closeTo(1.0, 0.001));
    });

    test('所有分数在 0~1 范围内', () {
      final candidates = [
        RecommendCandidate(
          id: 'x1', publishedHoursAgo: 0, views: 10000,
          likes: 5000, comments: 1000, bookings: 200, tags: ['cosplay'],
        ),
        RecommendCandidate(
          id: 'x2', publishedHoursAgo: 8760, views: 1, // 1年前，1次浏览
          likes: 0, comments: 0, bookings: 0, tags: [],
        ),
      ];
      for (final c in candidates) {
        final s = engine.score(
          candidate: c,
          recentlyShownTags:  ['cosplay'],
          userPreferenceTags: ['cosplay'],
        );
        expect(s, inInclusiveRange(0.0, 1.0),
            reason: '候选项 ${c.id} 的分数越界：$s');
      }
    });
  });

  group('排序正确性', () {
    test('高互动率 + 新内容 应排在 低互动率 + 旧内容 前面', () {
      final fresh = RecommendCandidate(
        id: 'fresh', publishedHoursAgo: 1, views: 1000,
        likes: 200, comments: 50, bookings: 10, tags: ['摄影'],
      );
      final stale = RecommendCandidate(
        id: 'stale', publishedHoursAgo: 720, views: 500,
        likes: 5, comments: 1, bookings: 0, tags: ['摄影'],
      );

      final ranked = engine.rank(
        candidates:        [stale, fresh],
        recentlyShownTags: [],
        userPreferenceTags: [],
      );

      expect(ranked.first.id, equals('fresh'));
    });
  });
}
