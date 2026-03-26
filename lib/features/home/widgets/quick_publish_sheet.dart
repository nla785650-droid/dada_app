import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/post_model.dart';
import '../../../data/models/profile_model.dart';
import '../../../shared/providers/current_user_provider.dart'
    show appUserProfileProvider;
import '../../../shared/services/agent_bridge_service.dart';
import '../providers/home_provider.dart';
import 'pureget_image_audit.dart';

/// 首页快速发动态（BottomSheet，Web 使用 image_picker 兼容方案）
Future<void> showQuickPublishSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _QuickPublishBody(),
  );
}

enum _AuditPhase {
  idle,
  verifying,
  passed,
  suspected,
}

class _QuickPublishBody extends ConsumerStatefulWidget {
  const _QuickPublishBody();

  @override
  ConsumerState<_QuickPublishBody> createState() => _QuickPublishBodyState();
}

class _QuickPublishBodyState extends ConsumerState<_QuickPublishBody>
    with SingleTickerProviderStateMixin {
  final _textCtrl = TextEditingController();
  Uint8List? _bytes;
  XFile? _pickedFile;
  _AuditPhase _auditPhase = _AuditPhase.idle;
  bool _busy = false;
  String _category = 'other';

  /// PureGet 打字机日志
  String _logLine1 = '';
  String _logLine2 = '';
  String _logLine3 = '';

  bool _artNonRealAck = false;
  int _auditGeneration = 0;

  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  void _syncScanAnimation() {
    if (_auditPhase == _AuditPhase.verifying) {
      if (!_scanController.isAnimating) {
        _scanController.repeat();
      }
    } else {
      _scanController.stop();
      _scanController.reset();
    }
  }

  Future<void> _typeLine(String full, void Function(String) setLine) async {
    const perChar = Duration(milliseconds: 28);
    for (var i = 0; i <= full.length; i++) {
      if (!mounted) return;
      if (_auditPhase != _AuditPhase.verifying) return;
      setLine(full.substring(0, i));
      setState(() {});
      await Future<void>.delayed(perChar);
    }
  }

  Future<void> _runPureGetAudit(XFile file) async {
    final gen = ++_auditGeneration;
    setState(() {
      _auditPhase = _AuditPhase.verifying;
      _artNonRealAck = false;
      _logLine1 = '';
      _logLine2 = '';
      _logLine3 = '';
    });
    _syncScanAnimation();

    final verifyFuture = AgentBridgeService.instance.verifyImage(file);
    final minHold = Future<void>.delayed(const Duration(milliseconds: 2600));

    final typewriter = () async {
      await _typeLine('正在提取 EXIF 拍摄数据...', (s) => _logLine1 = s);
      if (!mounted || gen != _auditGeneration) return;
      await _typeLine('正在比对 AIGC 扩散模型特征...', (s) => _logLine2 = s);
      if (!mounted || gen != _auditGeneration) return;
      await _typeLine('PureGet 结论：[计算中]', (s) => _logLine3 = s);
    }();

    await Future.wait<void>([verifyFuture, minHold, typewriter]);

    if (!mounted || gen != _auditGeneration) return;

    final result = await verifyFuture;
    if (!mounted || gen != _auditGeneration) return;

    setState(() {
      _auditPhase =
          result.isPass ? _AuditPhase.passed : _AuditPhase.suspected;
      if (result.isPass) {
        _logLine3 = 'PureGet 结论：审计通过 · 判定为真实拍摄';
      } else {
        _logLine3 = 'PureGet 结论：存在明显 AIGC / 合成疑似特征';
      }
    });
    _syncScanAnimation();

    if (!result.isPass && mounted) {
      await showPureGetAigcWarningDialog(context);
    }
  }

  Future<void> _pickImage() async {
    if (_busy || _auditPhase == _AuditPhase.verifying) return;
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: kIsWeb ? 1600 : 2000,
      maxHeight: kIsWeb ? 2200 : 2800,
      imageQuality: 88,
    );
    if (x == null) return;
    final b = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedFile = x;
      _bytes = b;
    });
    await _runPureGetAudit(x);
  }

  bool get _pureGetAllowsPublish {
    if (_bytes == null || _pickedFile == null) return false;
    if (_auditPhase == _AuditPhase.verifying) return false;
    if (_auditPhase == _AuditPhase.idle) return false;
    if (_auditPhase == _AuditPhase.passed) return true;
    return _artNonRealAck;
  }

  Future<void> _publish() async {
    final text = _textCtrl.text.trim();
    if (_bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择一张图片'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_pureGetAllowsPublish) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _auditPhase == _AuditPhase.suspected && !_artNonRealAck
                ? 'PureGet 未放行：请更换照片或勾选艺术创作声明'
                : '请等待 PureGet 完成鉴伪',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入动态文字'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final user = ref.read(appUserProfileProvider);
    final id = const Uuid().v4();

    final post = Post(
      id: id,
      providerId: user.id,
      title: text.length > 36 ? '${text.substring(0, 36)}…' : text,
      description: text,
      category: _category,
      images: const [],
      localCoverBytes: _bytes,
      price: 0,
      priceUnit: '次',
      tags: const ['动态'],
      location: '同城',
      createdAt: DateTime.now(),
      provider: Profile(
        id: user.id,
        username: user.id,
        displayName: user.displayName,
        avatarUrl: user.avatarUrl,
        role: 'provider',
        bio: user.bio,
        location: '同城',
        createdAt: DateTime.now(),
        isVerified: user.isVerified,
      ),
    );

    ref.read(homePostsProvider.notifier).prependUserPost(post);

    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('发布成功，已展示在首页瀑布流'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final auditBusy = _auditPhase == _AuditPhase.verifying;
    final showPureGetLog = _bytes != null;
    final showPassHint =
        _auditPhase == _AuditPhase.passed && _pickedFile != null;
    final showSuspectCheckbox = _auditPhase == _AuditPhase.suspected;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
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
                    color: AppTheme.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '发布动态',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Material(
                color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: (_busy || auditBusy) ? null : _pickImage,
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _bytes == null
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_photo_alternate_rounded,
                                    size: 44, color: AppTheme.onSurfaceVariant),
                                SizedBox(height: 8),
                                Text('点击选择图片',
                                    style: TextStyle(
                                        color: AppTheme.onSurfaceVariant)),
                              ],
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.memory(
                                  _bytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  gaplessPlayback: true,
                                ),
                                if (auditBusy)
                                  PureGetAuditingLayer(
                                    scanProgress: _scanController,
                                  ),
                                if (_auditPhase == _AuditPhase.passed)
                                  const Positioned(
                                    top: 10,
                                    right: 10,
                                    child: PureGetVerifiedBadge(),
                                  ),
                                if (_auditPhase == _AuditPhase.suspected)
                                  const Positioned.fill(
                                    child: PureGetSuspectTintLayer(),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              if (showPureGetLog) ...[
                const SizedBox(height: 12),
                PureGetAgentLogPanel(
                  line1: _logLine1,
                  line2: _logLine2,
                  line3: _logLine3,
                ),
              ],
              if (showPassHint) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: PureGetAuditTheme.deepBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: PureGetAuditTheme.passGreen.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_user_rounded,
                          color: PureGetAuditTheme.passGreen, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'PureGet 审计通过，该照片为真实拍摄，建议发布。',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: PureGetAuditTheme.deepBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (showSuspectCheckbox) ...[
                const SizedBox(height: 10),
                CheckboxTheme(
                  data: CheckboxThemeData(
                    fillColor: WidgetStateProperty.resolveWith((s) {
                      if (s.contains(WidgetState.selected)) {
                        return PureGetAuditTheme.warningAmber;
                      }
                      return null;
                    }),
                  ),
                  child: CheckboxListTile(
                    value: _artNonRealAck,
                    onChanged: (v) =>
                        setState(() => _artNonRealAck = v ?? false),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      '我确认此为艺术创作而非实人记录，并自愿承担展示风险',
                      style: TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('日常'),
                    selected: _category == 'other',
                    onSelected: auditBusy ? null : (_) => setState(() => _category = 'other'),
                  ),
                  ChoiceChip(
                    label: const Text('Cos'),
                    selected: _category == 'cosplay',
                    onSelected: auditBusy
                        ? null
                        : (_) => setState(() => _category = 'cosplay'),
                  ),
                  ChoiceChip(
                    label: const Text('摄影'),
                    selected: _category == 'photo',
                    onSelected: auditBusy
                        ? null
                        : (_) => setState(() => _category = 'photo'),
                  ),
                  ChoiceChip(
                    label: const Text('陪玩'),
                    selected: _category == 'game',
                    onSelected: auditBusy
                        ? null
                        : (_) => setState(() => _category = 'game'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _textCtrl,
                maxLines: 4,
                enabled: !auditBusy,
                decoration: const InputDecoration(
                  hintText: '分享你的动态…',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _pureGetAllowsPublish && !_busy
                      ? AppTheme.primary
                      : null,
                  disabledBackgroundColor: AppTheme.surfaceVariant,
                  disabledForegroundColor: AppTheme.onSurfaceVariant,
                ),
                onPressed: (_busy ||
                        auditBusy ||
                        !_pureGetAllowsPublish)
                    ? null
                    : _publish,
                child: _busy
                    ? SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: PureGetAuditTheme.accentCyan,
                          backgroundColor:
                              PureGetAuditTheme.panel.withValues(alpha: 0.4),
                        ),
                      )
                    : const Text('发布'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
