import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../models/discover_filter_model.dart';

/// 匹配页筛选面板（Bottom Sheet）
/// 支持：陪拍/陪玩/委托、性别、身高、风格、星座、MBTI
class DiscoverFilterSheet extends StatefulWidget {
  const DiscoverFilterSheet({
    super.key,
    required this.initialState,
    required this.onApply,
  });

  final DiscoverFilterState initialState;
  final ValueChanged<DiscoverFilterState> onApply;

  static Future<void> show(
    BuildContext context, {
    required DiscoverFilterState initialState,
    required ValueChanged<DiscoverFilterState> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useRootNavigator: true,
      builder: (_) => DiscoverFilterSheet(
        initialState: initialState,
        onApply: onApply,
      ),
    );
  }

  @override
  State<DiscoverFilterSheet> createState() => _DiscoverFilterSheetState();
}

class _DiscoverFilterSheetState extends State<DiscoverFilterSheet> {
  late DiscoverFilterState _state;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  void _apply() {
    HapticFeedback.lightImpact();
    widget.onApply(_state);
    Navigator.of(context).pop();
  }

  void _reset() {
    HapticFeedback.lightImpact();
    setState(() => _state = const DiscoverFilterState());
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return Container(
      height: mq.size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: mq.padding.bottom + 80,
              ),
              physics: const BouncingScrollPhysics(),
              children: [
                _buildSection('服务类型', _buildServiceTypes()),
                _buildSection('性别', _buildGenders()),
                _buildSection('身高', _buildHeights()),
                _buildSection('风格', _buildStyles()),
                _buildSection('星座', _buildZodiacs()),
                _buildSection('MBTI', _buildMbti()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.divider,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 16),
      child: Row(
        children: [
          const Text(
            '筛选条件',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.onSurface,
            ),
          ),
          if (_state.hasAnyFilter) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${_state.activeCount}项',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
          const Spacer(),
          TextButton(
            onPressed: _reset,
            child: const Text('重置', style: TextStyle(color: AppTheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _apply,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ),
        child,
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildServiceTypes() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kFilterServiceTypes.map((item) {
        final (label, value, emoji) = item;
        final selected = _state.serviceTypes.contains(value);
        return _FilterChip(
          label: '$emoji $label',
          selected: selected,
          onTap: () {
            setState(() {
              final next = Set<String>.from(_state.serviceTypes);
              if (selected) {
                next.remove(value);
              } else {
                next.add(value);
              }
              _state = _state.copyWith(serviceTypes: next);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildGenders() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kFilterGenders.map((item) {
        final (label, value) = item;
        final selected = _state.gender == value;
        return _FilterChip(
          label: label,
          selected: selected,
          onTap: () {
            setState(() => _state = _state.copyWith(gender: value));
          },
        );
      }).toList(),
    );
  }

  Widget _buildHeights() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kFilterHeightRanges.map((item) {
        final (label, value) = item;
        final selected = _state.heightRange == value;
        return _FilterChip(
          label: label,
          selected: selected,
          onTap: () {
            setState(() => _state = _state.copyWith(heightRange: value));
          },
        );
      }).toList(),
    );
  }

  Widget _buildStyles() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kFilterStyles.map((label) {
        final selected = _state.styles.contains(label);
        return _FilterChip(
          label: label,
          selected: selected,
          onTap: () {
            setState(() {
              final next = Set<String>.from(_state.styles);
              if (selected) {
                next.remove(label);
              } else {
                next.add(label);
              }
              _state = _state.copyWith(styles: next);
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildZodiacs() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kFilterZodiacs.map((item) {
        final (label, value) = item;
        final selected = _state.zodiac == value;
        return _FilterChip(
          label: label,
          selected: selected,
          onTap: () {
            setState(() => _state = _state.copyWith(zodiac: value));
          },
        );
      }).toList(),
    );
  }

  Widget _buildMbti() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kFilterMbtiTypes.map((item) {
        final (label, value) = item;
        final selected = _state.mbti == value;
        return _FilterChip(
          label: label,
          selected: selected,
          onTap: () {
            setState(() => _state = _state.copyWith(mbti: value));
          },
        );
      }).toList(),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppTheme.primary : AppTheme.onSurface,
          ),
        ),
      ),
    );
  }
}
