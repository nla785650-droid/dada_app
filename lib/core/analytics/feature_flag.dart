import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ══════════════════════════════════════════════════════════════
// FeatureFlagService — A/B 实验分组系统
//
// 分组策略（无需服务端依赖，可离线使用）：
//   1. 取 user_id 的 FNV-1a 哈希值
//   2. 对实验权重区间取模
//   3. 结果稳定（同一用户始终在同一组）
//
// 扩展性：
//   · 支持多个并行实验（每个实验独立 key）
//   · 远程配置可通过 Supabase `ab_experiments` 表覆盖
// ══════════════════════════════════════════════════════════════

// ── 实验 Key 枚举（新增实验只需加枚举值）──
enum ExperimentKey {
  discoverCardLayout('discover_card_layout_v2'),
  pricingDisplay('pricing_display_v1'),
  onboardingFlow('onboarding_flow_v1');

  const ExperimentKey(this.value);
  final String value;
}

// ── 实验变体 ──
enum CardLayoutVariant {
  control,    // 原始大图沉浸模式
  treatment,  // 紧凑信息卡（显示更多文字标签）
}

// ── FeatureFlagService ──
class FeatureFlagService {
  FeatureFlagService(this._userId);

  final String? _userId;

  // ── 核心：基于用户 ID 的稳定哈希分组 ──
  // 使用 FNV-1a 32-bit 哈希算法（轻量、碰撞率低）
  int _hashUserId(String userId) {
    const fnvPrime      = 0x01000193;
    const offsetBasis   = 0x811C9DC5;
    var   hash          = offsetBasis;

    for (final byte in userId.codeUnits) {
      hash ^= byte;
      hash  = (hash * fnvPrime) & 0xFFFFFFFF; // 保持 32-bit
    }
    return hash.abs();
  }

  // ── 获取用户在某实验的分组（0~99 的桶号）──
  int _getBucket(String experimentKey) {
    if (_userId == null) {
      // 未登录用户：随机分组（不稳定，可接受）
      return DateTime.now().millisecond % 100;
    }
    return _hashUserId('$_userId:$experimentKey') % 100;
  }

  // ── 卡片布局 A/B 实验 ──
  CardLayoutVariant get cardLayoutVariant {
    final bucket = _getBucket(ExperimentKey.discoverCardLayout.value);
    // 桶 0~49 → control，50~99 → treatment（各 50%）
    return bucket < 50 ? CardLayoutVariant.control : CardLayoutVariant.treatment;
  }

  bool get isControlGroup =>
      cardLayoutVariant == CardLayoutVariant.control;

  bool get isTreatmentGroup =>
      cardLayoutVariant == CardLayoutVariant.treatment;

  // ── A/B 分组标签（用于埋点上报）──
  String get abGroupLabel =>
      cardLayoutVariant == CardLayoutVariant.control ? 'control' : 'treatment';

  // ── 通用 feature flag（基于用户 ID 的奇偶）──
  /// 用户 ID 最后一位数字为偶数 → A 组；奇数 → B 组
  /// 简单明了，适用于快速测试
  bool get isEvenGroup {
    if (_userId == null) return true;
    final cleaned  = _userId.replaceAll('-', '');
    final lastChar = cleaned.isEmpty ? '0' : cleaned[cleaned.length - 1];
    final lastDigit = int.tryParse(lastChar) ?? 0;
    return lastDigit.isEven;
  }

  // ── 实验元数据（Debug 用）──
  Map<String, dynamic> get debugInfo => {
    'user_id':         _userId?.substring(0, 8) ?? 'anonymous',
    'card_layout':     cardLayoutVariant.name,
    'ab_group':        abGroupLabel,
    'is_even_group':   isEvenGroup,
    'bucket_discover': _getBucket(ExperimentKey.discoverCardLayout.value),
  };
}

// ── Riverpod Provider ──
final featureFlagProvider = Provider<FeatureFlagService>((ref) {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  return FeatureFlagService(userId);
});

// ── 便捷 Provider（直接访问卡片布局变体）──
final cardLayoutVariantProvider = Provider<CardLayoutVariant>((ref) {
  return ref.watch(featureFlagProvider).cardLayoutVariant;
});
