import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';
import '../../domain/models/agent_presence.dart';

/// Circular agent avatar with deterministic gradient and initials derived from
/// agent appearance seed and color, featuring an optional presence status signal dot.
class AgentAvatar extends StatelessWidget {
  final AgentAppearance appearance;
  final String label;
  final String name;
  final AgentPresenceStatus? status;
  final double size;

  const AgentAvatar({
    super.key,
    required this.appearance,
    required this.label,
    required this.name,
    this.status,
    this.size = 40.0,
  });

  static const String _defaultPackageColor = '7C5CFF';
  static const Color _glyphWhite = Color(0xFFFFFFFF);
  static const Color _glyphDark = Color(0xFF0A0A0A);

  static double _contrastRatio(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = math.max(l1, l2);
    final darker = math.min(l1, l2);
    return (lighter + 0.05) / (darker + 0.05);
  }

  /// Deterministically parses hex string or calculates HSL color from seed,
  /// adjusting lightness if needed to ensure >= 4.5:1 contrast under gradient.
  Color _resolveBaseColor(CompozyPalette palette) {
    final rawHex = appearance.colorHex?.replaceAll('#', '').trim().toUpperCase();
    if (rawHex != null && (rawHex.length == 6 || rawHex.length == 8)) {
      final normalizedHex = rawHex.length == 8 && rawHex.startsWith('FF')
          ? rawHex.substring(2)
          : rawHex;
      if (normalizedHex != _defaultPackageColor) {
        final parsed = int.tryParse(rawHex.length == 6 ? 'FF$rawHex' : rawHex, radix: 16);
        if (parsed != null) {
          return Color(parsed);
        }
      }
    }

    // Deterministic fallback from seed or name hash
    final seedString = (appearance.seed != null && appearance.seed!.isNotEmpty)
        ? appearance.seed!
        : (name.isNotEmpty ? name : label);
    final hash = seedString.codeUnits.fold<int>(0, (sum, c) => (sum * 31 + c) & 0xFFFFFF);
    final hue = (hash % 360).toDouble();

    final isDark = palette.canvas.computeLuminance() < 0.5;
    double lightness = isDark ? 0.35 : 0.72;
    const saturation = 0.55;

    for (int i = 0; i < 70; i++) {
      final base = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();
      final gradEnd = Color.lerp(base, palette.canvas, 0.35) ?? base;

      final whiteWorst = math.min(_contrastRatio(base, _glyphWhite), _contrastRatio(gradEnd, _glyphWhite));
      final darkWorst = math.min(_contrastRatio(base, _glyphDark), _contrastRatio(gradEnd, _glyphDark));
      final worstContrast = math.max(whiteWorst, darkWorst);

      if (worstContrast >= 4.5) {
        return base;
      }

      final glyph = whiteWorst >= darkWorst ? _glyphWhite : _glyphDark;
      final targetLightness = glyph == _glyphWhite ? 0.28 : 0.80;
      final step = lightness > targetLightness ? -0.01 : 0.01;
      final nextLightness = (lightness + step).clamp(0.18, 0.88);
      if ((nextLightness - lightness).abs() < 0.001) {
        break;
      }
      lightness = nextLightness;
    }

    return HSLColor.fromAHSL(1.0, hue, saturation, lightness.clamp(0.18, 0.88)).toColor();
  }

  /// Computes the glyph color based on circle luminance and gradient contrast.
  Color _resolveGlyphColor(CompozyPalette palette, Color baseColor) {
    final gradEnd = Color.lerp(baseColor, palette.canvas, 0.35) ?? baseColor;
    final whiteWorst = math.min(_contrastRatio(baseColor, _glyphWhite), _contrastRatio(gradEnd, _glyphWhite));
    final darkWorst = math.min(_contrastRatio(baseColor, _glyphDark), _contrastRatio(gradEnd, _glyphDark));
    return whiteWorst >= darkWorst ? _glyphWhite : _glyphDark;
  }

  /// Extracts 1 or 2 uppercase initials from label or name.
  String _extractInitials() {
    final source = label.trim().isNotEmpty ? label.trim() : name.trim();
    if (source.isEmpty) return 'A';

    final words = source.split(RegExp(r'[\s_\-]+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return source.substring(0, source.length >= 2 ? 2 : 1).toUpperCase();
  }

  Color _resolveStatusColor(CompozyPalette palette, AgentPresenceStatus s) {
    switch (s) {
      case AgentPresenceStatus.working:
        return palette.success;
      case AgentPresenceStatus.needsYou:
        return palette.accent;
      case AgentPresenceStatus.idle:
        return palette.subtle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final baseColor = _resolveBaseColor(palette);
    final glyphColor = _resolveGlyphColor(palette, baseColor);
    final initials = _extractInitials();
    final dotSize = (size * 0.28).clamp(8.0, 14.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Circular Avatar Surface with subtle gradient
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  baseColor,
                  Color.lerp(baseColor, palette.canvas, 0.35) ?? baseColor,
                ],
              ),
              border: Border.all(
                color: palette.lineStrong,
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: glyphColor,
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // Presence Signal Dot (mirrors always-on.jpg)
          if (status != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                key: Key('agent_avatar_status_dot_${status!.name}'),
                width: dotSize,
                height: dotSize,
                decoration: BoxDecoration(
                  color: _resolveStatusColor(palette, status!),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: palette.card,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
