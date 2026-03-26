import 'package:image_picker/image_picker.dart';

/// PureGet Agent 鉴伪结论（与后端 Bridge 对齐的占位实现）
enum PureGetImageVerdict {
  /// 判定为真实拍摄，允许发布（或通过艺术声明后发布）
  authentic,

  /// 疑似 AIGC / 篡改，需拦截或二次确认
  suspectedAigc,
}

class PureGetVerifyResult {
  const PureGetVerifyResult({
    required this.verdict,
    this.signalScore,
  });

  final PureGetImageVerdict verdict;

  /// 0–1 模拟置信辅助字段（便于后续接真模型）
  final double? signalScore;

  bool get isPass => verdict == PureGetImageVerdict.authentic;
}

/// 搭哒 × PureGet：图片鉴伪桥接（当前为可替换的异步模拟实现）
class AgentBridgeService {
  AgentBridgeService._();
  static final AgentBridgeService instance = AgentBridgeService._();

  /// 对选图结果做异步审计（不阻塞 isolate；具体推理应在后台 isolate / 服务中执行）
  Future<PureGetVerifyResult> verifyImage(XFile imageFile) async {
    final bytes = await imageFile.readAsBytes();
    // 模拟端侧最低耗时，避免 UI 闪一下结束
    await Future<void>.delayed(const Duration(milliseconds: 600));

    var h = 0;
    final len = bytes.length;
    final step = len > 5000 ? 97 : (len > 0 ? 1 : 1);
    for (var i = 0; i < len && i < 8000; i += step) {
      h = (h + bytes[i]) & 0x7fffffff;
    }

    // 约 1/3 概率模拟「疑似 AIGC」，便于联调两条分支
    final suspected = len > 0 && (h % 3 == 0);
    if (suspected) {
      return PureGetVerifyResult(
        verdict: PureGetImageVerdict.suspectedAigc,
        signalScore: 0.78,
      );
    }
    return PureGetVerifyResult(
      verdict: PureGetImageVerdict.authentic,
      signalScore: 0.12,
    );
  }
}
