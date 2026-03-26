import 'dart:math' as math;

import '../models/match_profile.dart';

List<MatchProfile> buildMatchMockProfiles() {
  final names = ['小樱', '星野', '绫波', '凉宫', '柚子', '美月', '彩花', '晴香', '雪乃', '和泉'];
  final types = ['Coser', '摄影师', '陪玩', 'Coser', '摄影师'];
  final emojis = ['🎭', '📸', '🎮', '🎭', '📸'];
  final locs = ['北京', '上海', '广州', '成都', '杭州'];
  final occupations = ['自由摄影师', '二次元妆造', '游戏陪练', '宅舞教练', '人像修图'];
  final taglines = [
    '用镜头记录每一套心的角色。',
    '日系棚拍 · 自然光爱好者。',
    '王者/原神都可，佛系上分。',
    '周末可约外景，提前沟通主题。',
    '希望遇到同频的你，认真接单。',
    '汉服/JK/Lolita 均可，妆造可包。',
    '喜欢胶片质感，欢迎私信样片。',
    '退役电竞少年，声控福利。',
    'Cos 后期三年，擅长合成。',
    '一起逛漫展也 OK～',
  ];
  final allTags = [
    ['汉服', '古风', '唐装'],
    ['日系', '写真', '棚拍'],
    ['王者', '原神', '二次元'],
    ['洛丽塔', 'JK制服', '小清新'],
    ['户外', '城市', '胶片'],
  ];
  final genders = ['女', '女', '男', '女', '男', '女', '男', '女', '女', '男'];
  final heights = [158, 165, 178, 162, 175, 168, 182, 155, 170, 172];
  final zodiacs = [
    '白羊座', '金牛座', '双子座', '巨蟹座', '狮子座',
    '处女座', '天秤座', '天蝎座', '射手座', '摩羯座',
  ];
  final mbtis = [
    'INFP', 'ENFP', 'ISTJ', 'INFJ', 'ENTP',
    'ISFJ', 'ESTP', 'INTJ', 'ENFJ', 'ISTP',
  ];

  return List.generate(15, (i) {
    return MatchProfile(
      id: 'p_$i',
      name: names[i % 10],
      age: 20 + (i % 8),
      occupation: occupations[i % 5],
      distanceKm: 1 + (i * 3) % 25,
      tagline: taglines[i % taglines.length],
      tag: types[i % 5],
      typeEmoji: emojis[i % 5],
      imageUrl: 'https://picsum.photos/seed/profile$i/800/1200',
      rating: 4.5 + (i % 5) * 0.1,
      reviews: 20 + i * 7,
      location: locs[i % 5],
      price: 80 + i * 30,
      tags: allTags[i % 5],
      gender: genders[i % 10],
      heightCm: heights[i % 10],
      zodiac: zodiacs[i % 10],
      mbti: mbtis[i % 10],
      isVerified: i % 3 == 0,
    );
  });
}

final matchDiversityPool = <MatchProfile>[
  MatchProfile(
    id: 'div_1',
    name: '雏菊',
    age: 26,
    occupation: '建筑空间摄影',
    distanceKm: 8,
    tagline: '极简与光影，是我唯一的语言。',
    tag: '摄影师',
    typeEmoji: '📸',
    imageUrl: 'https://picsum.photos/seed/div1/800/1200',
    rating: 4.9,
    reviews: 156,
    location: '深圳',
    price: 240,
    tags: const ['建筑', '极简', '黑白'],
    isDiversityPick: true,
    gender: '女',
    heightCm: 166,
    zodiac: '水瓶座',
    mbti: 'INTJ',
    isVerified: true,
  ),
  MatchProfile(
    id: 'div_2',
    name: '冬霞',
    age: 23,
    occupation: '机甲道具制作',
    distanceKm: 12,
    tagline: '赛博朋克系 Cos，定制排期请私信。',
    tag: 'Coser',
    typeEmoji: '🎭',
    imageUrl: 'https://picsum.photos/seed/div2/800/1200',
    rating: 4.8,
    reviews: 89,
    location: '武汉',
    price: 160,
    tags: const ['机甲', '赛博朋克', '科幻'],
    isDiversityPick: true,
    gender: '女',
    heightCm: 168,
    zodiac: '天蝎座',
    mbti: 'ENTP',
    isVerified: false,
  ),
  MatchProfile(
    id: 'div_3',
    name: '苍月',
    age: 24,
    occupation: '线下桌游 DM',
    distanceKm: 4,
    tagline: '剧本杀/密室皆可，车稳不鸽。',
    tag: '陪玩',
    typeEmoji: '🎮',
    imageUrl: 'https://picsum.photos/seed/div3/800/1200',
    rating: 5.0,
    reviews: 210,
    location: '杭州',
    price: 90,
    tags: const ['剧本杀', '桌游', '密室'],
    isDiversityPick: true,
    gender: '男',
    heightCm: 175,
    zodiac: '双子座',
    mbti: 'ENFP',
    isVerified: true,
  ),
];

MatchProfile pickDiverseProfile(Set<String> recentTags) {
  return matchDiversityPool.firstWhere(
    (p) => p.tags.every((t) => !recentTags.contains(t)),
    orElse: () =>
        matchDiversityPool[math.Random().nextInt(matchDiversityPool.length)],
  );
}
