import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../chat/providers/chat_threads_provider.dart';
import '../models/match_profile.dart';

/// 全屏「It's a Match!」祝贺（模拟互滑成功）
Future<void> showItsAMatchDialog(
  BuildContext context,
  WidgetRef ref, {
  required MatchProfile profile,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.92),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, anim1, anim2) {
      return _ItsAMatchScaffold(
        profile: profile,
        onMessage: () {
          ref.read(chatThreadsProvider.notifier).addOrBumpMatchThread(
                id: profile.id,
                name: profile.name,
                imageUrl: profile.imageUrl,
              );
          Navigator.of(ctx).pop();
          ctx.pushNamed(
            'chatDetail',
            pathParameters: {'otherId': profile.id},
            extra: {
              'currentUserId': 'current_user',
              'otherUserName': profile.name,
              'otherUserAvatar': profile.imageUrl,
              'isProvider': true,
            },
          );
        },
        onContinue: () => Navigator.of(ctx).pop(),
      );
    },
    transitionBuilder: (ctx, anim, _, child) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: anim, curve: Curves.elasticOut),
        child: FadeTransition(opacity: anim, child: child),
      );
    },
  );
}

class _ItsAMatchScaffold extends StatelessWidget {
  const _ItsAMatchScaffold({
    required this.profile,
    required this.onMessage,
    required this.onContinue,
  });

  final MatchProfile profile;
  final VoidCallback onMessage;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 48),
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFF4081), Color(0xFFFF9100)],
                ).createShader(bounds),
                child: const Text(
                  "It's a Match!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 38,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '你和 ${profile.name} 互相喜欢了对方',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _RoundPortrait(url: profile.imageUrl, label: profile.name),
                ],
              ),
              const Spacer(),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: onMessage,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: const Text(
                      '立即私信',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onContinue,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white38),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      '继续划牌',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundPortrait extends StatelessWidget {
  const _RoundPortrait({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: [
              BoxShadow(
                color: Colors.pinkAccent.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              memCacheWidth: 400,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
