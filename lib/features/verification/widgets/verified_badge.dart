import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// 真身认证徽章 —— 叠加在头像右下角
/// 使用银色线性渐变 + Shield 图标
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    this.size = 20,
    this.showLabel = false,
  });

  final double size;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    if (showLabel) {
      return _buildLabelBadge();
    }
    return _buildIconBadge();
  }

  Widget _buildIconBadge() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE8E8E8), // 亮银
            Color(0xFFA8A8B8), // 深银
            Color(0xFFD4D4D4), // 中银
            Color(0xFF8A8A9A), // 暗银
          ],
          stops: [0.0, 0.35, 0.65, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Icon(
        Icons.verified_rounded,
        size: size * 0.65,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLabelBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFDDDDDD),
            Color(0xFFAAAAAA),
            Color(0xFFCCCCCC),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shield_rounded,
            size: size * 0.8,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            '真身认证',
            style: TextStyle(
              color: Colors.white,
              fontSize: size * 0.65,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              shadows: const [
                Shadow(color: Colors.black26, blurRadius: 2),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────
// 头像 + 认证标记的组合组件
// ──────────────────────────────────────────

class AvatarWithVerification extends StatelessWidget {
  const AvatarWithVerification({
    super.key,
    required this.avatarUrl,
    required this.isVerified,
    this.verificationVideoUrl,
    this.size = 56,
    this.onTap,
  });

  final String? avatarUrl;
  final bool isVerified;
  final String? verificationVideoUrl;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.none,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          if (isVerified && verificationVideoUrl != null) {
            _showVerificationPreview(context);
          } else {
            onTap?.call();
          }
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Hero(
              tag: 'avatar_${avatarUrl ?? 'default'}',
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isVerified
                        ? const Color(0xFFCCCCCC)
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isVerified
                      ? [
                          BoxShadow(
                            color: Colors.grey.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          )
                        ]
                      : null,
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl!.isNotEmpty
                      ? Image.network(
                          avatarUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultAvatar(),
                        )
                      : _defaultAvatar(),
                ),
              ),
            ),
            if (isVerified)
              Positioned(
                right: -2,
                bottom: -2,
                child: VerifiedBadge(size: size * 0.35),
              ),
          ],
        ),
      ),
    );
  }

  Widget _defaultAvatar() {
    return Container(
      color: AppTheme.surfaceVariant,
      child: const Center(
        child: Text('🎭', style: TextStyle(fontSize: 24)),
      ),
    );
  }

  void _showVerificationPreview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerificationVideoSheet(
        videoUrl: verificationVideoUrl!,
        avatarUrl: avatarUrl,
      ),
    );
  }
}

// ──────────────────────────────────────────
// 核验视频底部面板
// ──────────────────────────────────────────

class _VerificationVideoSheet extends StatelessWidget {
  const _VerificationVideoSheet({
    required this.videoUrl,
    this.avatarUrl,
  });

  final String videoUrl;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFF1A1A2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // 拖拽条
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Icon(Icons.shield_rounded,
                      size: 20, color: Color(0xFFCCCCDD)),
                  const SizedBox(width: 8),
                  const Text(
                    '真身认证核验',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const VerifiedBadge(size: 24, showLabel: true),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 对比区域
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // 静态头像
                  Expanded(
                    child: _ComparePanel(
                      label: '主页照片',
                      child: avatarUrl != null
                          ? Image.network(avatarUrl!, fit: BoxFit.cover)
                          : Container(
                              color: AppTheme.surfaceVariant,
                              child: const Center(
                                child: Text('🎭',
                                    style: TextStyle(fontSize: 36)),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 核验视频缩略图
                  Expanded(
                    child: _ComparePanel(
                      label: '核验视频截帧',
                      badge: '🔒 加密存储',
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.grey[900]),
                          const Center(
                            child: Icon(
                              Icons.play_circle_fill_rounded,
                              size: 40,
                              color: Colors.white54,
                            ),
                          ),
                          // 时间戳水印
                          Positioned(
                            bottom: 6,
                            left: 6,
                            right: 6,
                            child: Text(
                              '认证时间：${_formatDate()}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // 说明
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08), width: 0.5),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: Colors.white54),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '此视频由平台加密存储，仅供身份真实性核验，不支持下载或转发。',
                        style:
                            TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 0, 20, MediaQuery.of(context).padding.bottom + 20),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: Colors.white10,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('关闭'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate() {
    final now = DateTime.now();
    return '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
  }
}

class _ComparePanel extends StatelessWidget {
  const _ComparePanel({
    required this.label,
    required this.child,
    this.badge,
  });

  final String label;
  final Widget child;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (badge != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 9),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
