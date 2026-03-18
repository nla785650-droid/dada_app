import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../providers/location_provider.dart';

// ══════════════════════════════════════════════════════════════
// SafetyControlPanel：线下履约安全控制面板
//
// 功能：
//   · 守护模式开关 + 状态显示
//   · 实时位置地图卡（Mock 地图 + 坐标）
//   · 对方位置指示（距离 + 方向）
//   · 地理围栏状态警告
//   · 行程分享按钮
//   · 隐私遮罩说明
//   · 一键紧急求助（110 / 紧急联系人）
// ══════════════════════════════════════════════════════════════

class SafetyControlPanel extends ConsumerStatefulWidget {
  const SafetyControlPanel({
    super.key,
    required this.bookingId,
    required this.isProvider,
    this.partnerName = '对方',
  });

  final String bookingId;
  final bool isProvider;
  final String partnerName;

  @override
  ConsumerState<SafetyControlPanel> createState() =>
      _SafetyControlPanelState();
}

class _SafetyControlPanelState extends ConsumerState<SafetyControlPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  bool _panicConfirmMode = false;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  SafetyNotifier get _notifier =>
      ref.read(safetyProvider(widget.bookingId).notifier);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(safetyProvider(widget.bookingId));

    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // ── 守护模式状态栏 ──
          _GuardianHeader(
            state: state,
            pulse: _pulse,
            onToggle: () => _toggleGuardian(state),
          ),

          const SizedBox(height: 12),

          // ── 地理围栏警告（有警告时显示）──
          if (state.hasAlert) _GeofenceAlert(state: state),

          // ── 地图区域 ──
          _MockMapCard(
            myLocation:      state.myLocation,
            partnerLocation: state.partnerLocation,
            partnerName:     widget.partnerName,
            myPath:          state.myPath,
          ),

          const SizedBox(height: 12),

          // ── 位置信息行 ──
          _LocationInfoRow(state: state, partnerName: widget.partnerName),

          const SizedBox(height: 12),

          // ── 操作按钮网格 ──
          _ActionGrid(
            state:      state,
            bookingId:  widget.bookingId,
            isProvider: widget.isProvider,
            onShare:    () => _shareTrip(state),
          ),

          const SizedBox(height: 16),

          // ── 隐私遮罩说明 ──
          _PrivacyMaskBanner(),

          const SizedBox(height: 16),

          // ── 紧急求助区域 ──
          _PanicSection(
            bookingId:        widget.bookingId,
            isPanic:          state.isPanicTriggered,
            isCooldown:       state.panicCooldown,
            confirmMode:      _panicConfirmMode,
            onEnterConfirm:   () => setState(() => _panicConfirmMode = true),
            onCancelConfirm:  () => setState(() => _panicConfirmMode = false),
            onConfirmPanic:   () => _triggerPanic(state),
          ),
        ],
      ),
    );
  }

  void _toggleGuardian(SafetyState state) {
    HapticFeedback.mediumImpact();
    if (state.isGuardianActive) {
      _notifier.pauseGuardian();
    } else {
      _notifier.startGuardian(widget.bookingId);
    }
  }

  void _shareTrip(SafetyState state) {
    // url 可传递给 url_launcher 打开实际地图
    // ignore: unused_local_variable
    final url = state.tripShareUrl ??
        'https://maps.google.com/?q=${state.myLocation?.lat ?? 0},${state.myLocation?.lng ?? 0}';
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.share_rounded, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            const Expanded(child: Text('行程链接已复制：点击在地图中查看')),
          ],
        ),
        backgroundColor: AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        action: SnackBarAction(
          label: '查看',
          textColor: Colors.white,
          onPressed: () {/* url_launcher 打开 */},
        ),
      ),
    );
  }

  Future<void> _triggerPanic(SafetyState state) async {
    setState(() => _panicConfirmMode = false);
    HapticFeedback.heavyImpact();
    await _notifier.triggerPanic(widget.bookingId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.white),
            SizedBox(width: 8),
            Text('⚠️ 紧急求助已发送，请保持冷静'),
          ],
        ),
        backgroundColor: AppTheme.error,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// 子组件
// ══════════════════════════════════════════════════════════════

