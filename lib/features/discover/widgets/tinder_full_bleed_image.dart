import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Web 友好：限制解码尺寸，BoxFit.cover 铺满不形变content。
class TinderFullBleedImage extends StatelessWidget {
  const TinderFullBleedImage({
    super.key,
    required this.imageUrl,
  });

  final String imageUrl;

  int? _decodePx(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final w = (MediaQuery.sizeOf(context).width * dpr).round();
    final cap = kIsWeb ? 1600 : 2000;
    return w.clamp(360, cap);
  }

  int? _decodeH(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final h = (MediaQuery.sizeOf(context).height * dpr).round();
    final cap = kIsWeb ? 2200 : 2800;
    return h.clamp(480, cap);
  }

  @override
  Widget build(BuildContext context) {
    final mw = _decodePx(context);
    final mh = _decodeH(context);

    return Positioned.fill(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        alignment: Alignment.center,
        fadeInDuration: const Duration(milliseconds: 180),
        fadeOutDuration: const Duration(milliseconds: 80),
        filterQuality: FilterQuality.medium,
        memCacheWidth: mw,
        memCacheHeight: mh,
        maxWidthDiskCache: kIsWeb ? 1600 : 2000,
        maxHeightDiskCache: kIsWeb ? 2200 : 2800,
        placeholder: (_, __) => Container(
          color: AppTheme.surfaceVariant,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.primary,
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: AppTheme.surfaceVariant,
          alignment: Alignment.center,
          child: const Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: AppTheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
