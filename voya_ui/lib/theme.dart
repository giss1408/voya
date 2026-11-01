import 'package:flutter/material.dart';

/// Voya palette (warm paper + route-ochre accent).
///
/// [ochre] is the single accent. It was #C96A2E (about 3.8:1 with white text,
/// below WCAG AA); #B35A22 gives about 4.8:1.
class VoyaColors {
  static const bg = Color(0xFFFBF4E8);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF2B2117);
  static const inkSoft = Color(0xFF6B5D4D);
  static const line = Color(0xFFE3D5BC);
  static const ochre = Color(0xFFB35A22);
  static const ochreTint = Color(0xFFFDF0E7);
  static const indigo = Color(0xFF2C4356);
  static const gold = Color(0xFFD9A441);
  static const good = Color(0xFF3E7D52);
  static const warn = Color(0xFFB4552C);
  static const crit = Color(0xFF9B3B3B);
  static const goodTint = Color(0xFFDFF0E3);
  static const warnTint = Color(0xFFF6E6D8);
  static const infoTint = Color(0xFFDDE6ED);
  static const critTint = Color(0xFFF3DEDE);
}

/// 8pt spacing scale (4 for tight pairs).
abstract final class Space {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

abstract final class Radii {
  static const sm = 8.0;
  static const md = 12.0;
}

/// Single type scale: caption 12, body 14, input 16, title 20-22, page 30+.
TextTheme _textTheme(TextTheme b) {
  TextStyle s(TextStyle? t, double size, FontWeight w, {double? height}) =>
      (t ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: w,
        height: height,
        color: VoyaColors.ink,
      );
  return b.copyWith(
    labelSmall: s(b.labelSmall, 12, FontWeight.w500),
    bodySmall: s(b.bodySmall, 12, FontWeight.w400, height: 1.5)
        .copyWith(color: VoyaColors.inkSoft),
    bodyMedium: s(b.bodyMedium, 14, FontWeight.w400, height: 1.5),
    bodyLarge: s(b.bodyLarge, 16, FontWeight.w400, height: 1.5),
    labelLarge: s(b.labelLarge, 14, FontWeight.w600),
    titleMedium: s(b.titleMedium, 16, FontWeight.w600),
    titleLarge: s(b.titleLarge, 20, FontWeight.w700),
    headlineSmall: s(b.headlineSmall, 24, FontWeight.w700),
    headlineMedium: s(b.headlineMedium, 30, FontWeight.w700),
  );
}

ThemeData voyaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: VoyaColors.ochre,
    brightness: Brightness.light,
    surface: VoyaColors.surface,
  ).copyWith(
    primary: VoyaColors.ochre,
    onPrimary: Colors.white,
    error: VoyaColors.crit,
    outline: VoyaColors.line,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: VoyaColors.bg,
  );

  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        borderSide: BorderSide(color: c, width: w),
      );
  final buttonShape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.md));

  return base.copyWith(
    textTheme: _textTheme(base.textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: VoyaColors.bg,
      foregroundColor: VoyaColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: _textTheme(base.textTheme).titleLarge,
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: VoyaColors.ochre,
      selectionHandleColor: VoyaColors.ochre,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VoyaColors.surface,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: Space.md, vertical: 14),
      border: border(VoyaColors.line),
      enabledBorder: border(VoyaColors.line),
      focusedBorder: border(VoyaColors.ochre, 2),
      errorBorder: border(VoyaColors.crit),
      focusedErrorBorder: border(VoyaColors.crit, 2),
      labelStyle: const TextStyle(color: VoyaColors.inkSoft),
      errorStyle: const TextStyle(color: VoyaColors.crit, fontSize: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VoyaColors.ochre,
        foregroundColor: Colors.white,
        disabledBackgroundColor: VoyaColors.line,
        disabledForegroundColor: VoyaColors.inkSoft,
        elevation: 0,
        minimumSize: const Size.fromHeight(52),
        shape: buttonShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: VoyaColors.ink,
        side: const BorderSide(color: VoyaColors.line),
        minimumSize: const Size.fromHeight(48),
        shape: buttonShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: VoyaColors.ochre,
        minimumSize: const Size(48, 48),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    cardTheme: CardTheme(
      color: VoyaColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: const BorderSide(color: VoyaColors.line),
      ),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: VoyaColors.surface,
      indicatorColor: VoyaColors.ochreTint,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected)
              ? VoyaColors.ochre
              : VoyaColors.inkSoft,
        ),
      ),
    ),
    dividerColor: VoyaColors.line,
  );
}
