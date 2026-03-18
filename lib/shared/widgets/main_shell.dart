import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// MainShell：底部导航壳层
//
// 使用 StatefulNavigationShell（StatefulShellRoute.indexedStack）
// 保证切换 Tab 时页面状态不丢失（如滚动位置、加载的数据等）
// ══════════════════════════════════════════════════════════════

class MainShell extends StatelessWidget {
  const MainShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _tabs = [
    _TabItem(icon: Icons.grid_view_rounded, activeIcon: Icons.grid_view_rounded, label: '首页', path: '/home'),
    _TabItem(icon: Icons.favorite_border_rounded, activeIcon: Icons.favorite_rounded, label: '匹配', path: '/discover'),
    _TabItem(icon: Icons.add_rounded, activeIcon: Icons.add_rounded, label: '发布', path: '/publish'),
    _TabItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: '消息', path: '/chat'),
    _TabItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: '我的', path: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: _GlassNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (i) => navigationShell.goBranch(
          i,
          // 再次点击当前 Tab 时回到该 Tab 的根路由
          initialLocation: i == navigationShell.currentIndex,
        ),
        tabs: _tabs,
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_TabItem> tabs;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.glassBg,
            border: Border(
              top: BorderSide(color: AppTheme.divider, width: 0.5),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 58,
              child: Row(
                children: List.generate(tabs.length, (i) {
                  final isSelected = i == currentIndex;
                  // 发布中心 Tab（中间）特殊样式：大号 + 渐变圆形按钮
                  if (i == 2) {
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onTap(i),
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppTheme.primary,
                                  Color(0xFF818CF8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(
                                      alpha: isSelected ? 0.5 : 0.25),
                                  blurRadius: isSelected ? 16 : 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              tabs[i].icon,
                              size: 26,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedScale(
                            scale: isSelected ? 1.18 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              isSelected ? tabs[i].activeIcon : tabs[i].icon,
                              size: 24,
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: isSelected
                                  ? AppTheme.primary
                                  : AppTheme.onSurfaceVariant,
                            ),
                            child: Text(tabs[i].label),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
