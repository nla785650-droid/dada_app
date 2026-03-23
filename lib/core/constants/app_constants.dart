class AppConstants {
  AppConstants._();

  // Supabase 配置
  // 方式 1：编译时 --dart-define=SUPABASE_URL=xxx --dart-define=SUPABASE_ANON_KEY=xxx
  // 方式 2：替换 defaultValue 为真实值
  static const supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: 'YOUR_SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'YOUR_SUPABASE_ANON_KEY',
  );

  static bool get isSupabaseConfigured =>
      !supabaseUrl.startsWith('YOUR_') && !supabaseAnonKey.startsWith('YOUR_');

  // 应用信息
  static const appName = '搭哒';
  static const appVersion = '1.0.0';

  // 分页
  static const pageSize = 20;

  // 服务分类
  static const categories = [
    CategoryItem(id: 'all', label: '全部', emoji: '✨'),
    CategoryItem(id: 'cosplay', label: 'Cosplay', emoji: '🎭'),
    CategoryItem(id: 'photo', label: '摄影陪拍', emoji: '📸'),
    CategoryItem(id: 'game', label: '社交陪玩', emoji: '🎮'),
    CategoryItem(id: 'other', label: '其他', emoji: '🌟'),
  ];
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.label,
    required this.emoji,
  });

  final String id;
  final String label;
  final String emoji;
}