// ── 守护模式状态头 ──
class _GuardianHeader extends StatelessWidget {
  const _GuardianHeader({
    required this.state,
    required this.pulse,
    required this.onToggle,
  });

  final SafetyState state;
  final Animation<double> pulse;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isActive = state.isGuardianActive;

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isActive
                ? [const Color(0xFF0D2137), const Color(0xFF1A3A5C)]
                : [AppTheme.surfaceVariant, AppTheme.surfaceVariant],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive
                ? AppTheme.primary.withValues(alpha: 0.5)
                : AppTheme.divider,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // 脉冲图标
            AnimatedBuilder(
              animation: pulse,
              builder: (_, __) => Transform.scale(
                scale: isActive ? pulse.value : 1.0,
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : AppTheme.surfaceVariant,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isActive ? AppTheme.primary : AppTheme.divider,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: Icon(
                    isActive
                        ? Icons.shield_rounded
                        : Icons.shield_outlined,
                    color: isActive ? AppTheme.primary : AppTheme.onSurfaceVariant,
                    size: 24,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isActive ? '🛡️ 安全守护已开启' : '安全守护（已关闭）',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isActive ? Colors.white : AppTheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isActive
                        ? '位置实时共享中 · 点击暂停'
                        : '开启后双方位置实时可见，保障履约安全',
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppTheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // 开关
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 44, height: 26,
              decoration: BoxDecoration(
                color: isActive ? AppTheme.primary : AppTheme.divider,
                borderRadius: BorderRadius.circular(13),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                alignment: isActive
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  width: 20, height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 地理围栏警告 ──
class _GeofenceAlert extends StatelessWidget {
  const _GeofenceAlert({required this.state});
  final SafetyState state;

  @override
  Widget build(BuildContext context) {
    final isBreach = state.geofenceStatus == GeofenceStatus.breach;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isBreach
            ? AppTheme.error.withValues(alpha: 0.1)
            : AppTheme.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBreach
              ? AppTheme.error.withValues(alpha: 0.5)
              : AppTheme.warning.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isBreach ? Icons.warning_rounded : Icons.info_outline_rounded,
            color: isBreach ? AppTheme.error : AppTheme.warning,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              state.lastAlert ?? '位置异常',
              style: TextStyle(
                fontSize: 12,
                color: isBreach ? AppTheme.error : AppTheme.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${state.geofenceDistanceMeters.toStringAsFixed(0)}m',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: isBreach ? AppTheme.error : AppTheme.warning,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mock 地图卡 ──
class _MockMapCard extends StatelessWidget {
  const _MockMapCard({
    required this.myLocation,
    required this.partnerLocation,
    required this.partnerName,
    required this.myPath,
  });

  final LocationPoint? myLocation;
  final LocationPoint? partnerLocation;
  final String partnerName;
  final List<LocationPoint> myPath;

  @override
  Widget build(BuildContext context) {
    final hasLocation = myLocation != null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 200,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A1628), Color(0xFF0D2137)],
          ),
        ),
        child: Stack(
          children: [
            // 地图网格背景
            CustomPaint(
              painter: _MapGridPainter(),
              child: const SizedBox.expand(),
            ),

            // 路径轨迹
            if (myPath.length >= 2)
              CustomPaint(
                painter: _PathPainter(myPath),
                child: const SizedBox.expand(),
              ),

            // 我的位置指示
            if (hasLocation)
              Center(
                child: _LocationDot(
                  color: AppTheme.primary,
                  label: '我',
                  isPulsing: true,
                ),
              ),

            // 对方位置指示
            if (partnerLocation != null)
              Positioned(
                right: 70, top: 60,
                child: _LocationDot(
                  color: AppTheme.accent,
                  label: partnerName.substring(0, 1),
                  isPulsing: false,
                ),
              ),

            // 底部信息条
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            color: AppTheme.primary, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hasLocation
                                ? myLocation!.shortAddress
                                : '获取位置中...',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                        ),
                        if (hasLocation) ...[
                          Container(
                            width: 5, height: 5,
                            decoration: const BoxDecoration(
                              color: AppTheme.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '实时',
                            style: TextStyle(
                              color: AppTheme.success,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        // 全屏地图按钮
                        GestureDetector(
                          onTap: () {/* 打开真实地图 URL */},
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    size: 10, color: Colors.white),
                                SizedBox(width: 3),
                                Text('地图',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 10)),
                              ],
                            ),
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
    );
  }
}

// ── 位置点 ──
class _LocationDot extends StatefulWidget {
  const _LocationDot({
    required this.color,
    required this.label,
    required this.isPulsing,
  });

  final Color color;
  final String label;
  final bool isPulsing;

  @override
  State<_LocationDot> createState() => _LocationDotState();
}

class _LocationDotState extends State<_LocationDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.isPulsing) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isPulsing)
            Opacity(
              opacity: (1.0 - _ctrl.value).clamp(0, 1),
              child: Container(
                width: 40 + _ctrl.value * 24,
                height: 40 + _ctrl.value * 24,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 位置信息行 ──
class _LocationInfoRow extends StatelessWidget {
  const _LocationInfoRow({
    required this.state,
    required this.partnerName,
  });

  final SafetyState state;
  final String partnerName;

  @override
  Widget build(BuildContext context) {
    final myLoc = state.myLocation;
    final partnerLoc = state.partnerLocation;
    final dist = myLoc != null && partnerLoc != null
        ? myLoc.distanceTo(partnerLoc)
        : null;

    return Row(
      children: [
        Expanded(
          child: _LocationCard(
            icon: Icons.my_location_rounded,
            label: '我的位置',
            value: myLoc != null
                ? '${myLoc.lat.toStringAsFixed(4)}, ${myLoc.lng.toStringAsFixed(4)}'
                : '获取中...',
            color: AppTheme.primary,
            sub: myLoc?.accuracy != null
                ? '精度 ±${myLoc!.accuracy!.toStringAsFixed(0)}m'
                : null,
          ),
        ),
        const SizedBox(width: 10),
        // 距离指示
        Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                dist != null
                    ? '${dist > 1000 ? '${(dist / 1000).toStringAsFixed(1)}km' : '${dist.toStringAsFixed(0)}m'}'
                    : '--',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.swap_horiz_rounded,
                size: 16, color: AppTheme.onSurfaceVariant),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _LocationCard(
            icon: Icons.person_pin_circle_rounded,
            label: partnerName,
            value: partnerLoc != null
                ? '${partnerLoc.lat.toStringAsFixed(4)}, ${partnerLoc.lng.toStringAsFixed(4)}'
                : '等待共享...',
            color: AppTheme.accent,
            sub: partnerLoc?.updatedAt != null
                ? _relTime(partnerLoc!.updatedAt!)
                : null,
          ),
        ),
      ],
    );
  }

  String _relTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inSeconds < 10) return '刚刚';
    if (diff.inSeconds < 60) return '${diff.inSeconds}秒前';
    return '${diff.inMinutes}分钟前';
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.sub,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.onSurface,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          if (sub != null)
            Text(sub!,
                style: const TextStyle(
                    fontSize: 9, color: AppTheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ── 操作按钮网格 ──
class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.state,
    required this.bookingId,
    required this.isProvider,
    required this.onShare,
  });

  final SafetyState state;
  final String bookingId;
  final bool isProvider;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionTile(
            icon: Icons.share_location_rounded,
            label: '分享行程',
            color: AppTheme.primary,
            onTap: onShare,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.local_police_rounded,
            label: '联系平台',
            color: const Color(0xFF3498DB),
            onTap: () => HapticFeedback.mediumImpact(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionTile(
            icon: Icons.phone_in_talk_rounded,
            label: '联系对方',
            color: AppTheme.success,
            onTap: () => HapticFeedback.mediumImpact(),
          ),
        ),
        if (isProvider) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _ActionTile(
              icon: Icons.task_alt_rounded,
              label: '完成服务',
              color: AppTheme.warning,
              onTap: () => HapticFeedback.heavyImpact(),
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── 隐私遮罩说明 ──
class _PrivacyMaskBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: const Row(
        children: [
          Icon(Icons.privacy_tip_rounded,
              size: 16, color: AppTheme.onSurfaceVariant),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '🔒 隐私保护：本次履约中真实手机号和头像已自动遮罩，请通过应用内渠道沟通',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 紧急求助区域 ──
class _PanicSection extends StatelessWidget {
  const _PanicSection({
    required this.bookingId,
    required this.isPanic,
    required this.isCooldown,
    required this.confirmMode,
    required this.onEnterConfirm,
    required this.onCancelConfirm,
    required this.onConfirmPanic,
  });

  final String bookingId;
  final bool isPanic;
  final bool isCooldown;
  final bool confirmMode;
  final VoidCallback onEnterConfirm;
  final VoidCallback onCancelConfirm;
  final VoidCallback onConfirmPanic;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 110 一键报警按钮
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: confirmMode
              ? _PanicConfirmRow(
                  onConfirm: onConfirmPanic,
                  onCancel:  onCancelConfirm,
                )
              : _PanicMainButton(
                  isPanic:   isPanic,
                  isCooldown: isCooldown,
                  onTap:     onEnterConfirm,
                ),
        ),

        const SizedBox(height: 10),

        // 紧急联系人（横排）
        _EmergencyContactsRow(),
      ],
    );
  }
}

class _PanicMainButton extends StatelessWidget {
  const _PanicMainButton({
    required this.isPanic,
    required this.isCooldown,
    required this.onTap,
  });

  final bool isPanic;
  final bool isCooldown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = !isCooldown;
    final color = isPanic ? const Color(0xFF7F0000) : AppTheme.error;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: enabled
                ? [color, color.withValues(alpha: 0.85)]
                : [Colors.grey.shade300, Colors.grey.shade300],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emergency_rounded,
              color: enabled ? Colors.white : Colors.grey,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              isCooldown
                  ? '已发送求助（60s 后可再次触发）'
                  : isPanic
                      ? '⚠️ 求助已发出'
                      : '一键紧急求助 / 110',
              style: TextStyle(
                color: enabled ? Colors.white : Colors.grey,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanicConfirmRow extends StatelessWidget {
  const _PanicConfirmRow({
    required this.onConfirm,
    required this.onCancel,
  });

  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            '⚠️ 确认发送紧急求助？',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.error,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '系统将向紧急联系人和平台发送你的当前位置',
            style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(child: Text('取消')),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.error,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Text(
                        '确认求助',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmergencyContactsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final mockContacts = [
      ('妈妈', '138****8888'),
      ('平台客服', '400-xxx-xxxx'),
    ];

    return Row(
      children: mockContacts.map((c) {
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(
                right: c == mockContacts.last ? 0 : 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.phone_rounded,
                      size: 16, color: AppTheme.primary),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.$1,
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(c.$2,
                          style: const TextStyle(
                              fontSize: 10, color: AppTheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// Custom Painters
// ══════════════════════════════════════════════════════════════

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E3A5F).withValues(alpha: 0.6)
      ..strokeWidth = 0.5;

    // 横向网格线
    for (double y = 0; y < size.height; y += size.height / 8) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // 纵向网格线
    for (double x = 0; x < size.width; x += size.width / 10) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // 几条随机"道路"线（装饰）
    final roadPaint = Paint()
      ..color = const Color(0xFF2A5F8F).withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
        Offset(0, size.height * 0.4),
        Offset(size.width, size.height * 0.55), roadPaint);
    canvas.drawLine(
        Offset(size.width * 0.3, 0),
        Offset(size.width * 0.4, size.height), roadPaint);
    canvas.drawLine(
        Offset(size.width * 0.6, 0),
        Offset(size.width * 0.55, size.height), roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PathPainter extends CustomPainter {
  _PathPainter(this.path);
  final List<LocationPoint> path;

  @override
  void paint(Canvas canvas, Size size) {
    if (path.length < 2) return;

    final paint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 将经纬度映射到画布（相对偏移）
    final refLat = path.first.lat;
    final refLng = path.first.lng;
    const scale = 5000.0;

    final flutterPath = Path();
    final first = path.first;
    flutterPath.moveTo(
      size.width / 2 + (first.lng - refLng) * scale,
      size.height / 2 - (first.lat - refLat) * scale,
    );

    for (var i = 1; i < path.length; i++) {
      final p = path[i];
      flutterPath.lineTo(
        size.width / 2 + (p.lng - refLng) * scale,
        size.height / 2 - (p.lat - refLat) * scale,
      );
    }

    canvas.drawPath(flutterPath, paint);
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.path != path;
}
