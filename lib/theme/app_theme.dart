import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const bg = Color(0xFF0B0B0F);
  static const surface = Color(0xFF13131A);
  static const surface2 = Color(0xFF16161D);
  static const border = Color(0xFF1E1E26);
  static const border2 = Color(0xFF2A2A35);
  static const accent = Color(0xFF8B7BFF);
  static const accentLight = Color(0xFFB3A8FF);
  static const accentBg = Color(0x248B7BFF);
  static const textPrimary = Color(0xFFEDEDF2);
  static const textSecondary = Color(0xFF8A8A99);
  static const textMuted = Color(0xFF6E6E7C);
  static const textDim = Color(0xFFC8C8D2);
  static const navBg = Color(0xFF0E0E13);
  static const danger = Color(0xFFFF6B7A);
}

class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
        textTheme: GoogleFonts.notoSansKrTextTheme(
          const TextTheme(
            bodyMedium: TextStyle(color: AppColors.textPrimary),
          ),
        ),
        dividerColor: AppColors.border,
        useMaterial3: true,
      );

  static TextStyle mono(double size, FontWeight weight, Color color) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color);
}
