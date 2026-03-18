import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/provider_application_model.dart';

/// Step 1：达人类型选择页
class Step1TypeSelection extends StatelessWidget {
  const Step1TypeSelection({super.key, required this.onSelect});

  final void Function(ProviderType) onSelect;

  static const _types = [
    _TypeCard(
      type: ProviderType.cosCommission,
      title: 'Cos 委托',
      subtitle: '汉服·二次元·原创角色委托',
      emoji: '🎭',
      tags: ['角色扮演', '形象授权', '档期灵活'],
      gradientColors: [Color(0xFF9B59B6), Color(0xFFBB6BD9)],
    ),
    _TypeCard(
      type: ProviderType.photography,
      title: '摄影陪拍',
      subtitle: '日系·写真·棚拍·户外跟拍',
      emoji: '📸',
      tags: ['专业设备', '修图包含', '当天出图'],
      gradientColors: [Color(0xFF2980B9), Color(0xFF6DD5FA)],
    ),
    _TypeCard(
      type: ProviderType.companion,
      title: '社交陪玩',
      subtitle: '游戏·逛展·观影·漫展同行',
      emoji: '🎮',
      tags: ['线上线下', '弹性时间', '多种场景'],
      gradientColors: [Color(0xFF27AE60), Color(0xFF6FCF97)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 引导语
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.onSurface,
                height: 1.4,
              ),
              children: [
                TextSpan(text: '你想成为\n哪种类型的 '),
                TextSpan(
                  text: '达人',
                  style: TextStyle(color: AppTheme.primary),
                ),
                TextSpan(text: '？'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '根据你的特长选择服务类型，后续可扩展多类型',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          // 类型卡片列表
          ...List.generate(_types.length, (i) {
            final card = _types[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _TypeCardWidget(
                card: card,
                onTap: () => onSelect(card.type),
              ),
            );
          }),
          // 底部提示
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 16, color: AppTheme.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '申请通过后可在个人中心切换服务类型',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeCard {
  const _TypeCard({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.tags,
    required this.gradientColors,
  });

  final ProviderType type;
  final String title;
  final String subtitle;
  final String emoji;
  final List<String> tags;
  final List<Color> gradientColors;
}

class _TypeCardWidget extends StatefulWidget {
  const _TypeCardWidget({required this.card, required this.onTap});

  final _TypeCard card;
  final VoidCallback onTap;

  @override
  State<_TypeCardWidget> createState() => _TypeCardWidgetState();
}

class _TypeCardWidgetState extends State<_TypeCardWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _ctrl;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return GestureDetector(
      onTapDown: (_) => _ctrl.reverse(),
      onTapUp: (_) {
        _ctrl.forward();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.forward(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: card.gradientColors.first.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: card.gradientColors,
                ),
              ),
              child: Stack(
                children: [
                  // 背景装饰圆
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 20,
                    bottom: -20,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ),
                  // 内容
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Emoji
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              card.emoji,
                              style: const TextStyle(fontSize: 30),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                card.subtitle,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 6,
                                children: card.tags
                                    .map(
                                      (t) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.2),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          t,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
