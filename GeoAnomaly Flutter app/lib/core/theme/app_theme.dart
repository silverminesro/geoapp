import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ✅ Main colors
  static const Color primaryColor = Color(0xFF00BCD4);
  static const Color secondaryColor = Color(0xFF4CAF50);
  static const Color backgroundColor = Color(0xFF0D1B2A);
  static const Color cardColor = Color(0xFF1B263B);
  static const Color borderColor = Color(0xFF415A77);
  static const Color textColor = Color(0xFFE0E1DD);
  static const Color textSecondaryColor = Color(0xFF778DA9);

  // ✅ Dark theme (hlavný theme)
  static ThemeData get theme => ThemeData(
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          secondary: secondaryColor,
          surface: cardColor,
          background: backgroundColor,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: textColor,
          onBackground: textColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: cardColor,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: borderColor, width: 1),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: BorderSide(color: primaryColor),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor),
          ),
          labelStyle: TextStyle(color: textSecondaryColor),
          hintStyle: TextStyle(color: textSecondaryColor),
        ),
        textTheme: GoogleFonts.interTextTheme().copyWith(
          bodyLarge: TextStyle(color: textColor),
          bodyMedium: TextStyle(color: textColor),
          bodySmall: TextStyle(color: textSecondaryColor),
          titleLarge: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: textColor, fontWeight: FontWeight.w600),
          titleSmall:
              TextStyle(color: textSecondaryColor, fontWeight: FontWeight.w500),
        ),
      );
}

// ✅ Game-specific text styles
class GameTextStyles {
  static TextStyle get clockTime => GoogleFonts.orbitron(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryColor,
      );

  static TextStyle get clockLabel => GoogleFonts.inter(
        fontSize: 12,
        color: AppTheme.textSecondaryColor,
      );

  static TextStyle get cardTitle => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: AppTheme.textColor,
      );

  static TextStyle get cardSubtitle => GoogleFonts.inter(
        fontSize: 14,
        color: AppTheme.textSecondaryColor,
      );

  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      );

  static TextStyle get header => GoogleFonts.orbitron(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppTheme.textColor,
      );

  static TextStyle get subheader => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppTheme.textColor,
      );
}
