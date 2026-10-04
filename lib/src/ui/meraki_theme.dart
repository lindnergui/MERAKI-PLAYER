import 'package:flutter/material.dart';

abstract final class MerakiColors {
  /// Core palette shared by the Linux and Android interfaces.
  static const Color deepPurple = Color(0xFF0D0814);
  static const Color playerGradientTop = Color(0xFF3D1B53);
  static const Color sidebar = Color(0xFF1B1226);
  static const Color panel = Color(0xFF1B1226);
  static const Color softText = Color(0xFFA799B7);
  static const Color defaultAccent = Color(0xFFA855F7);
  static const Color secondaryAccent = Color(0xFFC084FC);
  static const Color divider = Color(0xFF2A1B3D);
}

abstract final class MerakiFonts {
  /// Pixel typeface bundled in `assets/fonts` (Pixelify Sans, SIL OFL 1.1).
  /// Used for headings, labels and controls of the desktop interface.
  static const String pixel = 'PixelifySans';
}

/// Shared pixel-font text style for the desktop interface.
TextStyle merakiPixelStyle(
  double size, {
  Color color = Colors.white,
  FontWeight weight = FontWeight.w500,
  double? height,
  double letterSpacing = 0.4,
  TextDecoration? decoration,
}) {
  return TextStyle(
    fontFamily: MerakiFonts.pixel,
    fontSize: size,
    color: color,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    decoration: decoration,
    decorationColor: color,
  );
}

ThemeData buildMerakiTheme() {
  const accent = MerakiColors.defaultAccent;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ).copyWith(
        primary: accent,
        primaryContainer: accent,
        secondary: MerakiColors.secondaryAccent,
        secondaryContainer: MerakiColors.secondaryAccent,
        tertiary: MerakiColors.secondaryAccent,
        tertiaryContainer: MerakiColors.secondaryAccent,
        onPrimary: MerakiColors.deepPurple,
        onPrimaryContainer: MerakiColors.deepPurple,
        onSecondary: MerakiColors.deepPurple,
        onSecondaryContainer: MerakiColors.deepPurple,
        onTertiary: MerakiColors.deepPurple,
        onTertiaryContainer: MerakiColors.deepPurple,
        surface: MerakiColors.panel,
        surfaceContainer: MerakiColors.panel,
        surfaceContainerHigh: MerakiColors.panel,
        onSurface: const Color(0xFFFFFFFF),
        onSurfaceVariant: MerakiColors.softText,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: MerakiColors.deepPurple,
    cardColor: MerakiColors.panel,
    fontFamily: 'sans-serif',
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ),
    dividerColor: MerakiColors.divider,
    appBarTheme: const AppBarTheme(
      backgroundColor: MerakiColors.deepPurple,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: MerakiColors.panel,
      indicatorColor: MerakiColors.defaultAccent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: MerakiColors.panel,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: MerakiColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: accent),
      ),
    ),
    filledButtonTheme: const FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(accent),
        foregroundColor: WidgetStatePropertyAll(MerakiColors.deepPurple),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: accent,
      inactiveTrackColor: Colors.white.withValues(alpha: 0.12),
      thumbColor: accent,
      overlayColor: accent.withValues(alpha: 0.16),
    ),
  );
}
