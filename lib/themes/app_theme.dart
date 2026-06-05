import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.primary,
        secondary: AppColors.accent,
        surface:   AppColors.surface,
        error:     AppColors.error,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge:  AppTextStyles.display,
        headlineLarge: AppTextStyles.heading1,
        headlineMedium:AppTextStyles.heading2,
        headlineSmall: AppTextStyles.heading3,
        bodyLarge:     AppTextStyles.bodyLarge,
        bodyMedium:    AppTextStyles.body,
        bodySmall:     AppTextStyles.bodySmall,
        labelLarge:    AppTextStyles.label,
        labelSmall:    AppTextStyles.labelSmall,
      ),

      // ── AppBar ──────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor:    AppColors.surface,
        foregroundColor:    AppColors.textPrimary,
        elevation:          0,
        scrolledUnderElevation: 0,
        centerTitle:        false,
        titleTextStyle:     AppTextStyles.heading3,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:           Colors.transparent,
          statusBarIconBrightness:  Brightness.light,
          statusBarBrightness:      Brightness.dark,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary, size: 22),
      ),

      // ── BottomNavigationBar ──────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:       AppColors.surface,
        selectedItemColor:     AppColors.primaryLight,
        unselectedItemColor:   AppColors.textMuted,
        selectedLabelStyle:    AppTextStyles.labelSmall,
        unselectedLabelStyle:  AppTextStyles.labelSmall,
        type:                  BottomNavigationBarType.fixed,
        elevation:             0,
        showSelectedLabels:    true,
        showUnselectedLabels:  true,
      ),

      // ── Card ─────────────────────────────────────────────
      cardTheme: CardThemeData(
        color:        AppColors.cardBg,
        elevation:    0,
        shape:        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderColor, width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Input ────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:        true,
        fillColor:     AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: AppColors.borderColor, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: AppColors.borderColor, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: AppColors.primary, width: 1),
        ),
        hintStyle:         AppTextStyles.body.copyWith(color: AppColors.textDisabled),
        contentPadding:    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),

      // ── ElevatedButton ───────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation:       0,
          padding:         const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape:           RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: AppTextStyles.label,
        ),
      ),

      // ── Divider ──────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color:     AppColors.divider,
        thickness: 0.5,
        space:     0,
      ),

      // ── Icon ─────────────────────────────────────────────
      iconTheme: const IconThemeData(
        color: AppColors.textSecondary,
        size:  22,
      ),
    );
  }
}