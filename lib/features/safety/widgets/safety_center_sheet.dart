import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../pureget_safety_copy.dart';
import '../providers/safety_location_provider.dart';
import '../providers/emergency_contacts_provider.dart';

/// 一键求助与安全工具（Bottom Sheet）
Future<void> showSafetyCenterSheet(BuildContext context, WidgetRef ref) async {
  await ref.read(safetyLocationProvider.notifier).refresh();
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _SafetyCenterSheetBody(),
  );
}

String _pageShareUrl(BuildContext context) {
  try {
    final base = Uri.base;
    if (base.hasAuthority && base.scheme.startsWith('http')) {
      return base.removeFragment().toString();
    }
  } catch (_) {}
  try {
    final uri = GoRouterState.of(context).uri;
    return 'https://dada.app${uri.path}${uri.hasQuery ? '?${uri.query}' : ''}';
  } catch (_) {
    return 'https://dada.app';
  }
}

Future<void> _copyToClipboard(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

Future<void> _dialNumber(String number) async {
  final uri = Uri(scheme: 'tel', path: number);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

/// 3 秒倒计时，可取消；结束后自动拨打 110。
Future<void> showPoliceCountdownThenDial110(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _PoliceCountdownDialog(),
  );
}

class _PoliceCountdownDialog extends StatefulWidget {
  const _PoliceCountdownDialog();

  @override
  State<_PoliceCountdownDialog> createState() => _PoliceCountdownDialogState();
}

class _PoliceCountdownDialogState extends State<_PoliceCountdownDialog> {
  int _remaining = 3;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining == 1) {
        _t?.cancel();
        Navigator.of(context).pop();
        unawaited(_dialNumber('110'));
        return;
      }
      setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('一键报警'),
      content: Text('将在 $_remaining 秒后自动拨打 110，期间可随时取消。'),
      actions: [
        TextButton(
          onPressed: () {
            _t?.cancel();
            Navigator.of(context).pop();
          },
          child: const Text('取消报警'),
        ),
      ],
    );
  }
}

void _showSafetyShareDialog(BuildContext context, WidgetRef ref) {
  final loc = ref.read(safetyLocationProvider);
  final lat = loc.latitude;
  final lng = loc.longitude;
  final latStr = lat != null ? lat.toStringAsFixed(6) : '—';
  final lngStr = lng != null ? lng.toStringAsFixed(6) : '—';
  final tIso = DateTime.now().toUtc().toIso8601String();
  final payload = 'dada://safety?lat=$latStr&lng=$lngStr&t=$tIso';
  final shortLink = (lat != null && lng != null)
      ? 'https://dada.app/s/${lat.toStringAsFixed(4)}_${lng.toStringAsFixed(4)}?t=$tIso'
      : 'https://dada.app/safety?t=$tIso';

  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('安全分享'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 200,
                gapless: false,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '短链接（演示，含当前坐标与时间）',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            SelectableText(
              shortLink,
              style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _copyToClipboard(context, shortLink),
          child: const Text('复制短链'),
        ),
        TextButton(
          onPressed: () => _copyToClipboard(context, payload),
          child: const Text('复制二维码内容'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('关闭'),
        ),
      ],
    ),
  );
}

class _SafetyCenterSheetBody extends ConsumerStatefulWidget {
  const _SafetyCenterSheetBody();

  @override
  ConsumerState<_SafetyCenterSheetBody> createState() =>
      _SafetyCenterSheetBodyState();
}

class _SafetyCenterSheetBodyState extends ConsumerState<_SafetyCenterSheetBody> {
  Timer? _liveLocTimer;

