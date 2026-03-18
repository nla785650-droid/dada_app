/// 匹配页筛选状态模型
/// 维度：陪拍/陪玩/委托、性别、身高、风格、星座、MBTI
class DiscoverFilterState {
  const DiscoverFilterState({
    this.serviceTypes = const {},
    this.gender,
    this.heightRange,
    this.styles = const {},
    this.zodiac,
    this.mbti,
  });

  /// 服务类型：陪拍、陪玩、委托
  final Set<String> serviceTypes;

  /// 性别：男、女
  final String? gender;

  /// 身高区间：150-160、160-170、170-180、180+
  final String? heightRange;

  /// 风格标签
  final Set<String> styles;

  /// 星座
  final String? zodiac;

  /// MBTI
  final String? mbti;

  bool get hasAnyFilter =>
      serviceTypes.isNotEmpty ||
      gender != null ||
      heightRange != null ||
      styles.isNotEmpty ||
      zodiac != null ||
      mbti != null;

  int get activeCount {
    var c = 0;
    if (serviceTypes.isNotEmpty) c++;
    if (gender != null) c++;
    if (heightRange != null) c++;
    if (styles.isNotEmpty) c++;
    if (zodiac != null) c++;
    if (mbti != null) c++;
    return c;
  }

  DiscoverFilterState copyWith({
    Set<String>? serviceTypes,
    String? gender,
    String? heightRange,
    Set<String>? styles,
    String? zodiac,
    String? mbti,
  }) {
    return DiscoverFilterState(
      serviceTypes: serviceTypes ?? this.serviceTypes,
      gender: gender ?? this.gender,
      heightRange: heightRange ?? this.heightRange,
      styles: styles ?? this.styles,
      zodiac: zodiac ?? this.zodiac,
      mbti: mbti ?? this.mbti,
    );
  }
}

// ── 筛选选项常量 ──

/// 服务类型（对应达人 tag）
const kFilterServiceTypes = [
  ('陪拍', '摄影师', '📸'),
  ('陪玩', '陪玩', '🎮'),
  ('委托', 'Coser', '🎭'),
];

/// 性别
const kFilterGenders = [
  ('不限', null),
  ('男', '男'),
  ('女', '女'),
];

/// 身高区间 (label, value)
const kFilterHeightRanges = [
  ('不限', null),
  ('150-160', '150-160'),
  ('160-170', '160-170'),
  ('170-180', '170-180'),
  ('180+', '180+'),
];

/// 风格
const kFilterStyles = [
  '日系', '古风', '暗黑', '小清新', '赛博朋克',
  '洛丽塔', 'JK制服', '汉服', '胶片', '极简',
  '机甲', '二次元', '唐装', '户外', '棚拍',
  '黑白', '城市', '科幻',
];

/// 星座
const kFilterZodiacs = [
  ('不限', null),
  ('白羊座', '白羊座'),
  ('金牛座', '金牛座'),
  ('双子座', '双子座'),
  ('巨蟹座', '巨蟹座'),
  ('狮子座', '狮子座'),
  ('处女座', '处女座'),
  ('天秤座', '天秤座'),
  ('天蝎座', '天蝎座'),
  ('射手座', '射手座'),
  ('摩羯座', '摩羯座'),
  ('水瓶座', '水瓶座'),
  ('双鱼座', '双鱼座'),
];

/// MBTI（常见 16 型）
const kFilterMbtiTypes = [
  ('不限', null),
  ('INTJ', 'INTJ'),
  ('INTP', 'INTP'),
  ('ENTJ', 'ENTJ'),
  ('ENTP', 'ENTP'),
  ('INFJ', 'INFJ'),
  ('INFP', 'INFP'),
  ('ENFJ', 'ENFJ'),
  ('ENFP', 'ENFP'),
  ('ISTJ', 'ISTJ'),
  ('ISFJ', 'ISFJ'),
  ('ESTJ', 'ESTJ'),
  ('ESFJ', 'ESFJ'),
  ('ISTP', 'ISTP'),
  ('ISFP', 'ISFP'),
  ('ESTP', 'ESTP'),
  ('ESFP', 'ESFP'),
];
