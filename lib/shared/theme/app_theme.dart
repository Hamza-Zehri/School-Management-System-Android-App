import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Brand Colors
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryDark = Color(0xFF1239A6);
  static const Color accent = Color(0xFF10B981);
  static const Color danger = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color cardBg = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);
  static const Color paid = Color(0xFF10B981);
  static const Color unpaid = Color(0xFFEF4444);
  static const Color partial = Color(0xFFF59E0B);
  static const Color overdue = Color(0xFF7C3AED);

  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          secondary: accent,
          surface: surface,
          onPrimary: Colors.white,
        ),
        textTheme: GoogleFonts.interTextTheme().copyWith(
          displayLarge: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: textPrimary),
          headlineMedium: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary),
          titleLarge: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textPrimary),
          bodyLarge: GoogleFonts.inter(fontSize: 15, color: textPrimary),
          bodyMedium: GoogleFonts.inter(fontSize: 13, color: textSecondary),
          labelLarge: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
        scaffoldBackgroundColor: surface,
        appBarTheme: AppBarTheme(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        cardTheme: CardTheme(
          color: cardBg,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: border),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            textStyle: GoogleFonts.inter(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: primary),
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: primary, width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
          hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 13),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: cardBg,
          selectedItemColor: primary,
          unselectedItemColor: textSecondary,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle:
              GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              GoogleFonts.inter(fontSize: 11),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          labelStyle: GoogleFonts.inter(fontSize: 12),
        ),
        dividerTheme: const DividerThemeData(
          color: border,
          thickness: 1,
          space: 1,
        ),
        listTileTheme: ListTileThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
      );

  /// Status color helper
  static Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
        return paid;
      case 'unpaid':
        return unpaid;
      case 'partial':
        return partial;
      case 'overdue':
        return overdue;
      case 'present':
        return paid;
      case 'absent':
        return unpaid;
      case 'late':
        return warning;
      case 'leave':
        return info;
      default:
        return textSecondary;
    }
  }
}
