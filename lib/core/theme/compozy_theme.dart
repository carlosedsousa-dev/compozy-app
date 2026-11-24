import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'compozy_palette.dart';

export 'compozy_palette.dart';

/// Canonical CompozyOS Design System color tokens (Dark Mode).
/// Pure chroma-free neutral dark palette, inverted monochrome primary actions,
/// and semantic signal palette (strictly aligned with ds-core.css / reference images).
class CompozyColors {
  const CompozyColors._();

  // Canonical Surfaces
  static const Color canvas = Color(0xFF0A0A0A);     // Ultra dark canvas background (#0A0A0A)
  static const Color rail = Color(0xFF0A0A0A);       // Navigation rail / top app bar
  static const Color desk = Color(0xFF101010);       // Secondary surface / workspace desk (#101010)
  static const Color card = Color(0xFF161616);       // Cards & containers (#161616)
  static const Color canvasSoft = Color(0xFF1A1A1A); // Soft container surface
  static const Color surface2 = Color(0xFF1E1E1E);   // Sub-elements, chips, input background
  static const Color elevated = Color(0xFF232323);   // Elevated pills, hover, chat user bubble (#232323)

  // Lines & Borders (1px solid canonical line)
  static const Color line = Color(0xFF262626);       // Canonical border (#262626, 1px sólido)
  static const Color lineSoft = Color(0xFF1F1F1F);   // Subtle divider
  static const Color lineStrong = Color(0xFF383838); // Highlighted / selected border

  // Typography & Text Ladder
  static const Color fgStrong = Color(0xFFFFFFFF);
  static const Color fg = Color(0xFFF5F5F5);
  static const Color muted = Color(0xFF989898);
  static const Color subtle = Color(0xFF707070);

  // Actions & Accents
  // Primary action: STRICTLY inverted monochrome pill (#F5F5F5 bg, #0A0A0A text). NEVER orange.
  static const Color primary = Color(0xFFF5F5F5);
  static const Color primaryInk = Color(0xFF0A0A0A);

  // Accent: RESERVED EXCLUSIVELY for attention and urgency ("Needs you" badge/dot, unread alerts).
  // NEVER use for primary buttons or general borders.
  static const Color accent = Color(0xFFE8572A);

  // Semantic Signal Palette (Status)
  static const Color success = Color(0xFF34D399); // Mint / Green (Working, active, healthy)
  static const Color warning = Color(0xFFF5B14C); // Amber (Waiting/busy, degraded)
  static const Color danger = Color(0xFFF87171);  // Rose / Red (Stopped, failed, disconnected)
  static const Color info = Color(0xFF8E8EB5);    // Slate / Violet (Category / Agent info)
}

/// Canonical CompozyOS Design System Light Mode color tokens (tokens-light.css / lockup-light.png).
/// Pure chroma-free neutral light palette, inverted monochrome primary actions (#0A0A0A on #FFFFFF),
/// and semantic signal palette.
class CompozyColorsLight {
  const CompozyColorsLight._();

  // Canonical Surfaces
  static const Color canvas = Color(0xFFFFFFFF);     // Pure white canvas background (#FFFFFF)
  static const Color rail = Color(0xFFFAFAFA);       // Navigation rail / top app bar
  static const Color desk = Color(0xFFF4F4F5);       // Secondary surface / workspace desk (#F4F4F5)
  static const Color card = Color(0xFFFFFFFF);       // Cards & containers (#FFFFFF)
  static const Color canvasSoft = Color(0xFFF4F4F5); // Soft container surface
  static const Color surface2 = Color(0xFFEFEFEF);   // Sub-elements, chips, input background
  static const Color elevated = Color(0xFFE4E4E7);   // Elevated pills, hover, chat bubble

  // Lines & Borders (1px solid canonical line)
  static const Color line = Color(0xFFE4E4E7);       // Canonical border (#E4E4E7, 1px solid)
  static const Color lineSoft = Color(0xFFF0F0F0);   // Subtle divider
  static const Color lineStrong = Color(0xFFD4D4D8); // Highlighted / selected border

  // Typography & Text Ladder
  static const Color fgStrong = Color(0xFF0A0A0A);
  static const Color fg = Color(0xFF18181B);
  static const Color muted = Color(0xFF71717A);
  static const Color subtle = Color(0xFFA1A1AA);

  // Actions & Accents
  // Primary action: STRICTLY inverted monochrome pill (#0A0A0A bg, #FFFFFF text in light mode). NEVER orange.
  static const Color primary = Color(0xFF0A0A0A);
  static const Color primaryInk = Color(0xFFFFFFFF);

  // Accent: RESERVED EXCLUSIVELY for attention and urgency ("Needs you" badge/dot, unread alerts).
  static const Color accent = Color(0xFFE8572A);

