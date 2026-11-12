import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../enums/app_enums.dart';

/// Biểu tượng đại diện riêng cho từng Role trên góc Avatar và Trang cá nhân:
/// - USER (Khách hàng): `Icons.person_rounded`
/// - BARBER (Thợ cắt tóc): `Icons.content_cut_rounded` (Cây kéo)
/// - MANAGER (Chủ tiệm / Quản lý quán): `Icons.storefront_rounded` (Cửa tiệm)
/// - ADMIN (Quản trị viên): `Icons.admin_panel_settings_rounded` (Khiên Admin)
extension UserRoleBadgeX on UserRole {
  IconData get roleIcon {
    switch (this) {
      case UserRole.user:
        return Icons.person_rounded;
      case UserRole.barber:
        return Icons.content_cut_rounded;
      case UserRole.manager:
        return Icons.storefront_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
    }
  }
}

/// Extension quản lý các màu trạng thái phụ trợ & đổ bóng tập trung trong [AppTheme].
@immutable
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color starRating;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;
  final Color bannerOverlayTop;
  final Color bannerOverlayBottom;
  final Color translucentSurface;
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> primaryGlowShadow;
  final List<BoxShadow> primaryStrongGlowShadow;

  const AppColorsExtension({
    required this.starRating,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
    required this.bannerOverlayTop,
    required this.bannerOverlayBottom,
    required this.translucentSurface,
    required this.cardShadow,
    required this.primaryGlowShadow,
    required this.primaryStrongGlowShadow,
  });

  @override
  AppColorsExtension copyWith({
    Color? starRating,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
    Color? bannerOverlayTop,
    Color? bannerOverlayBottom,
    Color? translucentSurface,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? primaryGlowShadow,
    List<BoxShadow>? primaryStrongGlowShadow,
  }) {
    return AppColorsExtension(
      starRating: starRating ?? this.starRating,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
      bannerOverlayTop: bannerOverlayTop ?? this.bannerOverlayTop,
      bannerOverlayBottom: bannerOverlayBottom ?? this.bannerOverlayBottom,
      translucentSurface: translucentSurface ?? this.translucentSurface,
      cardShadow: cardShadow ?? this.cardShadow,
      primaryGlowShadow: primaryGlowShadow ?? this.primaryGlowShadow,
      primaryStrongGlowShadow:
          primaryStrongGlowShadow ?? this.primaryStrongGlowShadow,
    );
  }

  @override
  AppColorsExtension lerp(
    covariant ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      starRating: Color.lerp(starRating, other.starRating, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
      bannerOverlayTop:
          Color.lerp(bannerOverlayTop, other.bannerOverlayTop, t)!,
      bannerOverlayBottom:
          Color.lerp(bannerOverlayBottom, other.bannerOverlayBottom, t)!,
      translucentSurface:
          Color.lerp(translucentSurface, other.translucentSurface, t)!,
      cardShadow: other.cardShadow,
      primaryGlowShadow: other.primaryGlowShadow,
      primaryStrongGlowShadow: other.primaryStrongGlowShadow,
    );
  }
}

/// Hệ thống Typography ngữ nghĩa kế thừa hoàn toàn từ [TextTheme] (Font Inter) và [ColorScheme].
/// Khi thay đổi font, kích thước chuẩn hoặc bảng màu tại [AppTheme], toàn bộ chữ trong app tự động cập nhật.
@immutable
class AppTextStyles {
  final ThemeData _theme;

  const AppTextStyles(this._theme);

  TextTheme get _tt => _theme.textTheme;
  ColorScheme get _cs => _theme.colorScheme;
  AppColorsExtension get _ext => _theme.extension<AppColorsExtension>()!;

  // Brand & Display
  TextStyle get brandLogo => _tt.headlineMedium!.copyWith(
        color: _cs.primary,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.8,
      );

  TextStyle get headerBrand => _tt.titleLarge!.copyWith(
        color: _cs.primary,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.6,
      );

  TextStyle get heroPriceOnPrimary => _tt.headlineMedium!.copyWith(
        color: _cs.onPrimary,
        fontWeight: FontWeight.w900,
      );

  // Headlines & Titles
  TextStyle get pageTitle => _tt.titleLarge!.copyWith(
        color: _cs.onSurface,
        fontWeight: FontWeight.w800,
      );

