import 'dart:async';
import 'dart:math' as math;

// ══════════════════════════════════════════════════════════════
// RetryPolicy — 通用重试 + 指数退避工具
//
// 用途：
//   · Gemini AI 调用（视觉核验、文本生成）
//   · Supabase RPC 调用（并发锁、网络抖动）
//   · 任意 Future<T> 异步操作
//
// 策略：Exponential Backoff with Jitter
//   delay = min(base * 2^attempt, maxDelay) + random(0, jitter)
//   这是 Google、AWS 等大型系统推荐的标准重试策略
// ══════════════════════════════════════════════════════════════

// ── 可重试错误的判断函数类型 ──
typedef RetryCondition = bool Function(Object error);

// ── 进度回调 ──
typedef RetryCallback = void Function(int attempt, Duration nextDelay, Object error);

/// 默认重试条件：网络/超时/服务端 5xx 类错误
bool defaultRetryCondition(Object error) {
  final msg = error.toString().toLowerCase();
  return msg.contains('timeout') ||
      msg.contains('network') ||
      msg.contains('connection') ||
      msg.contains('socket') ||
      msg.contains('503') ||
      msg.contains('429') || // Rate limit
      msg.contains('unavailable');
}

class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts    = 3,
    this.baseDelay      = const Duration(milliseconds: 400),
    this.maxDelay       = const Duration(seconds: 8),
    this.jitter         = const Duration(milliseconds: 200),
    this.timeout        = const Duration(seconds: 15),
    this.shouldRetry    = defaultRetryCondition,
    this.onRetry,
  });

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxDelay;
  final Duration jitter;
  final Duration timeout;
  final RetryCondition shouldRetry;
  final RetryCallback? onRetry;

  static final _rng = math.Random();

  /// 执行带重试的操作
  Future<T> execute<T>(Future<T> Function() operation) async {
    Object? lastError;

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        // 带超时的单次调用
        return await operation().timeout(timeout);
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt == maxAttempts - 1) rethrow;
        final delay = _calcDelay(attempt);
        onRetry?.call(attempt + 1, delay, e);
        await Future.delayed(delay);
      } catch (e) {
        lastError = e;
        if (!shouldRetry(e) || attempt == maxAttempts - 1) rethrow;
        final delay = _calcDelay(attempt);
        onRetry?.call(attempt + 1, delay, e);
        await Future.delayed(delay);
      }
    }

    // 理论上不会到这里，但 Dart 需要确保路径完整
    throw lastError ?? Exception('RetryPolicy: unknown error after $maxAttempts attempts');
  }

  /// 指数退避 + 抖动计算
  Duration _calcDelay(int attempt) {
    final expMs = baseDelay.inMilliseconds * math.pow(2, attempt).toInt();
    final cappedMs = expMs.clamp(0, maxDelay.inMilliseconds);
    final jitterMs = _rng.nextInt(jitter.inMilliseconds + 1);
    return Duration(milliseconds: cappedMs + jitterMs);
  }
}

// ── 预设策略实例 ──

/// Gemini AI 专用策略（较长超时，最多 3 次）
const geminiRetryPolicy = RetryPolicy(
  maxAttempts: 3,
  baseDelay:   Duration(seconds: 1),
  maxDelay:    Duration(seconds: 10),
  timeout:     Duration(seconds: 20),
);

/// Supabase RPC 专用策略（快速重试，短超时）
const supabaseRetryPolicy = RetryPolicy(
  maxAttempts: 2,
  baseDelay:   Duration(milliseconds: 300),
  maxDelay:    Duration(seconds: 3),
  timeout:     Duration(seconds: 8),
);

// ══════════════════════════════════════════════════════════════
// GracefulDegradation — AI 服务优雅降级框架
//
// 策略：Primary（AI） → Fallback（规则引擎） → Default（静态）
// ══════════════════════════════════════════════════════════════

class GracefulDegradation<T> {
  const GracefulDegradation({
    required this.primary,
    required this.fallback,
    this.onFallback,
  });

  /// 主路径：AI 服务
  final Future<T> Function() primary;

  /// 降级路径：基于规则的静态推荐
  final Future<T> Function() fallback;

  /// 降级时的回调（用于埋点记录降级事件）
  final void Function(Object error)? onFallback;

  Future<T> call() async {
    try {
      return await geminiRetryPolicy.execute(primary);
    } catch (e) {
      onFallback?.call(e);
      return await fallback();
    }
  }
}
