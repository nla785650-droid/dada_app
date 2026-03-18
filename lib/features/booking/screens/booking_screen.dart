import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final _format = CalendarFormat.month;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('我的预约'),
        actions: [
          // 达人端：扫码核销入口
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: '扫码核销',
            onPressed: () => context.push('/scanner'),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCalendar(),
          const Divider(height: 1, color: AppTheme.divider),
          Expanded(child: _buildBookingList()),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.now().subtract(const Duration(days: 30)),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _focusedDay,
        calendarFormat: _format,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
        },
        calendarStyle: CalendarStyle(
          selectedDecoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.accent],
            ),
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w700,
          ),
          weekendTextStyle: const TextStyle(color: AppTheme.accent),
          outsideDaysVisible: false,
        ),
        headerStyle: const HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left_rounded,
            color: AppTheme.primary,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right_rounded,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildBookingList() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '近期订单',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        _BookingCard(
          bookingId: 'mock-booking-001',
          title: '🎭 精品Coser | 汉服古风',
          providerName: '小樱',
          date: '2026.03.20',
          time: '14:00 - 17:00',
          amount: 350,
          status: 'paid',
        ),
        _BookingCard(
          bookingId: 'mock-booking-002',
          title: '📸 摄影陪拍 | 日系写真',
          providerName: '星野',
          date: '2026.03.22',
          time: '10:00 - 12:00',
          amount: 180,
          status: 'pending',
        ),
        _BookingCard(
          bookingId: 'mock-booking-003',
          title: '🎮 王者荣耀陪玩',
          providerName: '凉宫',
          date: '2026.03.15',
          time: '20:00 - 22:00',
          amount: 120,
          status: 'completed',
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.bookingId,
    required this.title,
    required this.providerName,
    required this.date,
    required this.time,
    required this.amount,
    required this.status,
  });

  final String bookingId;
  final String title;
  final String providerName;
  final String date;
  final String time;
  final double amount;
  final String status;

  Color get _statusColor {
    return switch (status) {
      'confirmed' => AppTheme.success,
      'pending' => AppTheme.warning,
      'completed' => AppTheme.onSurfaceVariant,
      'cancelled' => AppTheme.error,
      _ => AppTheme.onSurfaceVariant,
    };
  }

  String get _statusLabel {
    return switch (status) {
      'confirmed' => '已确认',
      'pending' => '待确认',
      'completed' => '已完成',
      'cancelled' => '已取消',
      _ => status,
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/order/$bookingId'),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded,
                  size: 14, color: AppTheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                providerName,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.calendar_today_rounded,
                  size: 14, color: AppTheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                '$date  $time',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: AppTheme.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '¥${amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.accent,
                ),
              ),
              if (status == 'pending')
                ElevatedButton(
                  onPressed: () => context.push(
                    '/payment/$bookingId',
                    extra: {
                      'amount': amount,
                      'serviceName': title,
                      'providerName': providerName,
                    },
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('立即支付', style: TextStyle(fontSize: 13)),
                ),
              if (status == 'paid')
                ElevatedButton.icon(
                  onPressed: () => context.push('/order/$bookingId'),
                  icon: const Icon(Icons.qr_code_rounded, size: 14),
                  label: const Text('出示码', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
