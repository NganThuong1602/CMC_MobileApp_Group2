import 'package:flutter/material.dart';

/// Hệ thống Design System chuẩn Pixel-perfect theo bộ 10 màn hình UI BarberSmart:
/// - Primary: #00A859 (Xanh lá chủ đạo)
/// - Background: #FFFFFF (Card/Nav) & #F5F5F5 (Nền app)
/// - Text: #333333 (Chính) & #888888 (Phụ)
class AppTheme {
  AppTheme._();

  static const Color primaryGreen = Color(0xFF00A859);
  static const Color primaryGreenLight = Color(0xFFE6F6EE);
  static const Color scaffoldBg = Color(0xFFF5F5F5);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color inputFill = Color(0xFFF3F5F8);
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF888888);
  static const Color dangerRed = Color(0xFFD32F2F);

  // Giữ alias tương thích cho các widget cũ nếu có tham chiếu
  static const Color primaryGold = primaryGreen;
  static const Color darkCharcoal = primaryGreen;
  static const Color accentAmber = primaryGreen;

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: primaryGreen,
      surface: surfaceWhite,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceWhite,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE8ECF2), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;

  static List<BoxShadow> get softCardShadow => const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];
}
