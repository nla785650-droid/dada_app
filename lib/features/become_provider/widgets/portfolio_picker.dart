import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';

/// 通用作品集/照片选择器
/// - 支持多选图片
/// - 网格预览，可单独删除
/// - 虚线添加按钮（Apple 极简风）
class PortfolioPicker extends StatelessWidget {
  const PortfolioPicker({
    super.key,
    required this.label,
    required this.files,
    required this.onAdd,
    required this.onRemove,
    this.maxCount = 9,
    this.minCount = 1,
    this.hint,
    this.errorText,
  });

  final String label;
  final List<File> files;
  final void Function(List<File> newFiles) onAdd;
  final void Function(int index) onRemove;
  final int maxCount;
  final int minCount;
  final String? hint;
  final String? errorText;

  Future<void> _pickImages(BuildContext context) async {
    final remaining = maxCount - files.length;
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('最多上传 $maxCount 张'),
          backgroundColor: AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      limit: remaining,
      imageQuality: 85,
    );

    if (picked.isNotEmpty) {
      onAdd(picked.map((xf) => File(xf.path)).toList());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签行
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
            if (minCount > 0) ...[
              const SizedBox(width: 4),
              Text(
                '（至少$minCount张）',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
            const Spacer(),
            Text(
              '${files.length}/$maxCount',
              style: TextStyle(
                fontSize: 12,
                color: files.length >= minCount
                    ? AppTheme.success
                    : AppTheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 10),
        // 图片网格
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: files.length < maxCount ? files.length + 1 : files.length,
          itemBuilder: (context, index) {
            if (index == files.length && files.length < maxCount) {
              return _AddButton(onTap: () => _pickImages(context));
            }
            return _PhotoTile(
              file: files[index],
              onRemove: () => onRemove(index),
            );
          },
        ),
        // 错误提示
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 13, color: AppTheme.error),
              const SizedBox(width: 4),
              Text(
                errorText!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DottedBorder(
        color: AppTheme.primary.withValues(alpha: 0.4),
        strokeWidth: 1.5,
        dashPattern: const [6, 4],
        borderType: BorderType.RRect,
        radius: const Radius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Container(
            color: AppTheme.primary.withValues(alpha: 0.04),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_photo_alternate_rounded,
                  size: 28,
                  color: AppTheme.primary,
                ),
                SizedBox(height: 4),
                Text(
                  '添加',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.file, required this.onRemove});

  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, fit: BoxFit.cover),
        ),
        // 删除按钮
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 22,
              height: 22,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────
// 标签选择器
// ──────────────────────────────────────────

class TagSelector extends StatelessWidget {
  const TagSelector({
    super.key,
    required this.label,
    required this.allTags,
    required this.selectedTags,
    required this.onToggle,
    this.errorText,
  });

  final String label;
  final List<String> allTags;
  final List<String> selectedTags;
  final void Function(String tag) onToggle;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allTags.map((tag) {
            final selected = selectedTags.contains(tag);
            return GestureDetector(
              onTap: () => onToggle(tag),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.primary
                      : AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? AppTheme.primary
                        : AppTheme.divider,
                    width: 1,
                  ),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400,
                    color:
                        selected ? Colors.white : AppTheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: const TextStyle(fontSize: 12, color: AppTheme.error),
          ),
        ],
      ],
    );
  }
}
