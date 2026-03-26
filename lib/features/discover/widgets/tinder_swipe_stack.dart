import 'package:flutter/material.dart';

import '../models/match_profile.dart';
import 'tinder_card_widget.dart';
import 'tinder_full_bleed_image.dart';

/// 全屏叠卡 + 左右滑（喜欢 / 无感），带倾斜与飞出动画。
class TinderSwipeStack extends StatefulWidget {
  const TinderSwipeStack({
    super.key,
    required this.profiles,
    required this.currentIndex,
    required this.onSwiped,
    this.onProfileTap,
    this.bottomContentInset = 88,
  });

  final List<MatchProfile> profiles;
  final int currentIndex;
  final void Function(MatchProfile profile, MatchSwipeDirection direction)
      onSwiped;
  final void Function(MatchProfile profile)? onProfileTap;
  final double bottomContentInset;

  @override
  State<TinderSwipeStack> createState() => _TinderSwipeStackState();
}

class _TinderSwipeStackState extends State<TinderSwipeStack>
    with SingleTickerProviderStateMixin {
  Offset _drag = Offset.zero;
  late AnimationController _anim;
  Animation<Offset>? _offsetAnim;
  bool _hasPan = false;

  static const _snapBackDuration = Duration(milliseconds: 220);
  static const _flyOutDuration = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this);
    _anim.addListener(_onAnimTick);
  }

  void _onAnimTick() {
    if (_offsetAnim != null) {
      setState(() => _drag = _offsetAnim!.value);
    }
  }

  @override
  void dispose() {
    _anim.removeListener(_onAnimTick);
    _anim.dispose();
    super.dispose();
  }

  Future<void> _playOffsetTween(
    Offset begin,
    Offset end,
    Duration duration,
    Curve curve,
  ) async {
    _offsetAnim = Tween<Offset>(begin: begin, end: end).animate(
      CurvedAnimation(parent: _anim, curve: curve),
    );
    _anim.duration = duration;
    await _anim.forward(from: 0);
    _anim.reset();
    _offsetAnim = null;
  }

  double _stampOpacity(double dx, double width) {
    return (dx.abs() / (width * 0.28)).clamp(0.0, 1.0);
  }

  void _onPanStart(DragStartDetails _) {
    _hasPan = true;
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_anim.isAnimating) return;
    setState(() {
      _drag += d.delta;
    });
  }

  Future<void> _onPanEnd(DragEndDetails d) async {
    if (_anim.isAnimating) return;

    final size = MediaQuery.sizeOf(context);
    final w = size.width;
    final vx = d.velocity.pixelsPerSecond.dx;
    final dist = _drag.distance;

    if (_hasPan && dist < 16 && vx.abs() < 200) {
      widget.onProfileTap?.call(widget.profiles[widget.currentIndex]);
      if (_drag != Offset.zero) {
        await _playOffsetTween(
          _drag,
          Offset.zero,
          _snapBackDuration,
          Curves.easeOutCubic,
        );
        if (mounted) setState(() => _drag = Offset.zero);
      }
      _hasPan = false;
      return;
    }
    _hasPan = false;

    const threshold = 96.0;
    final like = _drag.dx > threshold || vx > 760;
    final pass = _drag.dx < -threshold || vx < -760;

    if (like) {
      final end = Offset(w * 1.45, _drag.dy + 24);
      await _playOffsetTween(_drag, end, _flyOutDuration, Curves.easeInCubic);
      if (!mounted) return;
      widget.onSwiped(
        widget.profiles[widget.currentIndex],
        MatchSwipeDirection.like,
      );
      setState(() => _drag = Offset.zero);
      return;
    }

    if (pass) {
      final end = Offset(-w * 1.45, _drag.dy + 24);
      await _playOffsetTween(_drag, end, _flyOutDuration, Curves.easeInCubic);
      if (!mounted) return;
      widget.onSwiped(
        widget.profiles[widget.currentIndex],
        MatchSwipeDirection.pass,
      );
      setState(() => _drag = Offset.zero);
      return;
    }

    await _playOffsetTween(
      _drag,
      Offset.zero,
      _snapBackDuration,
      Curves.easeOutCubic,
    );
    if (mounted) setState(() => _drag = Offset.zero);
  }

  void _onTap() {
    if (_anim.isAnimating || _drag != Offset.zero) return;
    widget.onProfileTap?.call(widget.profiles[widget.currentIndex]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentIndex >= widget.profiles.length) {
      return const SizedBox.expand();
    }

    final w = MediaQuery.sizeOf(context).width;
    final i = widget.currentIndex;
    final p0 = widget.profiles[i];

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        if (i + 2 < widget.profiles.length)
          _DeckBackLayer(profile: widget.profiles[i + 2], scale: 0.93, dy: 18),
        if (i + 1 < widget.profiles.length)
          _DeckBackLayer(profile: widget.profiles[i + 1], scale: 0.97, dy: 9),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: TinderCardWidget(
            profile: p0,
            dragOffset: _drag,
            likeStampOpacity: _stampOpacity(_drag.dx, w),
            passStampOpacity: _stampOpacity(-_drag.dx, w),
            bottomContentInset: widget.bottomContentInset,
          ),
        ),
      ],
    );
  }
}

class _DeckBackLayer extends StatelessWidget {
  const _DeckBackLayer({
    required this.profile,
    required this.scale,
    required this.dy,
  });

  final MatchProfile profile;
  final double scale;
  final double dy;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Stack(
            fit: StackFit.expand,
            children: [
              TinderFullBleedImage(imageUrl: profile.imageUrl),
              Container(color: Colors.black.withValues(alpha: 0.18)),
            ],
          ),
        ),
      ),
    );
  }
}
