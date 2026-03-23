import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/provider_summary.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/home/screens/post_detail_screen.dart';
import '../../features/profile/screens/my_orders_screen.dart';
import '../../features/discover/screens/my_likes_screen.dart';
import '../../data/models/post_model.dart';
import '../../features/discover/screens/discover_screen.dart';
import '../../features/ai_lab/screens/ai_lab_screen.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/signup_screen.dart';
import '../../features/chat/screens/chat_list_screen.dart';
import '../../features/chat/screens/chat_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/fulfillment/screens/fulfillment_screen.dart';
import '../../features/payment/screens/payment_mock_screen.dart';
import '../../features/booking/screens/order_detail_screen.dart';
import '../../features/booking/screens/scanner_screen.dart';
import '../../features/provider/screens/provider_profile_screen.dart';
import '../../features/review/screens/review_screen.dart';
import '../../features/become_provider/screens/become_provider_screen.dart';
import '../../features/publish/screens/publish_center_screen.dart';
import '../../features/publish/screens/provider_dashboard_screen.dart';
import '../../features/publish/screens/provider_reviews_screen.dart';
import '../../features/search/screens/search_results_screen.dart';
import '../../shared/widgets/main_shell.dart';

// ══════════════════════════════════════════════════════════════
// AppRouter：搭哒全局路由表
//
// 架构：
//   StatefulShellRoute.indexedStack  → 5 个 Tab 保持状态
//   ├─ Branch 0: /home       首页瀑布流
//   ├─ Branch 1: /discover   划一划匹配
//   ├─ Branch 2: /publish    发布中心（中间 Tab）
//   ├─ Branch 3: /chat       消息中心
//   └─ Branch 4: /profile    个人中心
//
//   全屏路由（不含底部导航）：
//   /provider/:id      达人主页 (Hero 目标)
//   /payment/:id       模拟支付
//   /order/:id         订单详情 + QR
//   /review/:id        服务评价
//   /scanner           扫码核销
//   /fulfillment/:id   履约流程（含安全守护中心）
//   /onboarding        成为达人入驻
//   /ai-lab            AI 实验室（从发布中心进入）
// ══════════════════════════════════════════════════════════════

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      // 仅当 Supabase 已配置且未登录时，访问需认证页面则跳转登录
      // Demo 模式（占位 Supabase）不强制登录
      return null;
    },
    errorBuilder: (context, state) => _ErrorPage(error: '${state.error}'),

    routes: [
      // ── 带底部导航的 Tab 壳层（StatefulShellRoute 保持状态）──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShell(navigationShell: navigationShell),
        branches: [
          // Branch 0: 首页
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                name: 'home',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: HomeScreen(),
                ),
              ),
            ],
          ),

          // Branch 1: 发现（划一划）
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/discover',
                name: 'discover',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: DiscoverScreen(),
                ),
              ),
            ],
          ),

          // Branch 2: 发布中心（中间 Tab）
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/publish',
                name: 'publish',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: PublishCenterScreen(),
                ),
              ),
            ],
          ),

          // Branch 3: 消息
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chat',
                name: 'chat',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: ChatListScreen(),
                ),
              ),
            ],
          ),

          // Branch 4: 我的
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: 'profile',
                pageBuilder: (_, __) => const NoTransitionPage(
                  child: ProfileScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // ── 认证（全屏，无底部导航）──
      GoRoute(
        path: '/login',
        name: 'login',
        pageBuilder: (_, __) => const NoTransitionPage(
          child: LoginScreen(),
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        pageBuilder: (_, __) => CustomTransitionPage(
          child: const SignUpScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              _slideRightTransition(animation, child),
        ),
      ),

      // ── 全屏路由 ──

      // 聊天详情（需传入对方信息）
      GoRoute(
        path: '/chat/:otherId',
        name: 'chatDetail',
        pageBuilder: (context, state) {
          final otherId = state.pathParameters['otherId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CustomTransitionPage(
            child: ChatScreen(
              currentUserId: extra['currentUserId'] as String? ?? 'current_user',
              otherUserId: otherId,
              otherUserName: extra['otherUserName'] as String? ?? '用户',
              otherUserAvatar: extra['otherUserAvatar'] as String?,
              isProvider: extra['isProvider'] as bool? ?? false,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                _slideRightTransition(animation, child),
          );
        },
      ),

      // 达人主页（Hero 动画目标）
      GoRoute(
        path: '/provider/:id',
        name: 'providerProfile',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final provider = extra.isNotEmpty
              ? ProviderSummary.fromExtra(extra)
              : _mockProvider(state.pathParameters['id']!);
          return CustomTransitionPage(
            child: ProviderProfileScreen(provider: provider),
            transitionsBuilder: (_, animation, __, child) =>
                _slideUpTransition(animation, child),
          );
        },
      ),

      // 成为达人入驻
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const BecomeProviderScreen(userId: 'current_user'),
          transitionsBuilder: (_, animation, __, child) =>
              _slideUpTransition(animation, child),
        ),
      ),

      // 模拟支付（浮层风格）
      GoRoute(
        path: '/payment/:bookingId',
        name: 'payment',
        pageBuilder: (context, state) {
          final bookingId = state.pathParameters['bookingId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CustomTransitionPage(
            opaque: false,
            barrierDismissible: true,
            barrierColor: Colors.black54,
            child: PaymentMockScreen(
              bookingId:    bookingId,
              amount:       (extra['amount'] as num?)?.toDouble() ?? 0,
              serviceName:  extra['serviceName'] as String? ?? '服务',
              providerName: extra['providerName'] as String? ?? '达人',
              slotId:       extra['slotId'] as String?,
              postId:       extra['postId'] as String?,
              providerId:   extra['providerId'] as String?,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                _slideUpTransition(animation, child),
          );
        },
      ),

      // 订单详情 + QR 核销码
      GoRoute(
        path: '/order/:bookingId',
        name: 'orderDetail',
        pageBuilder: (context, state) {
          final bookingId = state.pathParameters['bookingId']!;
          return CustomTransitionPage(
            child: OrderDetailScreen(bookingId: bookingId),
            transitionsBuilder: (_, animation, __, child) =>
                _slideRightTransition(animation, child),
          );
        },
      ),

      // 服务评价页
      GoRoute(
        path: '/review/:bookingId',
        name: 'review',
        pageBuilder: (context, state) {
          final bookingId = state.pathParameters['bookingId']!;
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CustomTransitionPage(
            child: ReviewScreen(
              bookingId:     bookingId,
              providerName:  extra['providerName'] as String? ?? '达人',
              providerAvatar: extra['providerAvatar'] as String? ?? '',
              serviceName:   extra['serviceName'] as String? ?? '服务',
              amount:        (extra['amount'] as num?)?.toDouble() ?? 0,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                _slideUpTransition(animation, child),
          );
        },
      ),

      // 扫码核销（卖家端）
      GoRoute(
        path: '/scanner',
        name: 'scanner',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ScannerScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
        ),
      ),

      // 搜索结果页（从搜索框提交后进入）
      GoRoute(
        path: '/search',
        name: 'search',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final keyword = extra['q'] as String? ?? '';
          return CustomTransitionPage(
            child: SearchResultsScreen(initialKeyword: keyword),
            transitionsBuilder: (_, animation, __, child) =>
                _slideRightTransition(animation, child),
          );
        },
      ),

      // 内容详情页（从首页瀑布流进入）
      GoRoute(
        path: '/post/:postId',
        name: 'postDetail',
        pageBuilder: (context, state) {
          final extra = state.extra;
          // extra 传递完整 Post 对象，避免重复请求
          final post = extra is Post
              ? extra
              : _mockPost(state.pathParameters['postId']!);
          return CustomTransitionPage(
            child: PostDetailScreen(post: post),
            transitionsBuilder: (_, animation, __, child) =>
                _slideUpTransition(animation, child),
          );
        },
      ),

      // 我的订单列表
      GoRoute(
        path: '/orders',
        name: 'myOrders',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const MyOrdersScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              _slideRightTransition(animation, child),
        ),
      ),

      // 我的喜欢列表
      GoRoute(
        path: '/likes',
        name: 'myLikes',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const MyLikesScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              _slideRightTransition(animation, child),
        ),
      ),

      // 数据看板（达人专属，从发布中心进入）
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ProviderDashboardScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              _slideRightTransition(animation, child),
        ),
      ),

      // 收到的评价（达人专属，从发布中心进入）
      GoRoute(
        path: '/provider-reviews',
        name: 'providerReviews',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const ProviderReviewsScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              _slideRightTransition(animation, child),
        ),
      ),

      // AI 实验室（从发布中心入口进入，全屏）
      GoRoute(
        path: '/ai-lab',
        name: 'aiLab',
        pageBuilder: (context, state) => CustomTransitionPage(
          child: const AILabScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              _slideUpTransition(animation, child),
        ),
      ),

      // 服务履约进度
      GoRoute(
        path: '/fulfillment/:bookingId',
        name: 'fulfillment',
        pageBuilder: (context, state) {
          final bookingId = state.pathParameters['bookingId']!;
          final isProvider =
              state.uri.queryParameters['role'] == 'provider';
          return CustomTransitionPage(
            child: FulfillmentScreen(
              bookingId:  bookingId,
              isProvider: isProvider,
            ),
            transitionsBuilder: (_, animation, __, child) =>
                _slideUpTransition(animation, child),
          );
        },
      ),
    ],
  );
});

