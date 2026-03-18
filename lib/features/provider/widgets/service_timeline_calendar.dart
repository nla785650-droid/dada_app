import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/provider_summary.dart';

// ══════════════════════════════════════════════════════════════
// ServiceTimelineCalendar：达人档期时间轴
//
// 视觉风格：Geek Chic 细线半透明色块
// 状态：
//   · available  绿色  可选择
//   · booked     红色  已约满（不可点）
//   · blocked    灰色  休息/不接单（不可点）
//   · selected   主色  用户选中
//
// 数据源：mock 数据 + Supabase availability_slots 表
// ══════════════════════════════════════════════════════════════

enum SlotStatus { available, booked, blocked, selected }

class AvailabilitySlot {
  const AvailabilitySlot({
    required this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.price,
  });

  final String id;
  final DateTime date;
  final String startTime; // "09:00"
  final String endTime;   // "11:00"
  final SlotStatus status;
  final double? price;

  double get durationHours {
    final startParts = startTime.split(':');
    final endParts = endTime.split(':');
    final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    return (endMinutes - startMinutes) / 60.0;
  }

  String get timeRange => '$startTime - $endTime';

  AvailabilitySlot copyWith({SlotStatus? status}) => AvailabilitySlot(
        id: id,
        date: date,
        startTime: startTime,
        endTime: endTime,
        status: status ?? this.status,
        price: price,
      );
}

// ── 数据生成器（连接 Supabase 后替换为真实 API 调用）──
List<AvailabilitySlot> generateMockSlots(
    String providerId, DateTime weekStart, double basePrice) {
  final slots = <AvailabilitySlot>[];
  final times = [
    ('09:00', '11:00'),
    ('11:00', '13:00'),
    ('14:00', '16:00'),
    ('16:00', '18:00'),
    ('19:00', '21:00'),
    ('21:00', '23:00'),
  ];

  for (var day = 0; day < 7; day++) {
    final date = weekStart.add(Duration(days: day));
    for (var t = 0; t < times.length; t++) {
      // 模拟不同状态
      SlotStatus status;
      final rand = (day * 7 + t + providerId.hashCode) % 10;
      if (rand < 5) {
        status = SlotStatus.available;
      } else if (rand < 7) {
        status = SlotStatus.booked;
      } else {
        status = SlotStatus.blocked;
      }
      // 周末下午强制为可选（演示目的）
      if (day >= 5 && t >= 2 && t <= 4) status = SlotStatus.available;

      slots.add(AvailabilitySlot(
        id: 'slot_${providerId}_${day}_$t',
        date: date,
        startTime: times[t].$1,
        endTime: times[t].$2,
        status: status,
        price: basePrice,
      ));
    }
  }
  return slots;
}

// ══════════════════════════════════════════════════════════════
// Widget
// ══════════════════════════════════════════════════════════════

class ServiceTimelineCalendar extends StatefulWidget {
  const ServiceTimelineCalendar({
    super.key,
    required this.provider,
    required this.onSlotSelected,
  });

  final ProviderSummary provider;
  final ValueChanged<AvailabilitySlot?> onSlotSelected;

  @override
  State<ServiceTimelineCalendar> createState() =>
      _ServiceTimelineCalendarState();
}

class _ServiceTimelineCalendarState extends State<ServiceTimelineCalendar> {
  late DateTime _weekStart;
  late List<AvailabilitySlot> _slots;
  AvailabilitySlot? _selected;

  @override
  void initState() {
    super.initState();
    // 本周从今天开始
    _weekStart = _startOfWeek(DateTime.now());
    _loadSlots();
  }

  DateTime _startOfWeek(DateTime date) {
    // 以今天为起点（不强制从周一）
    return DateTime(date.year, date.month, date.day);
  }

  void _loadSlots() {
    _slots = generateMockSlots(
      widget.provider.id,
      _weekStart,
      widget.provider.price.toDouble(),
    );
  }

