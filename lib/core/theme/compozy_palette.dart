import 'package:material_ui/material_ui.dart';

/// ThemeExtension providing CompozyOS Design System semantic color tokens.
/// Allows widgets to dynamically adapt between Dark and Light modes via [BuildContext.palette].
@immutable
class CompozyPalette extends ThemeExtension<CompozyPalette> {
  final Color canvas;
  final Color desk;
  final Color card;
  final Color canvasSoft;
  final Color surface2;
  final Color elevated;

  final Color line;
  final Color lineSoft;
  final Color lineStrong;

  final Color fgStrong;
  final Color fg;
  final Color muted;
  final Color subtle;

  final Color primary;
  final Color primaryInk;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  const CompozyPalette({
    required this.canvas,
    required this.desk,
    required this.card,
    required this.canvasSoft,
    required this.surface2,
    required this.elevated,
    required this.line,
    required this.lineSoft,
    required this.lineStrong,
    required this.fgStrong,
    required this.fg,
    required this.muted,
    required this.subtle,
    required this.primary,
    required this.primaryInk,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  /// Canonical CompozyOS Dark Mode palette tokens.
  static const CompozyPalette dark = CompozyPalette(
    canvas: Color(0xFF0A0A0A),
    desk: Color(0xFF101010),
    card: Color(0xFF161616),
    canvasSoft: Color(0xFF1A1A1A),
    surface2: Color(0xFF1E1E1E),
    elevated: Color(0xFF232323),
    line: Color(0xFF262626),
    lineSoft: Color(0xFF1F1F1F),
    lineStrong: Color(0xFF383838),
    fgStrong: Color(0xFFFFFFFF),
    fg: Color(0xFFF5F5F5),
    muted: Color(0xFF989898),
    subtle: Color(0xFF707070),
    primary: Color(0xFFF5F5F5),
    primaryInk: Color(0xFF0A0A0A),
    accent: Color(0xFFE8572A),
    success: Color(0xFF34D399),
    warning: Color(0xFFF5B14C),
    danger: Color(0xFFF87171),
    info: Color(0xFF8E8EB5),
  );

  /// Canonical CompozyOS Light Mode palette tokens.
  static const CompozyPalette light = CompozyPalette(
    canvas: Color(0xFFFFFFFF),
    desk: Color(0xFFF4F4F5),
    card: Color(0xFFFFFFFF),
    canvasSoft: Color(0xFFF4F4F5),
    surface2: Color(0xFFEFEFEF),
    elevated: Color(0xFFE4E4E7),
    line: Color(0xFFE4E4E7),
    lineSoft: Color(0xFFF0F0F0),
    lineStrong: Color(0xFFD4D4D8),
    fgStrong: Color(0xFF0A0A0A),
    fg: Color(0xFF18181B),
    muted: Color(0xFF71717A),
    subtle: Color(0xFFA1A1AA),
    primary: Color(0xFF0A0A0A),
    primaryInk: Color(0xFFFFFFFF),
    accent: Color(0xFFE8572A),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    info: Color(0xFF6366F1),
  );

  @override
  CompozyPalette copyWith({
    Color? canvas,
    Color? desk,
    Color? card,
    Color? canvasSoft,
    Color? surface2,
    Color? elevated,
    Color? line,
    Color? lineSoft,
    Color? lineStrong,
    Color? fgStrong,
    Color? fg,
    Color? muted,
    Color? subtle,
    Color? primary,
    Color? primaryInk,
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return CompozyPalette(
      canvas: canvas ?? this.canvas,
      desk: desk ?? this.desk,
      card: card ?? this.card,
      canvasSoft: canvasSoft ?? this.canvasSoft,
      surface2: surface2 ?? this.surface2,
      elevated: elevated ?? this.elevated,
      line: line ?? this.line,
      lineSoft: lineSoft ?? this.lineSoft,
      lineStrong: lineStrong ?? this.lineStrong,
      fgStrong: fgStrong ?? this.fgStrong,
      fg: fg ?? this.fg,
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
      primary: primary ?? this.primary,
      primaryInk: primaryInk ?? this.primaryInk,
      accent: accent ?? this.accent,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  CompozyPalette lerp(ThemeExtension<CompozyPalette>? other, double t) {
    if (other is! CompozyPalette) {
      return this;
    }
    return CompozyPalette(
      canvas: Color.lerp(canvas, other.canvas, t) ?? canvas,
      desk: Color.lerp(desk, other.desk, t) ?? desk,
      card: Color.lerp(card, other.card, t) ?? card,
      canvasSoft: Color.lerp(canvasSoft, other.canvasSoft, t) ?? canvasSoft,
      surface2: Color.lerp(surface2, other.surface2, t) ?? surface2,
      elevated: Color.lerp(elevated, other.elevated, t) ?? elevated,
      line: Color.lerp(line, other.line, t) ?? line,
      lineSoft: Color.lerp(lineSoft, other.lineSoft, t) ?? lineSoft,
      lineStrong: Color.lerp(lineStrong, other.lineStrong, t) ?? lineStrong,
      fgStrong: Color.lerp(fgStrong, other.fgStrong, t) ?? fgStrong,
      fg: Color.lerp(fg, other.fg, t) ?? fg,
      muted: Color.lerp(muted, other.muted, t) ?? muted,
      subtle: Color.lerp(subtle, other.subtle, t) ?? subtle,
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      primaryInk: Color.lerp(primaryInk, other.primaryInk, t) ?? primaryInk,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      info: Color.lerp(info, other.info, t) ?? info,
    );
  }
}

/// Convenience extension on [BuildContext] to access [CompozyPalette] tokens.
extension CompozyPaletteX on BuildContext {
  /// Theme-aware tokens. Falls back to dark when the extension is absent.
  CompozyPalette get palette =>
      Theme.of(this).extension<CompozyPalette>() ?? CompozyPalette.dark;
}
