import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// 多样性指示胶囊（滑卡内容重复度高时提示）
class MatchDiversityIndicator extends StatelessWidget {
  const MatchDiversityIndicator({super.key, required this.score});

  final double score;

  @override
  Widget build(BuildContext context) {
    final isLow = score < 0.3;
    final color = isLow ? AppTheme.warning : AppTheme.success;
    final label = isLow ? '注入新鲜感' : '内容多样';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLow ? Icons.shuffle_rounded : Icons.auto_awesome_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
