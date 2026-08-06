import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color background = Color(0xFF0A0E21);
  static const Color surface = Color(0xFF141832);
  static const Color surfaceDark = Color(0xFF0F1226);
  static const Color neonCyan = Color(0xFF00E5FF);
  static const Color neonPurple = Color(0xFFD500F9);
  static const Color neonGreen = Color(0xFF00E676);
  static const Color errorRed = Color(0xFFFF1744);
  static const Color textPrimary = Color(0xFFE0E0E0);
  static const Color textSecondary = Color(0xFF90A4AE);

  static ThemeData get darkCyberTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: neonCyan,
      colorScheme: ColorScheme.dark(
        primary: neonCyan,
        secondary: neonPurple,
        surface: surface,
        onSurface: textPrimary,
        error: errorRed,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onError: Colors.white,
      ),
      textTheme: GoogleFonts.rajdhaniTextTheme(
        ThemeData.dark().textTheme,
      ).apply(
        bodyColor: textPrimary,
        displayColor: neonCyan,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.orbitron(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: neonCyan,
          letterSpacing: 2,
        ),
        iconTheme: const IconThemeData(color: neonCyan),
      ),
      cardTheme: CardThemeData(
        color: Colors.white.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: neonCyan.withOpacity(0.2), width: 1),
        ),
        elevation: 0,
      ),
    );
  }
}