// ── 过渡动画工厂 ──

Widget _slideUpTransition(Animation<double> animation, Widget child) =>
    SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );

Widget _slideRightTransition(Animation<double> animation, Widget child) =>
    SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: child,
    );

// ── 降级 Mock Post（当 extra 丢失时兜底）──
Post _mockPost(String id) => Post(
      id: id,
      providerId: 'provider_mock',
      title: '精品达人服务',
      description: '专业团队，品质保证，欢迎咨询',
      category: 'cosplay',
      images: ['https://picsum.photos/seed/$id/400/560'],
      price: 150,
      priceUnit: '次',
      tags: ['专业', '精品'],
      location: '上海',
      createdAt: DateTime.now(),
    );

// ── 降级 Mock Provider（当 extra 丢失时兜底）──
ProviderSummary _mockProvider(String id) => ProviderSummary(
      id:       id,
      name:     '达人',
      tag:      'Coser',
      typeEmoji: '🎭',
      imageUrl: 'https://picsum.photos/seed/$id/400/600',
      rating:   4.8,
      reviews:  42,
      location: '未知',
      price:    120,
      tags:     const ['二次元', '古风', '写真'],
    );

// ── 错误页 ──
class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌀', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            const Text(
              '页面走丢了...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: Colors.white38, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
              ),
              child: const Text('回到首页'),
            ),
          ],
        ),
      ),
    );
  }
}
