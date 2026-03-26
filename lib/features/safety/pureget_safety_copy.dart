/// PureGet AI 安全播报（MVP：规则引擎；可替换为真实 LLM）。
class PuregetSafetyCopy {
  PuregetSafetyCopy._();

  static String advice({
    required int hour,
    required bool hasLocation,
  }) {
    final isNight = hour >= 22 || hour < 6;
    if (!hasLocation) {
      return 'PureGet AI：建议授权定位，便于紧急情况下快速分享准确位置。';
    }
    if (isNight) {
      return 'PureGet AI：当前处于夜间，建议开启行程分享并告知亲友你的见面地点。';
    }
    if (hour >= 18) {
      return 'PureGet AI：傍晚出行请选择明亮、人流较多的路线，抵达后确认环境安全。';
    }
    return 'PureGet AI：保持通讯畅通；首次线下见面建议选择公共场所。';
  }
}