  void _prevWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _selected = null;
      _loadSlots();
    });
    widget.onSlotSelected(null);
  }

  void _nextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _selected = null;
      _loadSlots();
    });
    widget.onSlotSelected(null);
  }

  void _selectSlot(AvailabilitySlot slot) {
    if (slot.status != SlotStatus.available && slot != _selected) return;

    HapticFeedback.selectionClick();

    setState(() {
      if (_selected?.id == slot.id) {
        // 取消选中
        _selected = null;
        _slots = _slots.map((s) =>
            s.id == slot.id ? s.copyWith(status: SlotStatus.available) : s
        ).toList();
        widget.onSlotSelected(null);
      } else {
        // 恢复上个选中
        if (_selected != null) {
          _slots = _slots.map((s) =>
              s.id == _selected!.id ? s.copyWith(status: SlotStatus.available) : s
          ).toList();
        }
        // 选中新时段
        _selected = slot.copyWith(status: SlotStatus.selected);
        _slots = _slots.map((s) =>
            s.id == slot.id ? _selected! : s
        ).toList();
        widget.onSlotSelected(_selected);
      }
    });
  }

  List<AvailabilitySlot> _slotsForDay(DateTime day) {
    return _slots.where((s) =>
        s.date.year == day.year &&
        s.date.month == day.month &&
        s.date.day == day.day
    ).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWeekHeader(),
        const SizedBox(height: 12),
        _buildLegend(),
        const SizedBox(height: 12),
        _buildScrollableGrid(),
      ],
    );
  }

  // ── 周导航 ──
  Widget _buildWeekHeader() {
    final now = DateTime.now();
    final isCurrentWeek = _weekStart.day == _startOfWeek(now).day;

    return Row(
      children: [
        GestureDetector(
          onTap: _prevWeek,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chevron_left_rounded, size: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCurrentWeek ? '本周' : _formatWeekRange(_weekStart),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface,
                ),
              ),
              Text(
                '点击绿色时段立即选择',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: _nextWeek,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.chevron_right_rounded, size: 20),
          ),
        ),
      ],
    );
  }

  // ── 图例 ──
  Widget _buildLegend() {
    return Row(
      children: [
        _LegendDot(color: _slotColor(SlotStatus.available), label: '可约'),
        const SizedBox(width: 12),
        _LegendDot(color: _slotColor(SlotStatus.booked), label: '已满'),
        const SizedBox(width: 12),
        _LegendDot(color: _slotColor(SlotStatus.blocked), label: '休息'),
        const SizedBox(width: 12),
        _LegendDot(color: _slotColor(SlotStatus.selected), label: '已选'),
      ],
    );
  }

  // ── 可横向滚动的日历网格 ──
  Widget _buildScrollableGrid() {
    return SizedBox(
      height: 340,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(7, (dayIndex) {
            final day = _weekStart.add(Duration(days: dayIndex));
            final daySlots = _slotsForDay(day);
            final isToday = _isSameDay(day, DateTime.now());

            return Container(
              width: 88,
              margin: const EdgeInsets.only(right: 6),
              child: Column(
                children: [
                  // 日期头
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isToday
                          ? AppTheme.primary
                          : AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _weekdayLabel(day.weekday),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isToday ? Colors.white : AppTheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${day.month}/${day.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isToday ? Colors.white : AppTheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 时段列表
                  ...daySlots.map((slot) => _SlotChip(
                        slot: slot,
                        onTap: () => _selectSlot(slot),
                      )),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  String _formatWeekRange(DateTime start) {
    final end = start.add(const Duration(days: 6));
    return '${start.month}/${start.day} - ${end.month}/${end.day}';
  }

  String _weekdayLabel(int weekday) {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return '周${labels[weekday - 1]}';
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ── 时段色彩 ──
Color _slotColor(SlotStatus status) => switch (status) {
  SlotStatus.available => const Color(0xFF10B981),
  SlotStatus.booked    => const Color(0xFFEF4444),
  SlotStatus.blocked   => const Color(0xFF9CA3AF),
  SlotStatus.selected  => AppTheme.primary,
};

// ── 时段色块 ──
class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot, required this.onTap});
  final AvailabilitySlot slot;
  final VoidCallback onTap;

  bool get _interactive => slot.status == SlotStatus.available ||
                            slot.status == SlotStatus.selected;

  @override
  Widget build(BuildContext context) {
    final color = _slotColor(slot.status);
    final isSelected = slot.status == SlotStatus.selected;

    return GestureDetector(
      onTap: _interactive ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(isSelected ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withOpacity(isSelected ? 1.0 : 0.4),
            width: isSelected ? 1.5 : 0.8,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.25), blurRadius: 6)]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              slot.startTime,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              slot.endTime,
              style: TextStyle(
                fontSize: 9,
                color: color.withOpacity(0.7),
              ),
            ),
            if (slot.status == SlotStatus.available || isSelected)
              Text(
                '¥${slot.price?.toStringAsFixed(0) ?? "?"}',
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant)),
      ],
    );
  }
}
