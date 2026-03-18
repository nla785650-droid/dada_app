import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/provider_summary.dart';
import 'service_timeline_calendar.dart';

// ══════════════════════════════════════════════════════════════
// BookingConfirmSheet：预约确认浮窗
//
// 显示：已选时间段、服务单价、总计金额
// 操作：确认 → PaymentMockScreen
// ══════════════════════════════════════════════════════════════

class BookingConfirmSheet extends StatefulWidget {
  const BookingConfirmSheet({
    super.key,
    required this.provider,
    required this.slot,
  });

  final ProviderSummary provider;
  final AvailabilitySlot slot;

  static Future<void> show({
    required BuildContext context,
    required ProviderSummary provider,
    required AvailabilitySlot slot,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingConfirmSheet(provider: provider, slot: slot),
    );
  }

  @override
  State<BookingConfirmSheet> createState() => _BookingConfirmSheetState();
}

class _BookingConfirmSheetState extends State<BookingConfirmSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _slide;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..forward();
    _slide = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  ProviderSummary get _p => widget.provider;
  AvailabilitySlot get _slot => widget.slot;

  double get _total => (_slot.price ?? _p.price.toDouble()) * _slot.durationHours;

  Future<void> _onConfirm() async {
    HapticFeedback.mediumImpact();
    setState(() => _loading = true);

    // 模拟创建预订（生产环境在后端执行 create_booking_with_lock RPC）
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    Navigator.of(context).pop(); // 关闭浮层

    // 跳转支付页，携带 slotId 供支付成功后调用 RPC
    context.push(
      '/payment/new-booking',
      extra: {
        'amount':       _total,
        'serviceName':  '${_p.typeEmoji} ${_p.tag} · ${_slot.timeRange}',
        'providerName': _p.name,
        'slotId':       _slot.id,
        'providerId':   _p.id,
        'postId':       'post_${_p.id}', // 生产环境传真实 postId
        'slotDate':     _slot.date.toIso8601String(),
        'startTime':    _slot.startTime,
        'endTime':      _slot.endTime,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);

    return AnimatedBuilder(
      animation: _slide,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _slide.value * 60),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          padding: EdgeInsets.fromLTRB(24, 8, 24, mq.padding.bottom + 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withOpacity(0.12),
                blurRadius: 32,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 把手
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // 标题
              Row(
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.accent]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(_p.typeEmoji,
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '确认预约 · ${_p.name}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.onSurface,
                          ),
                        ),
                        Text(
                          _p.tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // 时间信息卡
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  children: [
                    _InfoLine(
                      icon: Icons.calendar_today_rounded,
                      label: '服务日期',
                      value: _formatDate(_slot.date),
                    ),
                    const SizedBox(height: 10),
                    _InfoLine(
                      icon: Icons.access_time_rounded,
                      label: '服务时段',
                      value: _slot.timeRange,
                    ),
                    const SizedBox(height: 10),
                    _InfoLine(
                      icon: Icons.timelapse_rounded,
                      label: '服务时长',
                      value: '${_slot.durationHours.toStringAsFixed(0)} 小时',
                    ),
                    const SizedBox(height: 10),
                    _InfoLine(
                      icon: Icons.location_on_rounded,
                      label: '服务城市',
                      value: _p.location,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 费用明细
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.divider),
                ),
                child: Column(
                  children: [
                    _FeeLine(
                      label: '服务单价',
                      value: '¥${(_slot.price ?? _p.price).toStringAsFixed(0)} / 小时',
                    ),
                    const SizedBox(height: 8),
                    _FeeLine(
                      label: '服务时长',
                      value: '× ${_slot.durationHours.toStringAsFixed(0)} 小时',
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: AppTheme.divider),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('实付金额',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            )),
                        Text(
                          '¥${_total.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 11, color: AppTheme.success),
                        SizedBox(width: 4),
                        Text(
                          '资金由搭哒平台托管，服务完成后自动结算给达人',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppTheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 支付按钮
              SizedBox(
                width: double.infinity,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _loading
                      ? Container(
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 22, height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            ),
                          ),
                        )
                      : GestureDetector(
                          onTap: _onConfirm,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppTheme.primary, AppTheme.accent],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withOpacity(0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.flash_on_rounded,
                                    color: Colors.white, size: 20),
                                SizedBox(width: 6),
                                Text(
                                  '立即支付',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = ['一', '二', '三', '四', '五', '六', '日'];
    final weekday = weekdays[date.weekday - 1];
    return '${date.year}年${date.month}月${date.day}日（周$weekday）';
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 12, color: AppTheme.onSurfaceVariant)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600,
                color: AppTheme.onSurface)),
      ],
    );
  }
}

class _FeeLine extends StatelessWidget {
  const _FeeLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.onSurfaceVariant)),
        Text(value,
            style: const TextStyle(
                fontSize: 13, color: AppTheme.onSurface)),
      ],
    );
  }
}
