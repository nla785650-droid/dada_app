import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ══════════════════════════════════════════════════════════════
// LocationProvider：实时位置追踪 Provider
//
// 架构：
//   · Mock 位置模拟（生产环境接入 geolocator 包替换）
//   · 每 4 秒上传位置到 Supabase user_locations 表
//   · 监听对方位置变化（Realtime stream）
//   · 地理围栏检测（约定位置 vs 当前位置偏移）
// ══════════════════════════════════════════════════════════════

// ── 位置数据模型 ──
class LocationPoint {
  const LocationPoint({
    required this.lat,
    required this.lng,
    this.accuracy,
    this.address,
    this.updatedAt,
  });

  final double lat;
  final double lng;
  final double? accuracy;
  final String? address;
  final DateTime? updatedAt;

  factory LocationPoint.fromJson(Map<String, dynamic> json) => LocationPoint(
        lat:       (json['latitude'] as num).toDouble(),
        lng:       (json['longitude'] as num).toDouble(),
        accuracy:  (json['accuracy'] as num?)?.toDouble(),
        address:   json['address_text'] as String?,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  // 计算两点间距离（Haversine 公式，单位：米）
  double distanceTo(LocationPoint other) {
    const r = 6371000.0; // 地球半径（米）
    final dLat = _rad(other.lat - lat);
    final dLng = _rad(other.lng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat)) *
            math.cos(_rad(other.lat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double deg) => deg * math.pi / 180;

  String get shortAddress => address?.split('市').last ?? '定位中...';

  @override
  String toString() => 'Loc(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
}

// ── 安全状态 ──
enum GuardianMode { inactive, active, paused, ended }

enum GeofenceStatus { normal, warning, breach }

class SafetyState {
  const SafetyState({
    this.myLocation,
    this.partnerLocation,
    this.guardianMode = GuardianMode.inactive,
    this.geofenceStatus = GeofenceStatus.normal,
    this.geofenceDistanceMeters = 0,
    this.isTracking = false,
    this.isPanicTriggered = false,
    this.panicCooldown = false,
    this.tripShareUrl,
    this.lastAlert,
    this.myPath = const [],
  });

  final LocationPoint? myLocation;
  final LocationPoint? partnerLocation;
  final GuardianMode guardianMode;
  final GeofenceStatus geofenceStatus;
  final double geofenceDistanceMeters;
  final bool isTracking;
  final bool isPanicTriggered;
  final bool panicCooldown;
  final String? tripShareUrl;
  final String? lastAlert;
  final List<LocationPoint> myPath; // 路径记录（最近 50 个点）

  bool get isGuardianActive => guardianMode == GuardianMode.active;
  bool get hasAlert => geofenceStatus != GeofenceStatus.normal;

  SafetyState copyWith({
    LocationPoint? myLocation,
    LocationPoint? partnerLocation,
    GuardianMode? guardianMode,
    GeofenceStatus? geofenceStatus,
    double? geofenceDistanceMeters,
    bool? isTracking,
    bool? isPanicTriggered,
    bool? panicCooldown,
    String? tripShareUrl,
    String? lastAlert,
    List<LocationPoint>? myPath,
  }) =>
      SafetyState(
        myLocation:              myLocation              ?? this.myLocation,
        partnerLocation:         partnerLocation         ?? this.partnerLocation,
        guardianMode:            guardianMode            ?? this.guardianMode,
        geofenceStatus:          geofenceStatus          ?? this.geofenceStatus,
        geofenceDistanceMeters:  geofenceDistanceMeters  ?? this.geofenceDistanceMeters,
        isTracking:              isTracking              ?? this.isTracking,
        isPanicTriggered:        isPanicTriggered        ?? this.isPanicTriggered,
        panicCooldown:           panicCooldown           ?? this.panicCooldown,
        tripShareUrl:            tripShareUrl            ?? this.tripShareUrl,
        lastAlert:               lastAlert               ?? this.lastAlert,
        myPath:                  myPath                  ?? this.myPath,
      );
}

// ── Provider ──

class SafetyNotifier extends StateNotifier<SafetyState> {
  SafetyNotifier() : super(const SafetyState());

  static SupabaseClient get _db => Supabase.instance.client;

  Timer? _locationTimer;
  StreamSubscription? _partnerSub;
  String? _bookingId;

  // 模拟上海中心区域的基础坐标（生产环境替换为真实 geolocator）
  static const _baseLat = 31.2304;
  static const _baseLng = 121.4737;
  final _rng = math.Random();
  double _mockLatOffset = 0;
  double _mockLngOffset = 0;

  // ── 开始守护模式（卖家扫码核销后调用）──
  Future<void> startGuardian(String bookingId) async {
    _bookingId = bookingId;
    state = state.copyWith(
      guardianMode: GuardianMode.active,
      isTracking:   true,
    );

    // 立即获取一次位置
    await _updateMyLocation();

    // 每 4 秒上传一次
    _locationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _updateMyLocation();
    });

    // 监听对方位置
    _subscribePartnerLocation(bookingId);

    // 生成分享 URL
    final myLoc = state.myLocation;
    if (myLoc != null) {
      state = state.copyWith(
        tripShareUrl:
            'https://maps.google.com/?q=${myLoc.lat},${myLoc.lng}&t=k',
      );
    }
  }

  // ── 暂停/停止守护 ──
  void pauseGuardian() {
    _locationTimer?.cancel();
    state = state.copyWith(
      guardianMode: GuardianMode.paused,
      isTracking:   false,
    );
  }