  @override
  void initState() {
    super.initState();
    _liveLocTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      ref.read(safetyLocationProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    _liveLocTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emergency = ref.watch(emergencyContactProvider);
    final loc = ref.watch(safetyLocationProvider);
    final h = DateTime.now().hour;
    final advice = PuregetSafetyCopy.advice(
      hour: h,
      hasLocation: loc.latitude != null,
    );

    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.health_and_safety_rounded,
                      color: Colors.blue.shade700, size: 26),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '安全中心',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () =>
                      ref.read(safetyLocationProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: '立即刷新定位',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 实时定位（面板打开期间定时刷新，经纬度随 provider 更新）
            _SectionCard(
              icon: Icons.my_location_rounded,
              title: '实时定位',
              child: loc.loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : loc.error != null
                      ? Text(loc.error!,
                          style: const TextStyle(color: AppTheme.error))
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '监控中 · 约每 5 秒自动刷新坐标',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              loc.addressLine ?? '—',
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (loc.latitude != null && loc.longitude != null)
                              Text(
                                '经纬度：${loc.latitude!.toStringAsFixed(6)}, ${loc.longitude!.toStringAsFixed(6)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: () {
                                    final buf = StringBuffer()
                                      ..write(loc.addressLine ?? '')
                                      ..write('\n')
                                      ..write(
                                        '${loc.latitude ?? ''}, ${loc.longitude ?? ''}',
                                      );
                                    _copyToClipboard(context, buf.toString());
                                  },
                                  icon:
                                      const Icon(Icons.copy_rounded, size: 18),
                                  label: const Text('复制地址'),
                                ),
                              ],
                            ),
                          ],
                        ),
            ),

            const SizedBox(height: 12),

            _EmergencyContactSettingCard(
              initialName: emergency.contactName ?? '',
              initialPhone: emergency.contactPhone ?? '',
              onSave: (name, phone) async {
                await ref
                    .read(emergencyContactProvider.notifier)
                    .save(name: name, phone: phone);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('紧急联系人已保存到本机'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),

            const SizedBox(height: 12),

            // 紧急联络
            _SectionCard(
              icon: Icons.call_rounded,
              title: '紧急联络',
              child: Column(
                children: [
                  if (emergency.contactPhone != null &&
                      emergency.contactPhone!.trim().isNotEmpty)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.contact_emergency_rounded,
                          color: Colors.orange.shade700),
                      title: Text(
                        '拨打 ${emergency.contactName ?? '紧急联系人'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(emergency.contactPhone!),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => _dialNumber(emergency.contactPhone!),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_police_outlined,
                        color: AppTheme.primary),
                    title: const Text('报警电话 110 · 一键报警'),
                    subtitle: const Text('3 秒倒计时，可取消'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showPoliceCountdownThenDial110(context),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.medical_services_outlined,
                        color: Colors.red.shade400),
                    title: const Text('急救 120'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _dialNumber('120'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            _SectionCard(
              icon: Icons.qr_code_2_rounded,
              title: '安全分享',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '生成含当前经纬度的二维码与可复制的短链接（演示用途）。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppTheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () =>
                        _showSafetyShareDialog(context, ref),
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('生成安全二维码 / 短链'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // PureGet 安全播报
            _SectionCard(
              icon: Icons.auto_awesome_rounded,
              title: '安全播报 · PureGet AI',
              child: Text(
                advice,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: AppTheme.onSurfaceVariant,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 行程分享
            _SectionCard(
              icon: Icons.link_rounded,
              title: '行程分享',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _pageShareUrl(context),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: () =>
                        _copyToClipboard(context, _pageShareUrl(context)),
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('复制当前页面链接'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyContactSettingCard extends StatefulWidget {
  const _EmergencyContactSettingCard({
    required this.initialName,
    required this.initialPhone,
    required this.onSave,
  });

  final String initialName;
  final String initialPhone;
  final Future<void> Function(String name, String phone) onSave;

  @override
  State<_EmergencyContactSettingCard> createState() =>
      _EmergencyContactSettingCardState();
}

class _EmergencyContactSettingCardState
    extends State<_EmergencyContactSettingCard> {
  late TextEditingController _name;
  late TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _phone = TextEditingController(text: widget.initialPhone);
  }

  @override
  void didUpdateWidget(covariant _EmergencyContactSettingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialName != widget.initialName) {
      _name.text = widget.initialName;
    }
    if (oldWidget.initialPhone != widget.initialPhone) {
      _phone.text = widget.initialPhone;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.person_pin_circle_outlined,
      title: '我的紧急联系人',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: '称呼',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: '手机号',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: () async {
              await widget.onSave(_name.text.trim(), _phone.text.trim());
            },
            child: const Text('保存到本机'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}