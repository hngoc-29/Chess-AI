import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/colors.dart';
import 'dark_theme.dart';
import 'light_theme.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme => _buildLightTheme();
  static ThemeData get darkTheme => _buildDarkTheme();

  static ThemeData _buildLightTheme() {
    final baseTheme = ThemeData.light();
    final textTheme = _buildTextTheme(baseTheme.textTheme, isLight: true);

    return baseTheme.copyWith(
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surfaceLight,
        error: AppColors.error,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceLight,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceLight,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryLight,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.textSecondaryLight,
        thickness: 1,
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    final baseTheme = ThemeData.dark();
    final textTheme = _buildTextTheme(baseTheme.textTheme, isLight: false);

    return baseTheme.copyWith(
      primaryColor: AppColors.primaryLight,
      scaffoldBackgroundColor: AppColors.backgroundDark,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryLight,
        secondary: AppColors.secondaryLight,
        surface: AppColors.surfaceDark,
        error: AppColors.error,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textPrimaryDark,
        elevation: 0,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceDark,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryLight,
          foregroundColor: Colors.black,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textPrimaryDark,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.textSecondaryDark,
        thickness: 1,
      ),
    );
  }

  static TextTheme _buildTextTheme(TextTheme base, {required bool isLight}) {
    final color = isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark;
    final secondaryColor = isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark;

    return GoogleFonts.robotoTextTheme(base).copyWith(
      displayLarge: GoogleFonts.roboto(fontSize: 32, fontWeight: FontWeight.bold, color: color),
      displayMedium: GoogleFonts.roboto(fontSize: 28, fontWeight: FontWeight.bold, color: color),
      displaySmall: GoogleFonts.roboto(fontSize: 24, fontWeight: FontWeight.bold, color: color),
      headlineLarge: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.w600, color: color),
      headlineMedium: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w600, color: color),
      headlineSmall: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w600, color: color),
      titleLarge: GoogleFonts.roboto(fontSize: 20, fontWeight: FontWeight.w500, color: color),
      titleMedium: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.w500, color: color),
      titleSmall: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: color),
      bodyLarge: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.normal, color: color),
      bodyMedium: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.normal, color: color),
      bodySmall: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.normal, color: secondaryColor),
      labelLarge: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.w500, color: color),
      labelMedium: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.w500, color: color),
      labelSmall: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.w500, color: secondaryColor),
    );
  }
}
