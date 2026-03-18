import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════
// OfflineCacheService — 离线持久化服务
//
// 双层存储策略：
//   · [加密层] FlutterSecureStorage → 订单核销码（含 bookingId）
//     原因：核销码是财务凭证，明文存储有被伪造风险
//   · [普通层] SharedPreferences → 最近浏览记录、用户偏好
//     原因：非敏感数据，优先读写速度
//
// Clean Architecture：本文件属于 Infrastructure Layer
// 上层通过 Provider 调用，不直接依赖 storage 实现
// ══════════════════════════════════════════════════════════════

// ── 核销码缓存模型 ──
class CachedVerificationCode {
  const CachedVerificationCode({
    required this.bookingId,
    required this.code,
    required this.serviceName,
    required this.providerName,
    required this.amount,
    required this.cachedAt,
    this.expiresAt,
  });

  final String bookingId;
  final String code;
  final String serviceName;
  final String providerName;
  final double amount;
  final DateTime cachedAt;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && DateTime.now().isAfter(expiresAt!);

  Map<String, dynamic> toJson() => {
        'bookingId':    bookingId,
        'code':         code,
        'serviceName':  serviceName,
        'providerName': providerName,
        'amount':       amount,
        'cachedAt':     cachedAt.toIso8601String(),
        'expiresAt':    expiresAt?.toIso8601String(),
      };

  factory CachedVerificationCode.fromJson(Map<String, dynamic> j) =>
      CachedVerificationCode(
        bookingId:    j['bookingId'] as String,
        code:         j['code'] as String,
        serviceName:  j['serviceName'] as String,
        providerName: j['providerName'] as String,
        amount:       (j['amount'] as num).toDouble(),
        cachedAt:     DateTime.parse(j['cachedAt'] as String),
        expiresAt:    j['expiresAt'] != null
            ? DateTime.parse(j['expiresAt'] as String)
            : null,
      );
}

// ── 最近浏览记录模型 ──
class RecentlyViewedItem {
  const RecentlyViewedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.imageUrl,
    required this.viewedAt,
    this.extra,
  });

  final String id;
  final String type;          // 'post' | 'provider'
  final String title;
  final String imageUrl;
  final DateTime viewedAt;
  final Map<String, dynamic>? extra;

  Map<String, dynamic> toJson() => {
        'id':       id,
        'type':     type,
        'title':    title,
        'imageUrl': imageUrl,
        'viewedAt': viewedAt.toIso8601String(),
        'extra':    extra,
      };

  factory RecentlyViewedItem.fromJson(Map<String, dynamic> j) =>
      RecentlyViewedItem(
        id:       j['id'] as String,
        type:     j['type'] as String,
        title:    j['title'] as String,
        imageUrl: j['imageUrl'] as String,
        viewedAt: DateTime.parse(j['viewedAt'] as String),
        extra:    j['extra'] as Map<String, dynamic>?,
      );
}

// ══════════════════════════════════════════════════════════════
// OfflineCacheService
// ══════════════════════════════════════════════════════════════

class OfflineCacheService {
  OfflineCacheService({
    required SharedPreferences prefs,
    required FlutterSecureStorage secureStorage,
  })  : _prefs = prefs,
        _secure = secureStorage;

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  // ── Key 常量 ──
  static const _keyRecentViews   = 'recently_viewed_v2';
  static const _keyVerifPrefix   = 'verif_'; // + bookingId
  static const _maxRecentViews   = 30;
  static const _maxVerifCodes    = 20;

  // ══════════════════════════════════════════════════════════
  // 核销码：加密存储
  // ══════════════════════════════════════════════════════════

  /// 保存核销码（支付成功后调用，确保离线也能出示）
  Future<void> saveVerificationCode(CachedVerificationCode entry) async {
    await _secure.write(
      key:   '$_keyVerifPrefix${entry.bookingId}',
      value: jsonEncode(entry.toJson()),
    );
    // 同时维护一个索引列表（记录所有 bookingId）
    final ids = await _getVerifIds();
    if (!ids.contains(entry.bookingId)) {
      ids.add(entry.bookingId);
      // 超出上限时删除最旧的
      if (ids.length > _maxVerifCodes) {
        final oldest = ids.removeAt(0);
        await _secure.delete(key: '$_keyVerifPrefix$oldest');
      }
      await _prefs.setStringList('verif_index', ids);
    }
  }

  /// 读取单条核销码
  Future<CachedVerificationCode?> getVerificationCode(String bookingId) async {
    try {
      final raw = await _secure.read(key: '$_keyVerifPrefix$bookingId');
      if (raw == null) return null;
      return CachedVerificationCode.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// 读取所有未过期核销码（供"我的订单"离线展示）
  Future<List<CachedVerificationCode>> getAllValidCodes() async {
    final ids = await _getVerifIds();
    final results = <CachedVerificationCode>[];
    for (final id in ids) {
      final code = await getVerificationCode(id);
      if (code != null && !code.isExpired) results.add(code);
    }
    return results;
  }

  /// 删除核销码（核销完成后清理）
  Future<void> deleteVerificationCode(String bookingId) async {
    await _secure.delete(key: '$_keyVerifPrefix$bookingId');
    final ids = await _getVerifIds()..remove(bookingId);
    await _prefs.setStringList('verif_index', ids);
  }

  Future<List<String>> _getVerifIds() async =>
      List<String>.from(_prefs.getStringList('verif_index') ?? []);

  // ══════════════════════════════════════════════════════════
  // 最近浏览：普通存储
  // ══════════════════════════════════════════════════════════

  /// 记录浏览（自动去重 + 置顶）
  Future<void> recordView(RecentlyViewedItem item) async {
    final list = await getRecentViews();
    list.removeWhere((e) => e.id == item.id && e.type == item.type);
    list.insert(0, item);
    if (list.length > _maxRecentViews) list.removeLast();
    await _prefs.setString(
      _keyRecentViews,
      jsonEncode(list.map((e) => e.toJson()).toList()),
    );
  }

  /// 获取最近浏览列表
  Future<List<RecentlyViewedItem>> getRecentViews({int limit = 20}) async {
    try {
      final raw = _prefs.getString(_keyRecentViews);
      if (raw == null) return [];
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map(RecentlyViewedItem.fromJson)
          .toList();
      return list.take(limit).toList();
    } catch (_) {
      return [];
    }
  }

  /// 清空最近浏览
  Future<void> clearRecentViews() =>
      _prefs.remove(_keyRecentViews);

  // ══════════════════════════════════════════════════════════
  // 用户偏好（A/B 测试、筛选状态）
  // ══════════════════════════════════════════════════════════

  Future<void> saveUserPref(String key, String value) =>
      _prefs.setString('pref_$key', value);

  String? getUserPref(String key) => _prefs.getString('pref_$key');

  Future<void> clearAll() async {
    await _prefs.clear();
    await _secure.deleteAll();
  }
}

// ── Providers ──

final sharedPrefsProvider = FutureProvider<SharedPreferences>((ref) =>
    SharedPreferences.getInstance());

final offlineCacheProvider = Provider<OfflineCacheService?>((ref) {
  final prefsAsync = ref.watch(sharedPrefsProvider);
  return prefsAsync.maybeWhen(
    data: (prefs) => OfflineCacheService(
      prefs:         prefs,
      secureStorage: const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ),
    ),
    orElse: () => null,
  );
});

// 便捷 Provider：等待初始化完成
final cacheServiceProvider = FutureProvider<OfflineCacheService>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return OfflineCacheService(
    prefs:         prefs,
    secureStorage: const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    ),
  );
});
