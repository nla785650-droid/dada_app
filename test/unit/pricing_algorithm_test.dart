import 'package:flutter_test/flutter_test.dart';

// ══════════════════════════════════════════════════════════════
// 动态定价建议算法单元测试
//
// 测试目标：
//   · 评分系数计算（ratingFactor）
//   · AI 审美分系数计算（aestheticFactor）
//   · ±15% 价格区间生成
//   · 市场百分位置信度标注
//
// 注意：此测试为纯 Dart 层算法测试（不依赖 Supabase）
// 与后端 SQL 函数逻辑镜像，确保前后端定价结果一致
// ══════════════════════════════════════════════════════════════

/// 镜像 SQL 函数 get_price_recommendation 的 Dart 实现
/// 用于前端预计算定价建议（供达人填写价格时实时显示参考）
class PriceRecommendationEngine {
  const PriceRecommendationEngine();

  PriceRecommendation calculate({
    required double marketAvgPrice,
    required double providerRating,      // 0.0 ~ 5.0
    required double aiAestheticScore,    // 0.0 ~ 5.0
    required int sampleCount,
  }) {
    // 与 SQL 函数完全对应的系数公式
    final ratingFactor    = 0.75 + (providerRating / 5.0) * 0.40;
    final aestheticFactor = 0.90 + (aiAestheticScore / 5.0) * 0.20;
    final basePrice = _roundToTen(
      marketAvgPrice * ratingFactor * aestheticFactor,
    );

    return PriceRecommendation(
      suggestedPrice:   basePrice,
      priceLow:         _roundToTen(basePrice * 0.85),
      priceHigh:        _roundToTen(basePrice * 1.15),
      marketAvg:        marketAvgPrice,
      ratingFactor:     ratingFactor,
      aestheticFactor:  aestheticFactor,
      confidence:       sampleCount >= 20
          ? 'high'
          : sampleCount >= 5
              ? 'medium'
              : 'low',
    );
  }

  double _roundToTen(double v) => (v / 10).round() * 10.0;
}

class PriceRecommendation {
  const PriceRecommendation({
    required this.suggestedPrice,
    required this.priceLow,
    required this.priceHigh,
    required this.marketAvg,
    required this.ratingFactor,
    required this.aestheticFactor,
    required this.confidence,
  });

  final double suggestedPrice;
  final double priceLow;
  final double priceHigh;
  final double marketAvg;
  final double ratingFactor;
  final double aestheticFactor;
  final String confidence;
}

// ──────────────────────────────────────────────────────────────

void main() {
  final engine = PriceRecommendationEngine();

  group('评分系数（ratingFactor）', () {
    test('评分 3.0 → 系数约 0.99', () {
      final r = engine.calculate(
        marketAvgPrice:   200,
        providerRating:   3.0,
        aiAestheticScore: 3.0,
        sampleCount:      10,
      );
      // ratingFactor = 0.75 + 0.6 * 0.40 = 0.99
      expect(r.ratingFactor, closeTo(0.99, 0.001));
    });

    test('评分 5.0 → 系数为 1.15（满分）', () {
      final r = engine.calculate(
        marketAvgPrice:   200,
        providerRating:   5.0,
        aiAestheticScore: 3.0,
        sampleCount:      10,
      );
      // ratingFactor = 0.75 + 1.0 * 0.40 = 1.15
      expect(r.ratingFactor, closeTo(1.15, 0.001));
    });

    test('评分 0 → 系数为 0.75（基准下限）', () {
      final r = engine.calculate(
        marketAvgPrice:   200,
        providerRating:   0.0,
        aiAestheticScore: 3.0,
        sampleCount:      10,
      );
      expect(r.ratingFactor, closeTo(0.75, 0.001));
    });
  });

  group('AI 审美分系数（aestheticFactor）', () {
    test('审美分 0 → 系数 0.90（下限）', () {
      final r = engine.calculate(
        marketAvgPrice:   200,
        providerRating:   4.0,
        aiAestheticScore: 0.0,
        sampleCount:      10,
      );
      expect(r.aestheticFactor, closeTo(0.90, 0.001));
    });

    test('审美分 5 → 系数 1.10（上限）', () {
      final r = engine.calculate(
        marketAvgPrice:   200,
        providerRating:   4.0,
        aiAestheticScore: 5.0,
        sampleCount:      10,
      );
      expect(r.aestheticFactor, closeTo(1.10, 0.001));
    });
  });

  group('价格区间计算', () {
    test('±15% 区间边界正确', () {
      final r = engine.calculate(
        marketAvgPrice:   200,
        providerRating:   4.0,
        aiAestheticScore: 4.0,
        sampleCount:      15,
      );
      expect(r.priceLow,  closeTo(r.suggestedPrice * 0.85, 10));
      expect(r.priceHigh, closeTo(r.suggestedPrice * 1.15, 10));
    });

    test('建议价在区间内', () {
      final r = engine.calculate(
        marketAvgPrice:   350,
        providerRating:   4.5,
        aiAestheticScore: 4.2,
        sampleCount:      30,
      );
      expect(r.suggestedPrice, greaterThanOrEqualTo(r.priceLow));
      expect(r.suggestedPrice, lessThanOrEqualTo(r.priceHigh));
    });

    test('价格舍入到 10 的倍数', () {
      final r = engine.calculate(
        marketAvgPrice:   175,
        providerRating:   3.7,
        aiAestheticScore: 3.5,
        sampleCount:      8,
      );
      expect(r.suggestedPrice % 10, equals(0));
      expect(r.priceLow       % 10, equals(0));
      expect(r.priceHigh      % 10, equals(0));
    });

    test('低市场均价（如 50元）也能正常工作', () {
      final r = engine.calculate(
        marketAvgPrice:   50,
        providerRating:   4.0,
        aiAestheticScore: 3.0,
        sampleCount:      3,
      );
      expect(r.suggestedPrice, greaterThan(0));
      expect(r.priceLow, lessThan(r.priceHigh));
    });
  });

  group('置信度分级', () {
    test('样本 >= 20 → high 置信度', () {
      final r = engine.calculate(
        marketAvgPrice:   200,
        providerRating:   4.0,
        aiAestheticScore: 4.0,
        sampleCount:      20,
      );
      expect(r.confidence, equals('high'));
    });

    test('样本 5~19 → medium 置信度', () {
      final r = engine.calculate(
        marketAvgPrice:   200,
        providerRating:   4.0,
        aiAestheticScore: 4.0,
        sampleCount:      10,
      );
      expect(r.confidence, equals('medium'));
    });

    test('样本 < 5 → low 置信度', () {
      final r = engine.calculate(
        marketAvgPrice:   200,
        providerRating:   4.0,
        aiAestheticScore: 4.0,
        sampleCount:      0,
      );
      expect(r.confidence, equals('low'));
    });
  });

  group('综合场景测试', () {
    test('顶级达人（5.0分 + 5审美 + 充足样本）应高于市场均价', () {
      final r = engine.calculate(
        marketAvgPrice:   200,
        providerRating:   5.0,
        aiAestheticScore: 5.0,
        sampleCount:      50,
      );
      expect(r.suggestedPrice, greaterThan(200));
      expect(r.confidence, equals('high'));
    });

    test('新人达人（3.0分 + 2审美 + 无样本）应低于市场均价', () {
      final r = engine.calculate(
        marketAvgPrice:   200,
        providerRating:   3.0,
        aiAestheticScore: 2.0,
        sampleCount:      0,
      );
      expect(r.suggestedPrice, lessThan(200));
      expect(r.confidence, equals('low'));
    });
  });
}
