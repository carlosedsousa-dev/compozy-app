import 'package:material_ui/material_ui.dart';

/// Canonical CompozyOS Design System color tokens.
/// Neutral, chroma-free dark palette, inverted primary actions,
/// and semantic signal palette (aligned with ds-core.css / shell v2).
class CompozyColors {
  const CompozyColors._();

  // Surfaces
  static const Color rail = Color(0xFF0A0A0A);
  static const Color desk = Color(0xFF101010);
  static const Color canvas = Color(0xFF1A1A1A);
  static const Color canvasSoft = Color(0xFF1F1F1F);
  static const Color surface2 = Color(0xFF242424);
  static const Color elevated = Color(0xFF2B2B2B);

  // Lines & Borders
  static const Color line = Color(0xFF303030);
  static const Color lineSoft = Color(0xFF262626);
  static const Color lineStrong = Color(0xFF424242);

  // Typography & Text Ladder
  static const Color fgStrong = Color(0xFFFFFFFF);
  static const Color fg = Color(0xFFF5F5F5);
  static const Color muted = Color(0xFFA3A3A3);
  static const Color subtle = Color(0xFF8E8E8E);

  // Actions & Accents
  // The primary action is strictly an inverted pill (solid bright background with dark text)
  static const Color primary = Color(0xFFF5F5F5);
  static const Color primaryInk = Color(0xFF0A0A0A);
  // Accent is reserved strictly for highlight and attention
  static const Color accent = Color(0xFFE8572A);

  // Semantic Signal Palette (Status)
  static const Color success = Color(0xFF34D399); // Mint (Active sessions, healthy)
  static const Color warning = Color(0xFFF5B14C); // Amber (Waiting/busy, degraded)
  static const Color danger = Color(0xFFF87171);  // Rose/Red (Stopped, failed, disconnected)
  static const Color info = Color(0xFF8E8EB5);    // Slate/Violet (Agent badges, loop categories)
}

/// Canonical CompozyOS Geometry & Radius tokens.
class CompozyRadius {
  const CompozyRadius._();

  static const double radius = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusPill = 9999.0;

  static const BorderRadius input = BorderRadius.all(Radius.circular(radius));
  static const BorderRadius card = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(radiusPill));
}

/// CompozyOS Application Theme configuration.
class CompozyTheme {
  const CompozyTheme._();

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: CompozyColors.desk,
      canvasColor: CompozyColors.canvas,
      colorScheme: const ColorScheme.dark(
        surface: CompozyColors.canvas,
        onSurface: CompozyColors.fg,
        primary: CompozyColors.primary,
        onPrimary: CompozyColors.primaryInk,
        secondary: CompozyColors.surface2,
        onSecondary: CompozyColors.fg,
        error: CompozyColors.danger,
        onError: CompozyColors.fgStrong,
        outline: CompozyColors.line,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: CompozyColors.rail,
        foregroundColor: CompozyColors.fgStrong,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: CompozyColors.fgStrong,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      cardTheme: CardThemeData(
        color: CompozyColors.canvas,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: CompozyRadius.card,
          side: const BorderSide(color: CompozyColors.line, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CompozyColors.rail,
        selectedItemColor: CompozyColors.fg,
        unselectedItemColor: CompozyColors.muted,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: CompozyColors.rail,
        selectedIconTheme: IconThemeData(color: CompozyColors.fg),
        unselectedIconTheme: IconThemeData(color: CompozyColors.muted),
        selectedLabelTextStyle: TextStyle(
          color: CompozyColors.fg,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: CompozyColors.muted,
          fontSize: 12,
        ),
        indicatorColor: CompozyColors.elevated,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CompozyColors.surface2,
        selectedColor: CompozyColors.elevated,
        labelStyle: const TextStyle(color: CompozyColors.fg, fontSize: 13),
        secondaryLabelStyle: const TextStyle(
          color: CompozyColors.fgStrong,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: CompozyColors.line, width: 1),
        shape: const RoundedRectangleBorder(borderRadius: CompozyRadius.pill),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: CompozyColors.line,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: CompozyColors.fgStrong,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: CompozyColors.fgStrong,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: CompozyColors.fg,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: CompozyColors.muted,
          fontSize: 12,
        ),
      ),
    );
  }
}
