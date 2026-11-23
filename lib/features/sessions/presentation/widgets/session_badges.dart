import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';

/// Status badge pill reflecting session lifecycle state.
/// Mirrors the status dots and badges in board.jpg and always-on.jpg.
class StateBadge extends StatelessWidget {
  final String state;

  const StateBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final normalized = state.toLowerCase();

    switch (normalized) {
      case 'active':
      case 'working':
        badgeColor = CompozyColors.success; // Mint green (#34D399)
        break;
      case 'waiting':
      case 'busy':
        badgeColor = CompozyColors.warning; // Amber (#F5B14C)
        break;
      case 'needs you':
      case 'needs_you':
        badgeColor = CompozyColors.accent;  // Exclusive orange (#E8572A)
        break;
      case 'stopped':
      case 'failed':
      case 'canceled':
        badgeColor = CompozyColors.danger;  // Rose / Red (#F87171)
        break;
      case 'idle':
      case 'done':
      default:
        badgeColor = CompozyColors.subtle;  // Subtle gray (#707070)
        break;
    }

    final isNeedsYou = normalized == 'needs you' || normalized == 'needs_you';

    return Container(
      key: Key('session_state_badge_$normalized'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isNeedsYou ? const Color(0xFF241510) : CompozyColors.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(
          color: isNeedsYou
              ? CompozyColors.accent.withValues(alpha: 0.5)
              : CompozyColors.line,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            state,
            style: TextStyle(
              color: isNeedsYou ? CompozyColors.accent : CompozyColors.fg,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Agent pill badge indicating agent identity with clean neutral styling.
/// Aligned with the subtle tags in board.jpg and hero.jpg.
class AgentBadge extends StatelessWidget {
  final String agent;

  const AgentBadge({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('session_agent_badge_$agent'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CompozyColors.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: CompozyColors.line, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.smart_toy_outlined,
            size: 11,
            color: CompozyColors.info,
          ),
          const SizedBox(width: 4),
          Text(
            agent,
            style: const TextStyle(
              color: CompozyColors.fg,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular agent avatar mirroring always-on.jpg and board.jpg,
/// with agent-tinted circular surface and activity status indicator.
class AgentAvatar extends StatelessWidget {
  final String agent;
  final String? state;
  final double size;

  const AgentAvatar({
    super.key,
    required this.agent,
    this.state,
    this.size = 24.0,
  });

  Color _resolveAvatarBg(String name) {
    switch (name.toLowerCase()) {
      case 'designer':
        return const Color(0xFF6D28D9); // Violet/Purple
      case 'fixer':
        return const Color(0xFFD97706); // Amber/Bronze
      case 'auditor':
        return const Color(0xFFE11D48); // Coral/Rose
      case 'dispatcher':
        return const Color(0xFF0284C7); // Sky/Blue
      case 'researcher':
        return const Color(0xFF059669); // Emerald
      default:
        return const Color(0xFF334155); // Slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _resolveAvatarBg(agent);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: CompozyColors.line, width: 1),
      ),
      child: Center(
        child: Text(
          agent.isNotEmpty ? agent[0].toUpperCase() : 'A',
          style: TextStyle(
            color: CompozyColors.fgStrong,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