  void endGuardian() {
    _locationTimer?.cancel();
    _partnerSub?.cancel();
    state = state.copyWith(
      guardianMode: GuardianMode.ended,
      isTracking:   false,
    );
  }

  // ── 位置更新（Mock + Supabase upsert）──
  Future<void> _updateMyLocation() async {
    // Mock：在基础坐标附近随机小幅漂移（模拟步行）
    _mockLatOffset += (_rng.nextDouble() - 0.5) * 0.0001;
    _mockLngOffset += (_rng.nextDouble() - 0.5) * 0.0001;

    final lat = _baseLat + _mockLatOffset;
    final lng = _baseLng + _mockLngOffset;

    final newPoint = LocationPoint(
      lat:       lat,
      lng:       lng,
      accuracy:  5.0 + _rng.nextDouble() * 10,
      address:   '上海市徐汇区 · 模拟位置',
      updatedAt: DateTime.now(),
    );

    // 追加路径（最多保留 50 个点）
    final newPath = [...state.myPath, newPoint];
    if (newPath.length > 50) newPath.removeAt(0);

    state = state.copyWith(myLocation: newPoint, myPath: newPath);

    // 检查地理围栏（约定地点 vs 实际位置）
    _checkGeofence(newPoint);

    // 上传到 Supabase
    try {
      final uid = _db.auth.currentUser?.id;
      if (uid != null && _bookingId != null) {
        await _db.rpc('update_my_location', params: {
          'p_booking_id': _bookingId,
          'p_latitude':   lat,
          'p_longitude':  lng,
          'p_accuracy':   5.0,
          'p_address':    newPoint.address,
        });
      }
    } catch (_) {
      // 上传失败不影响 UI（离线可用）
    }
  }

  // ── 地理围栏检测 ──
  void _checkGeofence(LocationPoint current) {
    // 模拟约定地点（生产环境从 bookings.location_lat/lng 读取）
    final agreed = const LocationPoint(lat: _baseLat, lng: _baseLng);
    final dist = current.distanceTo(agreed);

    GeofenceStatus status;
    String? alert;

    if (dist > 500) {
      status = GeofenceStatus.breach;
      alert = '⚠️ 检测到偏离路线 ${dist.toStringAsFixed(0)}m，请确认安全';
    } else if (dist > 300) {
      status = GeofenceStatus.warning;
      alert = '注意：距约定地点 ${dist.toStringAsFixed(0)}m';
    } else {
      status = GeofenceStatus.normal;
    }

    if (status != state.geofenceStatus) {
      state = state.copyWith(
        geofenceStatus:         status,
        geofenceDistanceMeters: dist,
        lastAlert:              alert,
      );
    } else {
      state = state.copyWith(geofenceDistanceMeters: dist);
    }
  }

  // ── 监听对方位置（Supabase Realtime）──
  void _subscribePartnerLocation(String bookingId) {
    _partnerSub?.cancel();
    try {
      _partnerSub = _db
          .from('user_locations')
          .stream(primaryKey: ['id'])
          .eq('booking_id', bookingId)
          .listen((data) {
        if (data.isEmpty) return;
        final myUid = _db.auth.currentUser?.id;
        // 找对方的位置（不是自己的）
        final partnerData = data.firstWhere(
          (d) => d['user_id'] != myUid,
          orElse: () => <String, dynamic>{},
        );
        if (partnerData.isNotEmpty) {
          try {
            state = state.copyWith(
              partnerLocation: LocationPoint.fromJson(partnerData),
            );
          } catch (_) {}
        }
      });
    } catch (_) {
      // 模拟对方位置（演示）
      _simulatePartnerLocation();
    }
  }

  void _simulatePartnerLocation() {
    Timer.periodic(const Duration(seconds: 5), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final lat = _baseLat + (_rng.nextDouble() - 0.5) * 0.003;
      final lng = _baseLng + (_rng.nextDouble() - 0.5) * 0.003;
      state = state.copyWith(
        partnerLocation: LocationPoint(
          lat:       lat,
          lng:       lng,
          address:   '上海市静安区 · 对方位置',
          updatedAt: DateTime.now(),
        ),
      );
    });
  }

  // ── 一键报警 ──
  Future<bool> triggerPanic(String bookingId) async {
    if (state.panicCooldown) return false;

    state = state.copyWith(isPanicTriggered: true, panicCooldown: true);

    try {
      final loc = state.myLocation;
      await _db.rpc('trigger_panic', params: {
        'p_booking_id': bookingId,
        'p_latitude':   loc?.lat ?? 0,
        'p_longitude':  loc?.lng ?? 0,
        'p_message':    '用户触发了紧急求助',
      });
    } catch (_) {
      // 即使 RPC 失败，依然完成本地状态变更（给用户反馈）
    }

    // 60 秒冷却
    Timer(const Duration(seconds: 60), () {
      if (mounted) {
        state = state.copyWith(panicCooldown: false);
      }
    });

    return true;
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _partnerSub?.cancel();
    super.dispose();
  }
}

// ── Family Provider（每个 bookingId 独立实例）──
final safetyProvider =
    StateNotifierProvider.family<SafetyNotifier, SafetyState, String>(
  (ref, bookingId) => SafetyNotifier(),
);

// 单例版本（全局安全状态，用于守护模式常驻）
final globalSafetyProvider =
    StateNotifierProvider<SafetyNotifier, SafetyState>(
  (_) => SafetyNotifier(),
);
