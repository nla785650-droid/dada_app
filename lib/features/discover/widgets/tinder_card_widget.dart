import 'package:flutter/material.dart';

import '../models/match_profile.dart';
import 'tinder_card_overlay.dart';
import 'tinder_full_bleed_image.dart';

/// 单张全屏卡片： cover 图 + 底部信息层 + 滑动角标（由 opacity 控制）
class TinderCardWidget extends StatelessWidget {
  const TinderCardWidget({
    super.key,
    required this.profile,
    required this.dragOffset,
    required this.likeStampOpacity,
    required this.passStampOpacity,
    required this.bottomContentInset,
  });

  final MatchProfile profile;
  final Offset dragOffset;
  final double likeStampOpacity;
  final double passStampOpacity;
  final double bottomContentInset;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final rotRad = (dragOffset.dx / w) * 0.38;

    return Transform.translate(
      offset: dragOffset,
      child: Transform.rotate(
        angle: rotRad,
        alignment: Alignment.center,
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              TinderFullBleedImage(imageUrl: profile.imageUrl),
              TinderCardOverlay(
                profile: profile,
                bottomInset: bottomContentInset,
              ),
              TinderLikeNopeOverlays(
                likeOpacity: likeStampOpacity,
                passOpacity: passStampOpacity,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