  TextStyle get dialogTitle => _tt.titleMedium!.copyWith(
        color: _cs.onSurface,
        fontWeight: FontWeight.w800,
      );

  TextStyle get sectionTitle => _tt.titleSmall!.copyWith(
        color: _cs.onSurface,
        fontWeight: FontWeight.w800,
      );

  TextStyle get sectionTitlePrimary => _tt.titleSmall!.copyWith(
        color: _cs.primary,
        fontWeight: FontWeight.w800,
      );

  TextStyle get cardTitleLarge => _tt.titleMedium!.copyWith(
        color: _cs.onSurface,
        fontWeight: FontWeight.w800,
      );

  TextStyle get cardTitle => _tt.titleSmall!.copyWith(
        color: _cs.onSurface,
        fontWeight: FontWeight.w700,
      );

  TextStyle get cardTitleOnInverse => _tt.titleMedium!.copyWith(
        color: _cs.onInverseSurface,
        fontWeight: FontWeight.w800,
      );

  TextStyle get bannerOverlayTitle => _tt.titleMedium!.copyWith(
        color: _cs.onInverseSurface,
        fontWeight: FontWeight.w800,
        shadows: [
          Shadow(
            color: _cs.scrim,
            blurRadius: 6,
          ),
        ],
      );

  TextStyle get underlineLinkPrimary => _tt.bodySmall!.copyWith(
        color: _cs.primary,
        fontWeight: FontWeight.w700,
        decoration: TextDecoration.underline,
      );

  TextStyle get priceLargePrimary => _tt.titleLarge!.copyWith(
        color: _cs.primary,
        fontWeight: FontWeight.w900,
      );

  TextStyle get pricePrimary => _tt.titleSmall!.copyWith(
        color: _cs.primary,
        fontWeight: FontWeight.w800,
      );

  TextStyle get priceStrikethrough => _tt.bodySmall!.copyWith(
        color: _cs.onSurfaceVariant,
        decoration: TextDecoration.lineThrough,
      );

  // Body styles
  TextStyle get bodyStrong => _tt.bodyMedium!.copyWith(
        color: _cs.onSurface,
        fontWeight: FontWeight.w700,
      );

  TextStyle get bodyPrimary => _tt.bodyMedium!.copyWith(
        color: _cs.onSurface,
        fontWeight: FontWeight.w600,
      );

  TextStyle get bodyRegular => _tt.bodyMedium!.copyWith(
        color: _cs.onSurface,
        height: 1.45,
      );

  TextStyle get bodyOnPrimary => _tt.bodyMedium!.copyWith(
        color: _cs.onPrimary,
        height: 1.35,
      );

  TextStyle get bodyMuted => _tt.bodyMedium!.copyWith(
        color: _cs.onSurfaceVariant,
        height: 1.45,
      );

  TextStyle get bodySmallStrong => _tt.bodySmall!.copyWith(
        color: _cs.onSurface,
        fontWeight: FontWeight.w700,
      );

  TextStyle get bodySmallPrimary => _tt.bodySmall!.copyWith(
        color: _cs.primary,
        fontWeight: FontWeight.w700,
      );

  TextStyle get bodySmallDanger => _tt.bodySmall!.copyWith(
        color: _cs.error,
        fontWeight: FontWeight.w700,
      );

  TextStyle get bodySmallWarning => _tt.bodySmall!.copyWith(
        color: _ext.warning,
        fontWeight: FontWeight.w700,
      );

  TextStyle get bodySmallMuted => _tt.bodySmall!.copyWith(
        color: _cs.onSurfaceVariant,
      );

  TextStyle get bodySmallOnPrimary => _tt.bodySmall!.copyWith(
        color: _cs.onPrimary,
        fontWeight: FontWeight.w600,
      );

  TextStyle get bodySmallOnInverse => _tt.bodySmall!.copyWith(
        color: _cs.onInverseSurface,
      );

  // Labels & Badges
  TextStyle get buttonLabel => _tt.labelLarge!.copyWith(
        color: _cs.onPrimary,
        fontWeight: FontWeight.w700,
      );

  TextStyle get buttonLabelPrimary => _tt.labelLarge!.copyWith(
        color: _cs.primary,
        fontWeight: FontWeight.w700,
      );

  TextStyle get buttonLabelDanger => _tt.labelLarge!.copyWith(
        color: _cs.error,
        fontWeight: FontWeight.w700,
      );

