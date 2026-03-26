import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class CurrentUserProfile {
  const CurrentUserProfile({
    this.id = 'current_user',
    this.displayName = '搭哒用户',
    this.bio = '✨ 二次元爱好者',
    this.avatarUrl,
    this.isVerified = false,
  });

  final String id;
  final String displayName;
  final String bio;
  final String? avatarUrl;
  final bool isVerified;

  CurrentUserProfile copyWith({
    String? displayName,
    String? bio,
    String? avatarUrl,
    bool? isVerified,
  }) {
    return CurrentUserProfile(
      id: id,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

class AppUserProfileNotifier extends StateNotifier<CurrentUserProfile> {
  AppUserProfileNotifier() : super(const CurrentUserProfile()) {
    _load();
  }

  static const _kName = 'cu_display_name';
  static const _kBio = 'cu_bio';
  static const _kAvatar = 'cu_avatar_url';

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = CurrentUserProfile(
      displayName: p.getString(_kName) ?? state.displayName,
      bio: p.getString(_kBio) ?? state.bio,
      avatarUrl: p.getString(_kAvatar),
      isVerified: state.isVerified,
    );
  }

  Future<void> update({
    required String displayName,
    required String bio,
    String? avatarUrl,
  }) async {
    state = state.copyWith(
      displayName: displayName,
      bio: bio,
      avatarUrl: avatarUrl,
    );
    final p = await SharedPreferences.getInstance();
    await p.setString(_kName, displayName);
    await p.setString(_kBio, bio);
    if (avatarUrl != null) {
      await p.setString(_kAvatar, avatarUrl);
    } else {
      await p.remove(_kAvatar);
    }
  }

  /// 模拟更换头像（预设图床轮播，写入本地）
  Future<void> cycleDemoAvatar() async {
    const seeds = ['av_demo_1', 'av_demo_2', 'av_demo_3', 'av_demo_4'];
    var idx = 0;
    final cur = state.avatarUrl;
    if (cur != null) {
      for (var i = 0; i < seeds.length; i++) {
        if (cur.contains(seeds[i])) {
          idx = (i + 1) % seeds.length;
          break;
        }
      }
    }
    final url = 'https://picsum.photos/seed/${seeds[idx]}/256/256';
    state = state.copyWith(avatarUrl: url);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAvatar, url);
  }
}

/// 本地可编辑资料（与 Supabase 的 [currentUserProvider] 区分）
final appUserProfileProvider =
    StateNotifierProvider<AppUserProfileNotifier, CurrentUserProfile>(
  (ref) => AppUserProfileNotifier(),
);
