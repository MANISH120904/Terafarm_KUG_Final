import 'package:flutter/material.dart';

/// Shared TeraFarm brand tokens.
class TeraFarmColors {
  static const primaryDark = Color(0xFF1E633A);
  static const primary = Color(0xFF246B40);
  static const primaryMid = Color(0xFF2E8B57);
  static const accent = Color(0xFF22C55E);
  static const farmerGreen = Color(0xFF16A34A);
  static const farmerGreenDark = Color(0xFF15803D);
  static const olive = Color(0xFF407944);
  static const oliveDark = Color(0xFF2F5A32);
  static const surface = Color(0xFFF8F9FA);
  static const sageLight = Color(0xFFF5F7F3);
  static const sage = Color(0xFFECF1E8);

  static const gradientSecondary = [primary, primaryMid];
  static const gradientAccent = [accent, farmerGreen];
  static const gradientNav = [olive, oliveDark];
}

class TeraFarmTheme {
  static ThemeData light() {
    final base = ColorScheme.fromSeed(
      seedColor: TeraFarmColors.primary,
      primary: TeraFarmColors.primary,
      secondary: TeraFarmColors.accent,
      surface: TeraFarmColors.surface,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: TeraFarmColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: TeraFarmColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: TeraFarmColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: TeraFarmColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: TeraFarmColors.primary,
        foregroundColor: Colors.white,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: TeraFarmColors.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: TeraFarmColors.sage,
        selectedColor: TeraFarmColors.accent.withOpacity(0.25),
        labelStyle: const TextStyle(color: Colors.black87),
        side: BorderSide(color: Colors.grey.shade300),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: TeraFarmColors.primary,
        textColor: TeraFarmColors.primaryDark,
        collapsedIconColor: TeraFarmColors.primary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: TeraFarmColors.primary,
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade300),
    );
  }
}
