import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/current_user_provider.dart'
    show appUserProfileProvider;

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _bioCtrl;
  bool _fieldsReady = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fieldsReady) {
      final u = ref.read(appUserProfileProvider);
      _nameCtrl.text = u.displayName;
      _bioCtrl.text = u.bio;
      _fieldsReady = true;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(appUserProfileProvider.notifier).update(
          displayName: _nameCtrl.text.trim(),
          bio: _bioCtrl.text.trim(),
          avatarUrl: ref.read(appUserProfileProvider).avatarUrl,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('资料已更新'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(appUserProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('编辑资料'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await ref
                          .read(appUserProfileProvider.notifier)
                          .cycleDemoAvatar();
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已切换演示头像（模拟）'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    customBorder: const CircleBorder(),
                    child: Ink(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.surface,
                        border: Border.all(
                          color: AppTheme.divider.withValues(alpha: 0.9),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: me.avatarUrl != null && me.avatarUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: me.avatarUrl!,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                  child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.person_rounded,
                                  size: 48,
                                ),
                              )
                            : const Icon(Icons.add_a_photo_outlined, size: 40),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '点击头像更换（演示）',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(
              labelText: '昵称',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _bioCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: '个人签名',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: const Text('保存修改'),
          ),
        ],
      ),
    );
  }
}
