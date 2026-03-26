import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/match_profile.dart';

/// MVP：在本地内存中模拟记录用户滑动偏好（后续可同步后端）。
@immutable
class MatchPreferencesState {
  const MatchPreferencesState({
    this.likedIds = const [],
    this.passedIds = const [],
  });

  final List<String> likedIds;
  final List<String> passedIds;

  MatchPreferencesState copyWith({
    List<String>? likedIds,
    List<String>? passedIds,
  }) {
    return MatchPreferencesState(
      likedIds: likedIds ?? this.likedIds,
      passedIds: passedIds ?? this.passedIds,
    );
  }
}

class MatchPreferencesNotifier extends StateNotifier<MatchPreferencesState> {
  MatchPreferencesNotifier() : super(const MatchPreferencesState());

  void recordSwipe(String profileId, MatchSwipeDirection direction) {
    switch (direction) {
      case MatchSwipeDirection.like:
        state = state.copyWith(
          likedIds: [...state.likedIds, profileId],
          passedIds: state.passedIds.where((id) => id != profileId).toList(),
        );
      case MatchSwipeDirection.pass:
        state = state.copyWith(
          passedIds: [...state.passedIds, profileId],
          likedIds: state.likedIds.where((id) => id != profileId).toList(),
        );
    }
  }
}

final matchPreferencesProvider =
    StateNotifierProvider<MatchPreferencesNotifier, MatchPreferencesState>(
  (ref) => MatchPreferencesNotifier(),
);
