import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // 品牌色：极简银灰 + 渐变紫粉
  static const Color primary = Color(0xFF9B59B6);
  static const Color primaryLight = Color(0xFFBB8FCE);
  static const Color accent = Color(0xFFFF6B9D);
  static const Color accentLight = Color(0xFFFF9BBD);

  // 中性色
  static const Color surface = Color(0xFFF8F8FA);
  static const Color surfaceVariant = Color(0xFFEEEEF4);
  static const Color onSurface = Color(0xFF1A1A2E);
  static const Color onSurfaceVariant = Color(0xFF6B6B8A);
  static const Color divider = Color(0xFFE8E8F0);

  // 毛玻璃底色
  static const Color glassBg = Color(0xCCFFFFFF);
  static const Color glassBorder = Color(0x40FFFFFF);

  // 功能色
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);

  // 渐变
  static const Gradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );

  static const Gradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC000000)],
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        surface: surface,
        onSurface: onSurface,
        primary: primary,
        secondary: accent,
      ),
      textTheme: GoogleFonts.notoSansScTextTheme(
        const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: onSurface,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: onSurface),
          bodyMedium: TextStyle(fontSize: 14, color: onSurfaceVariant),
          labelLarge: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: onSurface,
          ),
        ),
      ),
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.notoSansSc(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        iconTheme: const IconThemeData(color: onSurface),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedItemColor: primary,
        unselectedItemColor: onSurfaceVariant,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