  TextStyle get buttonLabelMuted => _tt.labelLarge!.copyWith(
        color: _cs.onSurfaceVariant,
        fontWeight: FontWeight.w700,
      );

  TextStyle get tabActive => _tt.labelSmall!.copyWith(
        color: _cs.primary,
        fontWeight: FontWeight.w700,
      );

  TextStyle get tabInactive => _tt.labelSmall!.copyWith(
        color: _cs.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      );

  TextStyle get badgePrimary => _tt.labelSmall!.copyWith(
        color: _cs.primary,
        fontWeight: FontWeight.w700,
      );

  TextStyle get badgeOnPrimary => _tt.labelSmall!.copyWith(
        color: _cs.onPrimary,
        fontWeight: FontWeight.w800,
      );

  TextStyle get badgeWarning => _tt.labelSmall!.copyWith(
        color: _ext.warning,
        fontWeight: FontWeight.w700,
      );

  TextStyle get badgeDanger => _tt.labelSmall!.copyWith(
        color: _cs.error,
        fontWeight: FontWeight.w700,
      );

  TextStyle get badgeSecondary => _tt.labelMedium!.copyWith(
        color: _cs.onSecondaryContainer,
        fontWeight: FontWeight.w600,
      );

  TextStyle get captionMuted => _tt.labelSmall!.copyWith(
        color: _cs.onSurfaceVariant,
      );

  TextStyle get captionStrong => _tt.labelSmall!.copyWith(
        color: _cs.onSurface,
        fontWeight: FontWeight.w700,
      );

  TextStyle get captionOnPrimary => _tt.labelSmall!.copyWith(
        color: _cs.onPrimary,
        fontWeight: FontWeight.w600,
      );
}

extension ThemeContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
  AppTextStyles get appTextStyles => AppTextStyles(Theme.of(this));
}

/// Điểm cấu hình Design System duy nhất của toàn bộ ứng dụng BarberSmart.
/// Muốn đổi màu chủ đạo, đổi font chữ (mặc định: Inter) hoặc chỉnh kích thước chữ chuẩn,
/// chỉ cần thay đổi thông số tại class [AppTheme] này.
class AppTheme {
  AppTheme._();

  // ==================== BẢNG MÀU TRUNG TÂM ====================
  static const Color primaryGreen = Color(0xFF00A859);
  static const Color primaryGreenLight = Color(0xFFE6F6EE);
  static const Color secondaryMint = Color(0xFF4ADE80);
  static const Color secondaryContainerBg = Color(0xFFEEF4FA);
  static const Color onSecondaryContainerText = Color(0xFF4A5568);
  static const Color tertiaryPurple = Color(0xFF6D28D9);
  static const Color tertiaryPurpleLight = Color(0xFFEDE9FE);

