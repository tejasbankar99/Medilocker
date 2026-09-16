import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color primary     = Color(0xFF00C9A7);
  static const Color primaryDark = Color(0xFF00A589);
  static const Color secondary   = Color(0xFF4FC3F7);
  static const Color bg          = Color(0xFF0A1628);
  static const Color surface     = Color(0xFF122036);
  static const Color card        = Color(0xFF1A2D48);
  static const Color border      = Color(0xFF263B56);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8BA0B8);
  static const Color error       = Color(0xFFFF6B6B);
  static const Color success     = Color(0xFF00C9A7);
  static const Color warning     = Color(0xFFFFB74D);

  // ── Category colours ─────────────────────────────────────────────────────
  static const Map<String, Color> categoryColors = {
    'Lab Report':      Color(0xFF00C9A7),
    'Prescription':    Color(0xFF4FC3F7),
    'Hospital Record': Color(0xFFCE93D8),
    'Doctor Note':     Color(0xFFFFB74D),
    'Vaccination':     Color(0xFF81C784),
    'Radiology':       Color(0xFFFF8A65),
    'Cardiology':      Color(0xFFF48FB1),
    'Dental':          Color(0xFFFFF176),
    'Insurance':       Color(0xFF9FA8DA),
    'Other':           Color(0xFF78909C),
  };

  static Color categoryColor(String category) =>
      categoryColors[category] ?? const Color(0xFF78909C);

  // ── Theme ─────────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: primary,
      secondary: secondary,
      surface: surface,
      error: error,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: textPrimary,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      displayLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w700),
      displayMedium: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w700),
      headlineLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w700, fontSize: 28),
      headlineMedium: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 22),
      headlineSmall: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 18),
      titleLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
      titleMedium: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w500, fontSize: 14),
      bodyLarge: GoogleFonts.inter(color: textPrimary, fontSize: 16),
      bodyMedium: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      bodySmall: GoogleFonts.inter(color: textSecondary, fontSize: 12),
      labelLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: error),
      ),
      hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GoogleFonts.inter(
        color: textPrimary, fontWeight: FontWeight.w700, fontSize: 20,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: primary,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerTheme: const DividerThemeData(color: border, thickness: 1),
    iconTheme: const IconThemeData(color: textSecondary),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: card,
      contentTextStyle: GoogleFonts.inter(color: textPrimary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
