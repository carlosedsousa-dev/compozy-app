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

  /// Deterministically parses hex string or calculates HSL color from seed.
  Color _resolveBaseColor(CompozyPalette palette) {
    final hex = appearance.colorHex?.replaceAll('#', '').trim();
    if (hex != null && (hex.length == 6 || hex.length == 8)) {
      final parsed = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (parsed != null) {
        return Color(parsed);
      }
    }

    // Deterministic fallback from seed or name hash
    final seedString = appearance.seed ?? name;
    final hash = seedString.codeUnits.fold<int>(0, (sum, c) => (sum * 31 + c) & 0xFFFFFF);
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.60, 0.42).toColor();
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
                  color: palette.fgStrong,
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
