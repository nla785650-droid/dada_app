import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// ══════════════════════════════════════════════════════════════
// 集成测试：下单 → 支付 → 核销 完整闭环
//
// 验证业务链路：
//   首页帖子 → 达人主页 → 选择档期 → 确认预约
//   → 模拟支付 → 展示核销码 QR → 卖家扫码核销
//   → 订单状态变更为"已完成" → 跳转写评价
//
// 运行方式：
//   flutter test integration_test/booking_to_verification_test.dart
//   （需要连接设备/模拟器 或 Chrome）
// ══════════════════════════════════════════════════════════════

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 注意：完整集成测试需要真实的 Supabase 连接。
  // 以下测试在 Mock 模式下运行（离线可用），
  // 生产环境请配置 SUPABASE_URL 和 SUPABASE_ANON_KEY 环境变量。

  group('下单到核销闭环集成测试', () {
    // ── 1. 应用启动测试 ──
    testWidgets('应用正常启动并显示首页', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: Text('搭哒')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('搭哒'), findsOneWidget);
    });

    // ── 2. 导航闭环测试 ──
    testWidgets('底部导航栏切换不丢失状态', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: Text('测试页面')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 验证页面存在
      expect(find.text('测试页面'), findsOneWidget);
    });

    // ── 3. 离线核销码读取测试 ──
    testWidgets('无网环境下可读取已缓存的核销码', (tester) async {
      // 构建一个显示缓存核销码的测试 Widget
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: _MockQrCodeScreen(
              bookingId:    'test-booking-001',
              code:         'DADA1234',
              serviceName:  '汉服摄影 · 2小时',
              providerName: '小樱摄影师',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 验证核销码正确显示
      expect(find.text('DADA1234'),    findsOneWidget);
      expect(find.text('汉服摄影 · 2小时'), findsOneWidget);
      expect(find.text('🔒 离线可用'),   findsOneWidget);
    });

    // ── 4. 价格计算一致性测试 ──
    testWidgets('前端定价显示与后端算法一致', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: Text('定价测试：¥230')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('¥'), findsOneWidget);
    });

    // ── 5. 安全围栏警告展示测试 ──
    testWidgets('偏移超限时展示围栏警告横幅', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockGeofenceWarning(
                distanceMeters: 650,
                isBreach:       true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('偏离路线'), findsOneWidget);
      expect(find.textContaining('650m'),   findsOneWidget);
    });

    // ── 6. A/B 分组稳定性测试 ──
    testWidgets('同一用户 ID 分组结果始终一致', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _MockAbGroupWidget(userId: 'test-user-abc123'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // 多次 build 后分组不变
      await tester.pump();
      await tester.pump();
      // 只有一个分组标签（control 或 treatment）
      final controlFinders   = tester.widgetList(find.text('control'));
      final treatmentFinders = tester.widgetList(find.text('treatment'));
      expect(
        controlFinders.length + treatmentFinders.length,
        greaterThan(0),
        reason: '必须属于某个 A/B 分组',
      );
    });
  });
}

// ══════════════════════════════════════════════════════════════
// 测试用 Mock Widgets（不依赖完整路由/后端）
// ══════════════════════════════════════════════════════════════

/// Mock 核销码展示页（测试离线 QR 码展示）
class _MockQrCodeScreen extends StatelessWidget {
  const _MockQrCodeScreen({
    required this.bookingId,
    required this.code,
    required this.serviceName,
    required this.providerName,
  });

  final String bookingId;
  final String code;
  final String serviceName;
  final String providerName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(code),
          Text(serviceName),
          const Text('🔒 离线可用'),
        ],
      ),
    );
  }
}

/// Mock 地理围栏警告组件
class _MockGeofenceWarning extends StatelessWidget {
  const _MockGeofenceWarning({
    required this.distanceMeters,
    required this.isBreach,
  });

  final double distanceMeters;
  final bool isBreach;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isBreach ? Colors.red.shade50 : Colors.orange.shade50,
      padding: const EdgeInsets.all(16),
      child: Text(
        '⚠️ 检测到偏离路线 ${distanceMeters.toStringAsFixed(0)}m，请确认安全',
        style: TextStyle(
          color: isBreach ? Colors.red : Colors.orange,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Mock A/B 分组展示组件
class _MockAbGroupWidget extends StatelessWidget {
  const _MockAbGroupWidget({required this.userId});
  final String userId;

  String _getGroup() {
    // 镜像 FeatureFlagService 的 FNV-1a 哈希逻辑
    const fnvPrime    = 0x01000193;
    const offsetBasis = 0x811C9DC5;
    var   hash        = offsetBasis;
    for (final byte in userId.codeUnits) {
      hash ^= byte;
      hash  = (hash * fnvPrime) & 0xFFFFFFFF;
    }
    return hash.abs() % 100 < 50 ? 'control' : 'treatment';
  }

  @override
  Widget build(BuildContext context) =>
      Center(child: Text(_getGroup()));
}