  // Semantic Signal Palette (Status)
  static const Color success = Color(0xFF059669); // Emerald / Green (Working, active, healthy)
  static const Color warning = Color(0xFFD97706); // Amber (Waiting/busy, degraded)
  static const Color danger = Color(0xFFDC2626);  // Red (Stopped, failed, disconnected)
  static const Color info = Color(0xFF6366F1);    // Slate / Violet (Category / Agent info)
}

/// Canonical CompozyOS Geometry & Radius tokens.
class CompozyRadius {
  const CompozyRadius._();

  static const double radiusSm = 6.0;
  static const double radius = 8.0;
  static const double radiusLg = 12.0;
  static const double radiusXl = 16.0;
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
      extensions: const [CompozyPalette.dark],
      scaffoldBackgroundColor: CompozyColors.desk,
      canvasColor: CompozyColors.canvas,
      colorScheme: const ColorScheme.dark(
        surface: CompozyColors.card,
        onSurface: CompozyColors.fg,
        primary: CompozyColors.primary,
        onPrimary: CompozyColors.primaryInk,
        secondary: CompozyColors.elevated,
        onSecondary: CompozyColors.fg,
        error: CompozyColors.danger,
        onError: CompozyColors.fgStrong,
        outline: CompozyColors.line,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: CompozyColors.canvas,
        foregroundColor: CompozyColors.fgStrong,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemStatusBarContrastEnforced: false,
        ),
        titleTextStyle: TextStyle(
          color: CompozyColors.fgStrong,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      cardTheme: CardThemeData(
        color: CompozyColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: CompozyRadius.card,
          side: const BorderSide(color: CompozyColors.line, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CompozyColors.canvas,
        selectedItemColor: CompozyColors.fgStrong,
        unselectedItemColor: CompozyColors.subtle,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: CompozyColors.canvas,
        selectedIconTheme: IconThemeData(color: CompozyColors.fgStrong),
        unselectedIconTheme: IconThemeData(color: CompozyColors.subtle),
        selectedLabelTextStyle: TextStyle(
          color: CompozyColors.fgStrong,
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
        backgroundColor: CompozyColors.card,
        selectedColor: CompozyColors.elevated,
        labelStyle: const TextStyle(color: CompozyColors.muted, fontSize: 13),
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

  /// Light Theme adhering to tokens-light.css / lockup-light.png.
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      extensions: const [CompozyPalette.light],
      scaffoldBackgroundColor: CompozyColorsLight.desk,
      canvasColor: CompozyColorsLight.canvas,
      colorScheme: const ColorScheme.light(
        surface: CompozyColorsLight.card,
        onSurface: CompozyColorsLight.fg,
        primary: CompozyColorsLight.primary,
        onPrimary: CompozyColorsLight.primaryInk,
        secondary: CompozyColorsLight.elevated,
        onSecondary: CompozyColorsLight.fg,
        error: CompozyColorsLight.danger,
        onError: CompozyColorsLight.primaryInk,
        outline: CompozyColorsLight.line,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: CompozyColorsLight.canvas,
        foregroundColor: CompozyColorsLight.fgStrong,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemStatusBarContrastEnforced: false,
        ),
        titleTextStyle: TextStyle(
          color: CompozyColorsLight.fgStrong,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          fontFamily: 'Inter',
        ),
      ),
      cardTheme: CardThemeData(
        color: CompozyColorsLight.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: CompozyRadius.card,
          side: const BorderSide(color: CompozyColorsLight.line, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: CompozyColorsLight.canvas,
        selectedItemColor: CompozyColorsLight.fgStrong,
        unselectedItemColor: CompozyColorsLight.subtle,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: CompozyColorsLight.canvas,
        selectedIconTheme: IconThemeData(color: CompozyColorsLight.fgStrong),
        unselectedIconTheme: IconThemeData(color: CompozyColorsLight.subtle),
        selectedLabelTextStyle: TextStyle(
          color: CompozyColorsLight.fgStrong,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: CompozyColorsLight.muted,
          fontSize: 12,
        ),
        indicatorColor: CompozyColorsLight.elevated,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: CompozyColorsLight.card,
        selectedColor: CompozyColorsLight.elevated,
        labelStyle: const TextStyle(color: CompozyColorsLight.muted, fontSize: 13),
        secondaryLabelStyle: const TextStyle(
          color: CompozyColorsLight.fgStrong,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        side: const BorderSide(color: CompozyColorsLight.line, width: 1),
        shape: const RoundedRectangleBorder(borderRadius: CompozyRadius.pill),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: CompozyColorsLight.line,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: CompozyColorsLight.fgStrong,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: CompozyColorsLight.fgStrong,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(
          color: CompozyColorsLight.fg,
          fontSize: 14,
        ),
        bodySmall: TextStyle(
          color: CompozyColorsLight.muted,
          fontSize: 12,
        ),
      ),
    );
  }
}
