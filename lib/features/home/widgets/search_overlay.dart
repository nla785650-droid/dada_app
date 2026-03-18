import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';

// ══════════════════════════════════════════════════════════════
// SearchOverlay — 全屏搜索蒙层（小红书风格）
//
// 交互：
//   · 点击搜索图标 → Hero 过渡进入，TextField 自动聚焦
//   · 热门搜索标签 → 点击填入关键词并立即搜索
//   · 最近搜索记录 → 点击重新搜索，长按删除单条
//   · 实时搜索建议 → 输入时动态过滤显示
//   · 点击结果卡片 → 执行搜索
//   · 取消按钮 / 系统返回 → 退出 overlay
// ══════════════════════════════════════════════════════════════

class SearchOverlay extends StatefulWidget {
  const SearchOverlay({super.key});

  /// 通过 Navigator 展示全屏搜索蒙层（带过渡动画）
  static Future<String?> show(BuildContext context) {
    return Navigator.of(context).push<String>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, __, ___) => const SearchOverlay(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay>
    with SingleTickerProviderStateMixin {
  final _controller    = TextEditingController();
  final _focusNode     = FocusNode();
  late AnimationController _slideCtrl;
  late Animation<Offset>   _slideAnim;

  String _query        = '';
  bool   _hasResults   = false;

  // 最近搜索（实际应从 SharedPreferences 读取）
  final List<String> _recents = [
    'COS委托',
    '汉服摄影 上海',
    '漫展陪玩',
    '原神角色',
  ];

  // 热门搜索
  static const _hotSearches = [
    ('🔥 COS委托',   1),
    ('📸 摄影陪拍',  2),
    ('🎮 王者陪玩',  3),
    ('🌸 汉服写真', 4),
    ('✨ 原神角色',  5),
    ('🎭 古风Cos',  6),
    ('🌙 暗黑系',   7),
    ('🎯 代练上分',  8),
  ];

  // 搜索建议（输入时动态过滤）
  static const _suggestions = [
    'COS委托 北京',
    'COS委托 上海',
    'COS委托 价格',
    '摄影陪拍 日系风',
    '摄影陪拍 古风',
    '游戏陪玩 一对一',
    '漫展陪伴 同城',
    '汉服摄影 写真',
  ];

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    // 自动聚焦
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());

    _controller.addListener(() {
      setState(() {
        _query      = _controller.text;
        _hasResults = _query.length >= 1;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  List<String> get _filteredSuggestions => _query.isEmpty
      ? []
      : _suggestions
          .where((s) => s.contains(_query))
          .take(6)
          .toList();

  void _search(String keyword) {
    if (keyword.trim().isEmpty) return;
    HapticFeedback.lightImpact();
    // 记录到最近搜索
    _recents.remove(keyword);
    _recents.insert(0, keyword);
    if (_recents.length > 8) _recents.removeLast();
    // 实际跳转搜索结果页（此处以 pop 返回关键词）
    Navigator.of(context).pop(keyword);
  }

  void _removeRecent(String keyword) {
    setState(() => _recents.remove(keyword));
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: AppTheme.surface.withValues(alpha: 0.92),
              child: GestureDetector(
                onTap: () {}, // 防止点击内容区关闭
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── 搜索栏 ──
                      _buildSearchBar(topPad),

                      // ── 内容区（建议 / 历史 / 热搜）──
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          child: _hasResults && _filteredSuggestions.isNotEmpty
                              ? _buildSuggestions()
                              : _buildDefaultContent(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar(double topPad) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          // 搜索框
          Expanded(
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(21),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search_rounded,
                      size: 18, color: AppTheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode:  _focusNode,
                      textInputAction: TextInputAction.search,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.onSurface,
                      ),
                      decoration: const InputDecoration(
                        hintText:    '搜索达人、服务、风格...',
                        hintStyle:   TextStyle(
                          color:    AppTheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                        border:      InputBorder.none,
                        isDense:     true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: _search,
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _focusNode.requestFocus();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(Icons.cancel_rounded,
                            size: 16, color: AppTheme.onSurfaceVariant),
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          // 取消按钮
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              '取消',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 实时搜索建议列表 ──
  Widget _buildSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _filteredSuggestions.map((s) {
        final idx    = s.toLowerCase().indexOf(_query.toLowerCase());
        final before = idx < 0 ? s : s.substring(0, idx);
        final match  = idx < 0 ? '' : s.substring(idx, idx + _query.length);
        final after  = idx < 0 ? '' : s.substring(idx + _query.length);

        return InkWell(
          onTap: () => _search(s),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 4),
            child: Row(
              children: [
                const Icon(Icons.search_rounded,
                    size: 16, color: AppTheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text:  before,
                          style: const TextStyle(
                            color: AppTheme.onSurface, fontSize: 14),
                        ),
                        TextSpan(
                          text:  match,
                          style: const TextStyle(
                            color:      AppTheme.primary,
                            fontSize:   14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text:  after,
                          style: const TextStyle(
                            color: AppTheme.onSurface, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const Icon(Icons.north_west_rounded,
                    size: 14, color: AppTheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── 默认内容（历史 + 热搜）──
  Widget _buildDefaultContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 最近搜索
        if (_recents.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionHeader(
            title: '最近搜索',
            action: '清空',
            onAction: () => setState(() => _recents.clear()),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recents.map((r) {
              return GestureDetector(
                onTap: () => _search(r),
                onLongPress: () => _removeRecent(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history_rounded,
                          size: 13, color: AppTheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        r,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        // 热门搜索
        _SectionHeader(title: '热门搜索'),
        const SizedBox(height: 10),
        // 两列网格布局
        ..._buildHotGrid(),
      ],
    );
  }

  List<Widget> _buildHotGrid() {
    final rows = <Widget>[];
    for (var i = 0; i < _hotSearches.length; i += 2) {
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: _HotItem(item: _hotSearches[i],  onTap: _search)),
              const SizedBox(width: 8),
              if (i + 1 < _hotSearches.length)
                Expanded(child: _HotItem(item: _hotSearches[i + 1], onTap: _search))
              else
                const Expanded(child: SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return rows;
  }
}

// ── 热搜条目 ──
class _HotItem extends StatelessWidget {
  const _HotItem({required this.item, required this.onTap});

  final (String, int) item;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final (label, rank) = item;
    final isTop3 = rank <= 3;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        // 去掉 emoji 前缀
        final keyword = label.replaceAll(RegExp(r'^[^\w\s]+\s*'), '');
        onTap(keyword.trim());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isTop3 ? AppTheme.error : AppTheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: AppTheme.onSurface),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isTop3)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B6B), Color(0xFFFF8E53)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'HOT',
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── section header ──
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}
