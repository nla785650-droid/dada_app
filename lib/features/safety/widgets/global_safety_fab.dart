import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'safety_center_sheet.dart';

/// 全局安全入口（登录 / 注册 / 实人认证流程中隐藏）
class GlobalSafetyFabLayer extends ConsumerWidget {
  const GlobalSafetyFabLayer({super.key});

  static const _hidePaths = {
    '/login',
    '/signup',
    '/verify',
    '/profile/edit',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = GoRouterState.of(context).uri.path;
    if (_hidePaths.contains(path)) {
      return const SizedBox.shrink();
    }

    final bottom = MediaQuery.paddingOf(context).bottom + 88;

    /// 与底部主导航错开；不拦截底层点击区域外的空白。
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
