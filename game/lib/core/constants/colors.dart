import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Modern dark theme colors
  static const Color primary = Color(0xFF3B82F6); // Blue
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF60A5FA);

  static const Color secondary = Color(0xFFF59E0B); // Orange/Amber
  static const Color secondaryDark = Color(0xFFD97706);
  static const Color secondaryLight = Color(0xFFFBBF24);

  static const Color accent = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);

  // Dark theme backgrounds
  static const Color backgroundDark = Color(0xFF0F172A); // Very dark blue-gray
  static const Color backgroundLight = Color(0xFFF8FAFC);

  static const Color surfaceDark = Color(0xFF1E293B); // Dark blue-gray
  static const Color surfaceLight = Color(0xFFFFFFFF);

  static const Color cardDark = Color(0xFF334155); // Medium dark
  static const Color cardLight = Color(0xFFF1F5F9);

  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textPrimaryLight = Color(0xFF0F172A);

  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textSecondaryLight = Color(0xFF64748B);

  static const Color lightSquare = Color(0xFFF0D9B5);
  static const Color darkSquare = Color(0xFFB58863);

  static const Color highlightMove = Color(0x8000FF00);
  static const Color highlightSelected = Color(0x80FFFF00);
  static const Color highlightLegal = Color(0x4000FF00);
  static const Color highlightCheck = Color(0x80FF0000);
  static const Color highlightLastMove = Color(0x60FFFF00);

  static final Map<String, BoardColors> boardThemes = {
    'brown': BoardColors(
      lightSquare: const Color(0xFFF0D9B5),
      darkSquare: const Color(0xFFB58863),
    ),
    'blue': BoardColors(
      lightSquare: const Color(0xFFDEE3E6),
      darkSquare: const Color(0xFF8CA2AD),
    ),
    'green': BoardColors(
      lightSquare: const Color(0xFFFFFFDD),
      darkSquare: const Color(0xFF86A666),
    ),
    'purple': BoardColors(
      lightSquare: const Color(0xFFE8E9B7),
      darkSquare: const Color(0xFF9F90B0),
    ),
    'wood': BoardColors(
      lightSquare: const Color(0xFFD5A574),
      darkSquare: const Color(0xFF946F51),
    ),
    'dark': BoardColors(
      lightSquare: const Color(0xFF5A5A5A),
      darkSquare: const Color(0xFF3A3A3A),
    ),
  };
}

class BoardColors {
  final Color lightSquare;
  final Color darkSquare;

  const BoardColors({
    required this.lightSquare,
    required this.darkSquare,
  });
}
