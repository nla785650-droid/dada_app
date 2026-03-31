import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../providers/meet_safety_session_provider.dart';
import 'safety_center_sheet.dart';

/// 全局安全入口（登录 / 注册 / 实人认证流程中隐藏）
///
/// 注意：本组件挂在 MaterialApp.router 的 builder 中，与 Navigator 并列，不在 [InheritedGoRouter]
/// 子树内，因此禁止使用 [GoRouterState.of] / [GoRouter.maybeOf] 依赖 context 取路由。
class GlobalSafetyFabLayer extends ConsumerStatefulWidget {
  const GlobalSafetyFabLayer({super.key});

  @override
  ConsumerState<GlobalSafetyFabLayer> createState() =>
      _GlobalSafetyFabLayerState();
}

class _GlobalSafetyFabLayerState extends ConsumerState<GlobalSafetyFabLayer> {
  late final GoRouter _router;
  late final VoidCallback _onRouteChanged;

  static const _hidePaths = {
    '/login',
    '/signup',
    '/verify',
    '/profile/edit',
  };

  @override
  void initState() {
    super.initState();
    _router = ref.read(routerProvider);
    _onRouteChanged = () {
      if (mounted) setState(() {});
    };
    _router.routerDelegate.addListener(_onRouteChanged);
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = _router.state.uri.path;
    if (_hidePaths.contains(path)) {
      return const SizedBox.shrink();
    }
    if (ref.watch(meetSafetySessionProvider).active) {
      return const SizedBox.shrink();
    }

    final bottom = MediaQuery.paddingOf(context).bottom + 88;

    return Positioned(
      right: 16,
      bottom: bottom,
      child: FloatingActionButton(
        backgroundColor: Colors.blue,
        elevation: 4,
        onPressed: () => showSafetyCenterSheet(context, ref),
        child: const Icon(Icons.security_rounded, color: Colors.white),
      ),
    );
  }
}
