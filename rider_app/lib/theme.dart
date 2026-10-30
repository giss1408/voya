import 'package:flutter/material.dart';

/// Voya palette, matching the web prototypes (warm paper + route-ochre accent).
class VoyaColors {
  static const bg = Color(0xFFFBF4E8);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2B2117);
  static const inkSoft = Color(0xFF6B5D4D);
  static const line = Color(0xFFE3D5BC);
  static const ochre = Color(0xFFC96A2E);
  static const indigo = Color(0xFF2C4356);
  static const gold = Color(0xFFD9A441);
  static const good = Color(0xFF3E7D52);
  static const warn = Color(0xFFB4552C);
  static const crit = Color(0xFF9B3B3B);
}

ThemeData voyaTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: VoyaColors.ochre,
      brightness: Brightness.light,
      surface: VoyaColors.surface,
    ),
    scaffoldBackgroundColor: VoyaColors.bg,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: VoyaColors.bg,
      foregroundColor: VoyaColors.ink,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: VoyaColors.ink,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VoyaColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VoyaColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VoyaColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: VoyaColors.ochre, width: 1.4),
      ),
      labelStyle: const TextStyle(color: VoyaColors.inkSoft),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VoyaColors.ochre,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VoyaColors.ink,
        side: const BorderSide(color: VoyaColors.line),
        minimumSize: const Size.fromHeight(46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    cardTheme: CardTheme(
      color: VoyaColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: VoyaColors.line),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerColor: VoyaColors.line,
  );
}
