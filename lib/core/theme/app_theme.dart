import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// The visual language for SecureMessenger: deep indigo communicates trust,
/// cyan adds a lively, optimistic accent, and warm surfaces keep long sessions
/// comfortable. All screens consume these tokens through ThemeData.
class AppTheme {
  static const Color primaryColor = Color(0xFF4659D9);
  static const Color secondaryColor = Color(0xFF13B8B0);
  static const Color accentColor = Color(0xFFFFB45C);
  static const Color lightCanvas = Color(0xFFF6F7FC);
  static const Color darkCanvas = Color(0xFF0D1120);

  static ThemeData get lightTheme => _theme(Brightness.light);
  static ThemeData get darkTheme => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      primary: dark ? const Color(0xFF93A0FF) : primaryColor,
      secondary: dark ? const Color(0xFF62DDD4) : secondaryColor,
      surface: dark ? const Color(0xFF171D31) : Colors.white,
    );
    final text = TextTheme(
      displayLarge: const TextStyle(fontFamily: 'Vazirmatn'),
      displayMedium: const TextStyle(fontFamily: 'Vazirmatn'),
      displaySmall: const TextStyle(fontFamily: 'Vazirmatn'),
      headlineLarge: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700),
      headlineMedium: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700),
      headlineSmall: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700),
      titleLarge: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w600),
      titleSmall: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w600),
      bodyLarge: const TextStyle(fontFamily: 'Vazirmatn'),
      bodyMedium: const TextStyle(fontFamily: 'Vazirmatn'),
      bodySmall: const TextStyle(fontFamily: 'Vazirmatn'),
      labelLarge: const TextStyle(fontFamily: 'Vazirmatn', fontWeight: FontWeight.w600),
      labelMedium: const TextStyle(fontFamily: 'Vazirmatn'),
      labelSmall: const TextStyle(fontFamily: 'Vazirmatn'),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: dark ? darkCanvas : lightCanvas,
      fontFamily: 'Vazirmatn',
      textTheme: text,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: dark ? darkCanvas : lightCanvas,
        foregroundColor: dark ? Colors.white : const Color(0xFF171B32),
        titleTextStyle: TextStyle(fontFamily: 'Vazirmatn', fontSize: 22, fontWeight: FontWeight.w800, color: dark ? Colors.white : const Color(0xFF171B32)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF171D31) : Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF171D31) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        hintStyle: TextStyle(color: dark ? Colors.white54 : const Color(0xFF8A90A6)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary, foregroundColor: Colors.white,
        elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )),
      floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: scheme.primary, foregroundColor: Colors.white, elevation: 5, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
      navigationBarTheme: NavigationBarThemeData(
        height: 72, elevation: 0, backgroundColor: dark ? const Color(0xFF12172A) : Colors.white,
        indicatorColor: scheme.primary.withValues(alpha: .14),
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant.withValues(alpha: .35), thickness: 1, space: 1),
    );
  }
}
