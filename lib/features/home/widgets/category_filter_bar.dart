import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';

class CategoryFilterBar extends StatefulWidget {
  const CategoryFilterBar({super.key, required this.onCategoryChanged});

  final ValueChanged<String> onCategoryChanged;

  @override
  State<CategoryFilterBar> createState() => _CategoryFilterBarState();
}

class _CategoryFilterBarState extends State<CategoryFilterBar> {
  String _selected = 'all';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: AppConstants.categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = AppConstants.categories[index];
          final isSelected = _selected == cat.id;
          return GestureDetector(
            onTap: () {
              setState(() => _selected = cat.id);
              widget.onCategoryChanged(cat.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cat.emoji,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: isSelected
                          ? Colors.white
                          : AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
