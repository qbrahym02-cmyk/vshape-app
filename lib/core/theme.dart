import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colour system of the app: deep navy night + cyan (water) + orange (food).
class C {
  static const bg = Color(0xFF0B1020);
  static const surface = Color(0xFF141A2E);
  static const surface2 = Color(0xFF1C2440);
  static const border = Color(0xFF26304F);

  static const cyan = Color(0xFF22D3EE);
  static const blue = Color(0xFF3B82F6);
  static const orange = Color(0xFFF97316);
  static const amber = Color(0xFFFBBF24);
  static const green = Color(0xFF34D399);
  static const red = Color(0xFFF87171);
  static const violet = Color(0xFFA78BFA);

  static const lightBg = Color(0xFFF4F6FB);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder = Color(0xFFE2E7F2);
  static const lightText = Color(0xFF10162B);
}

const String kFont = 'Cairo';

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme(
    brightness: b,
    primary: dark ? C.cyan : const Color(0xFF0E7490),
    onPrimary: dark ? const Color(0xFF04212A) : Colors.white,
    secondary: C.orange,
    onSecondary: const Color(0xFF2B1200),
    surface: dark ? C.surface : C.lightSurface,
    onSurface: dark ? const Color(0xFFE8ECF8) : C.lightText,
    error: C.red,
    onError: const Color(0xFF3B0707),
    outline: dark ? C.border : C.lightBorder,
  );

  final textTheme = _baseText(dark).apply(fontFamily: kFont, bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? C.bg : C.lightBg,
    canvasColor: dark ? C.bg : C.lightBg,
    fontFamily: kFont,
    textTheme: textTheme,
    primaryTextTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? C.bg : C.lightBg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: dark ? C.surface : C.lightSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: dark ? C.border : C.lightBorder),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xFF0E1428) : C.lightSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: (dark ? C.cyan : const Color(0xFF0E7490)).withValues(alpha: 0.18),
      elevation: 0,
      height: 66,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontFamily: kFont, fontSize: 12, fontWeight: FontWeight.w700),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: dark ? C.border : C.lightBorder),
        textStyle: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        textStyle: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? C.surface2 : const Color(0xFFEAF1FB),
      side: BorderSide(color: dark ? C.border : C.lightBorder),
      labelStyle: TextStyle(fontFamily: kFont, fontWeight: FontWeight.w700, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? C.surface2 : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? C.border : C.lightBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? C.border : C.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: dark ? C.cyan : const Color(0xFF0E7490), width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? C.surface2 : const Color(0xFF1D2740),
      contentTextStyle: TextStyle(fontFamily: kFont, color: Colors.white, fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? C.surface : C.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? C.surface : C.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
    ),
    dividerColor: dark ? C.border : C.lightBorder,
    progressIndicatorTheme: ProgressIndicatorThemeData(color: dark ? C.cyan : const Color(0xFF0E7490)),
    listTileTheme: ListTileThemeData(
      iconColor: dark ? const Color(0xFF9AA6C7) : const Color(0xFF5A6785),
    ),
  );
}

TextTheme _baseText(bool dark) {
  final c = dark ? const Color(0xFFE8ECF8) : C.lightText;
  final m = dark ? const Color(0xFF9AA6C7) : const Color(0xFF5A6785);
  return TextTheme(
    displaySmall: TextStyle(color: c, fontWeight: FontWeight.w800),
    headlineMedium: TextStyle(color: c, fontWeight: FontWeight.w800),
    headlineSmall: TextStyle(color: c, fontWeight: FontWeight.w800),
    titleLarge: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 21),
    titleMedium: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 16),
    titleSmall: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 14),
    bodyLarge: TextStyle(color: c, fontSize: 15, height: 1.6),
    bodyMedium: TextStyle(color: c, fontSize: 13.5, height: 1.55),
    bodySmall: TextStyle(color: m, fontSize: 12, height: 1.5),
    labelLarge: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13),
    labelMedium: TextStyle(color: m, fontWeight: FontWeight.w600, fontSize: 12),
    labelSmall: TextStyle(color: m, fontWeight: FontWeight.w600, fontSize: 11),
  );
}

/// Section accent colours reused across screens.
class Accents {
  static Color forCategory(String c) {
    switch (c) {
      case 'water':
        return C.cyan;
      case 'food':
        return C.orange;
      case 'workout':
        return C.violet;
      case 'sleep':
        return C.blue;
      case 'study':
        return C.amber;
      default:
        return C.green;
    }
  }
}
