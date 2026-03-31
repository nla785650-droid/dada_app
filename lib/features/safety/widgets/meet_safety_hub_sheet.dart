import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/meet_safety_session_provider.dart';
import '../providers/safety_location_provider.dart';

/// 高侵入安全工具：行程共享、模拟来电 / 警示音、结束守护
Future<void> showMeetSafetyHubSheet(BuildContext context, WidgetRef ref) async {
  ref.read(meetSafetySessionProvider.notifier).clearArrivalNudge();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => _MeetSafetyHubBody(parentRef: ref),
  );
}

class _MeetSafetyHubBody extends StatelessWidget {
  const _MeetSafetyHubBody({required this.parentRef});

  final WidgetRef parentRef;

  @override
  Widget build(BuildContext context) {
    final session = parentRef.watch(meetSafetySessionProvider);
    final bottom = MediaQuery.paddingOf(context).bottom;
    parentRef.read(safetyLocationProvider.notifier).refresh();

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.red.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.red.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.shield_moon_rounded,
                    color: Colors.red.shade800, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'PureGet 安全中心 · ${session.counterpartyName}',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '对方档案：${session.counterpartyPureGetRef} · 行程已纳入审计',
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade900.withValues(alpha: 0.75),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            _DangerTile(
              icon: Icons.share_location_rounded,
              title: '行程共享',
              subtitle: '将实时位置与对方 PureGet 信用摘要同步给紧急联系人 / 微信好友（演示）',
              onTap: () => _shareRoute(context, parentRef, session),
            ),
            const SizedBox(height: 10),
            _DangerTile(
              icon: Icons.phone_in_talk_rounded,
              title: '音频护盾 · 模拟来电',
              subtitle: '播放警示音并弹出「来电」界面，帮助脱身尴尬场景',
              onTap: () => _audioShield(context),
            ),
            const SizedBox(height: 10),
            _DangerTile(
              icon: Icons.chat_rounded,
              title: '敏感沟通检测',
              subtitle: '约见聊天中出现暴力、资金等关键词时，PureGet 会强制弹窗（已在私信页启用）',
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('请返回聊天页发送消息以触发检测演示'),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade900,
                side: BorderSide(color: Colors.red.shade400),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                parentRef.read(meetSafetySessionProvider.notifier).deactivate();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已结束约见守护模式')),
                );
              },
              child: const Text('结束守护模式'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareRoute(
    BuildContext context,
    WidgetRef ref,
    MeetSafetySessionState session,
  ) async {
    final loc = ref.read(safetyLocationProvider);
    final lat = loc.latitude ?? 31.2304;
    final lng = loc.longitude ?? 121.4737;
    final text = '''
【搭哒 PureGet 行程共享】
实时位置：$lat, $lng（脱敏）
对方实人：${session.counterpartyName} · ${session.counterpartyPureGetRef}
我已开启守护，请留意我的动态。
''';
    await Clipboard.setData(ClipboardData(text: text.trim()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('已复制行程卡，可粘贴到微信 / 短信分享给紧急联系人'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _audioShield(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => _FakeCallDialog(
        onDismiss: () => Navigator.pop(dCtx),
      ),
    );
  }
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.deepOrange.shade800, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.red.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: Colors.brown.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.red.shade200),
            ],
          ),
        ),
      ),
    );
  }
}

class _FakeCallDialog extends StatefulWidget {
  const _FakeCallDialog({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  State<_FakeCallDialog> createState() => _FakeCallDialogState();
}

class _FakeCallDialogState extends State<_FakeCallDialog> {
  @override
  void initState() {
    super.initState();
    for (var i = 0; i < 4; i++) {
      Future<void>.delayed(Duration(milliseconds: 200 * i), () {
        if (mounted) {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.alert);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black87,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.call_received_rounded,
                color: Colors.greenAccent, size: 42),
            const SizedBox(height: 12),
            const Text(
              '妈妈',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Text(
              '手机来电 · 模拟',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _RoundCallBtn(
                  color: Colors.redAccent,
                  icon: Icons.call_end_rounded,
                  label: '挂断',
                  onTap: widget.onDismiss,
                ),
                _RoundCallBtn(
                  color: Colors.green,
                  icon: Icons.call_rounded,
                  label: '接听',
                  onTap: widget.onDismiss,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundCallBtn extends StatelessWidget {
  const _RoundCallBtn({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: Colors.white, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}
