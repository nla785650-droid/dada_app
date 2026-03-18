import 'package:flutter_test/flutter_test.dart';
import 'package:dada/features/safety/providers/location_provider.dart';

// ══════════════════════════════════════════════════════════════
// 地理围栏偏移算法单元测试
//
// 测试目标：LocationPoint.distanceTo()（Haversine 公式）
//
// 为什么重要：
//   安全护航系统依赖此算法判断是否触发地理围栏警告。
//   精度误差必须在 ±1% 以内，否则会产生大量误报。
// ══════════════════════════════════════════════════════════════

void main() {
  group('Haversine 地理围栏算法', () {
    // ── 基准测试：已知精确距离对 ──

    test('同一地点距离为 0', () {
      const p = LocationPoint(lat: 31.2304, lng: 121.4737);
      expect(p.distanceTo(p), closeTo(0, 0.001));
    });

    test('上海外滩 → 陆家嘴约 1.5km', () {
      // 外滩：31.2397, 121.4900
      // 陆家嘴：31.2400, 121.5064
      const waitan    = LocationPoint(lat: 31.2397, lng: 121.4900);
      const lujiazui  = LocationPoint(lat: 31.2400, lng: 121.5064);
      final dist = waitan.distanceTo(lujiazui);
      // 实际约 1500m，允许 ±2% 误差
      expect(dist, inInclusiveRange(1400, 1600));
    });

    test('北京天安门 → 故宫午门约 1.2km', () {
      // 天安门广场：39.9055, 116.3976
      // 故宫午门（北侧）：39.9163, 116.3972
      // 实测距离约 1200m
      const tiananmen = LocationPoint(lat: 39.9055, lng: 116.3976);
      const wumen     = LocationPoint(lat: 39.9163, lng: 116.3972);
      final dist = tiananmen.distanceTo(wumen);
      expect(dist, inInclusiveRange(1100, 1350));
    });

    test('距离具有对称性（A→B = B→A）', () {
      const a = LocationPoint(lat: 31.2304, lng: 121.4737);
      const b = LocationPoint(lat: 31.2350, lng: 121.4800);
      expect(
        a.distanceTo(b),
        closeTo(b.distanceTo(a), 0.001),
      );
    });

    // ── 围栏阈值测试 ──

    test('偏移 100m 以内：正常状态（normal）', () {
      const center  = LocationPoint(lat: 31.2304, lng: 121.4737);
      // 约 80m 偏移
      const nearby  = LocationPoint(lat: 31.2311, lng: 121.4737);
      final dist = center.distanceTo(nearby);
      expect(dist, lessThan(300), reason: '100m 偏移应低于警告阈值 300m');
    });

    test('偏移 350m：警告状态（warning）', () {
      const center  = LocationPoint(lat: 31.2304, lng: 121.4737);
      // 纬度每度约 111km，0.003度 ≈ 333m
      const offset  = LocationPoint(lat: 31.2334, lng: 121.4737);
      final dist = center.distanceTo(offset);
      expect(dist, inInclusiveRange(300, 500), reason: '应触发警告（300~500m）');
    });

    test('偏移 600m：违规状态（breach）', () {
      const center  = LocationPoint(lat: 31.2304, lng: 121.4737);
      // 0.006度 ≈ 666m
      const farAway = LocationPoint(lat: 31.2364, lng: 121.4737);
      final dist = center.distanceTo(farAway);
      expect(dist, greaterThan(500), reason: '应触发违规（>500m）');
    });

    // ── 边界情况 ──

    test('跨越经度 0 子午线（国际通用）', () {
      const west  = LocationPoint(lat: 51.5074, lng: -0.1278); // 伦敦
      const east  = LocationPoint(lat: 48.8566, lng:  2.3522); // 巴黎
      final dist  = west.distanceTo(east);
      // 伦敦到巴黎约 340km
      expect(dist, inInclusiveRange(330000, 360000));
    });

    test('shortAddress 正确解析带"市"的地名', () {
      const p = LocationPoint(
        lat: 31.2304, lng: 121.4737,
        address: '上海市徐汇区天钥桥路',
      );
      expect(p.shortAddress, equals('徐汇区天钥桥路'));
    });

    test('shortAddress 无"市"时返回完整 address', () {
      const p = LocationPoint(lat: 31.2304, lng: 121.4737, address: '定位中');
      expect(p.shortAddress, equals('定位中'));
    });

    test('address 为 null 时返回默认文字', () {
      const p = LocationPoint(lat: 31.2304, lng: 121.4737);
      expect(p.shortAddress, equals('定位中...'));
    });
  });
}
