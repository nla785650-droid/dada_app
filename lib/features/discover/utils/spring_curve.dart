import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 欠阻尼弹簧感曲线（背景色过渡等）
class SpringCurve extends Curve {
  const SpringCurve({this.stiffness = 200, this.damping = 20});

  final double stiffness;
  final double damping;

  @override
  double transform(double t) {
    final w = math.sqrt(stiffness - damping * damping / 4);
    final result = 1 -
        math.exp(-damping * t / 2) *
            (math.cos(w * t) + (damping / (2 * w)) * math.sin(w * t));
    return result.clamp(0.0, 1.0);
  }
}