  static const Color scaffoldBg = Color(0xFFF5F5F5);
  static const Color authScaffoldBg = Color(0xFFF8FAFC);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color inputFill = Color(0xFFF3F5F8);
  static const Color containerHigh = Color(0xFFE9EEF5);
  static const Color containerHighest = Color(0xFFE5E7EB);

  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF888888);
  static const Color outlineBorder = Color(0xFFDCE3EC);
  static const Color dividerBorder = Color(0xFFEEEEEE);

  static const Color dangerRed = Color(0xFFD32F2F);
  static const Color dangerRedLight = Color(0xFFFEE2E2);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color warningAmberLight = Color(0xFFFFF4E5);
  static const Color starGold = Color(0xFFFFB300);
  static const Color infoBlue = Color(0xFF2563EB);
  static const Color infoBlueLight = Color(0xFFDBEAFE);

  static const Color inverseDarkSurface = Color(0xFF1F2937);
  static const Color scrimOverlay = Color(0x73000000);
  static const Color shadowColor = Color(0x0D000000);
  static const Color transparent = Colors.transparent;

  // Alias tương thích ngược
  static const Color primaryGold = primaryGreen;
  static const Color darkCharcoal = primaryGreen;
  static const Color accentAmber = primaryGreen;

  // ==================== CẤU HÌNH KÍCH THƯỚC CHỮ CHUẨN ====================
  static const double fontSizeDisplay = 26.0;
  static const double fontSizeHeadline = 22.0;
  static const double fontSizeTitleLarge = 19.0;
  static const double fontSizeTitleMedium = 16.5;
  static const double fontSizeTitleSmall = 15.0;
  static const double fontSizeBodyLarge = 14.5;
  static const double fontSizeBodyMedium = 13.5;
  static const double fontSizeBodySmall = 12.5;
  static const double fontSizeLabelLarge = 14.0;
  static const double fontSizeLabelMedium = 12.0;
  static const double fontSizeLabelSmall = 11.0;

  static List<BoxShadow> get softCardShadow => const [
        BoxShadow(
          color: shadowColor,
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ];

  static TextTheme _buildInterTextTheme(ColorScheme cs) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 30,
        fontWeight: FontWeight.w900,
        color: cs.onSurface,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        color: cs.onSurface,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: fontSizeDisplay,
        fontWeight: FontWeight.w900,
        color: cs.onSurface,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: fontSizeHeadline,
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: fontSizeTitleLarge,
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: fontSizeTitleMedium,
        fontWeight: FontWeight.w800,
        color: cs.onSurface,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: fontSizeTitleSmall,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: fontSizeBodyLarge,
        fontWeight: FontWeight.w600,
        color: cs.onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: fontSizeBodyMedium,
        fontWeight: FontWeight.w500,
        color: cs.onSurface,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: fontSizeBodySmall,
        fontWeight: FontWeight.w500,
        color: cs.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: fontSizeLabelLarge,
        fontWeight: FontWeight.w700,
        color: cs.onSurface,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: fontSizeLabelMedium,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: fontSizeLabelSmall,
        fontWeight: FontWeight.w600,
        color: cs.onSurfaceVariant,
      ),
    );
  }

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: primaryGreen,
      onPrimary: surfaceWhite,
      primaryContainer: primaryGreenLight,
      onPrimaryContainer: primaryGreen,
      secondary: secondaryMint,
      onSecondary: inverseDarkSurface,
      secondaryContainer: secondaryContainerBg,
      onSecondaryContainer: onSecondaryContainerText,
      tertiary: tertiaryPurple,
      onTertiary: surfaceWhite,
      tertiaryContainer: tertiaryPurpleLight,
      onTertiaryContainer: tertiaryPurple,
      error: dangerRed,
      onError: surfaceWhite,
      errorContainer: dangerRedLight,
      onErrorContainer: dangerRed,
      surface: surfaceWhite,
      onSurface: textPrimary,
      onSurfaceVariant: textSecondary,
      surfaceContainerLowest: authScaffoldBg,
      surfaceContainerLow: scaffoldBg,
      surfaceContainer: inputFill,
      surfaceContainerHigh: containerHigh,
      surfaceContainerHighest: containerHighest,
      outline: outlineBorder,
      outlineVariant: dividerBorder,
      shadow: shadowColor,
      scrim: scrimOverlay,
      inverseSurface: inverseDarkSurface,
      onInverseSurface: surfaceWhite,
    );

    final textTheme = _buildInterTextTheme(colorScheme);
    final defaultFontFamily = GoogleFonts.inter().fontFamily;

    const appColorsExt = AppColorsExtension(
      starRating: starGold,
      warning: warningAmber,
      warningContainer: warningAmberLight,
      info: infoBlue,
      infoContainer: infoBlueLight,
      bannerOverlayTop: Color(0x14000000),
      bannerOverlayBottom: Color(0xC7000000),
      translucentSurface: Color(0xF5FFFFFF),
      cardShadow: [
        BoxShadow(
          color: shadowColor,
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
      primaryGlowShadow: [
        BoxShadow(
          color: Color(0x4000A859),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
      primaryStrongGlowShadow: [
        BoxShadow(
          color: Color(0x6B00A859),
          blurRadius: 12,
          offset: Offset(0, 4),
        ),
      ],
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surfaceContainerLow,
      fontFamily: defaultFontFamily,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      extensions: const <ThemeExtension<dynamic>>[appColorsExt],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleMedium,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surface,
        surfaceTintColor: transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: transparent,
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.primary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: colorScheme.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: colorScheme.primary,
        labelStyle: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: textTheme.labelMedium,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.primaryContainer,
        labelStyle: textTheme.labelMedium!,
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: colorScheme.primary, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainer,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
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
          borderSide: BorderSide(color: colorScheme.outline, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }

  static ThemeData get darkTheme => lightTheme;
}
