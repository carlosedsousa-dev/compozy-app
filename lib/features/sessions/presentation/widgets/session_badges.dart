import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';

/// Helper to determine whether a session lifecycle state requires user action / triage.
bool isSessionAwaitingUser(String state) {
  final s = state.toLowerCase().replaceAll('_', '-').trim();
  return s == 'waiting' ||
      s == 'needs-input' ||
      s == 'needs you' ||
      s == 'needs-you' ||
      s == 'blocked';
}

/// Status badge pill reflecting session lifecycle state.
/// Mirrors the status dots and badges in board.jpg and always-on.jpg.
class StateBadge extends StatelessWidget {
  final String state;

  const StateBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color badgeColor;
    final normalized = state.toLowerCase();
    final isNeedsYou = isSessionAwaitingUser(state);

    if (isNeedsYou) {
      badgeColor = palette.accent;
    } else {
      switch (normalized) {
        case 'active':
        case 'working':
          badgeColor = palette.success;
          break;
        case 'busy':
        case 'queued':
        case 'pending':
          badgeColor = palette.warning;
          break;
        case 'stopped':
        case 'failed':
        case 'canceled':
        case 'cancelled':
          badgeColor = palette.danger;
          break;
        case 'idle':
        case 'done':
        default:
          badgeColor = palette.subtle;
          break;
      }
    }

    return Container(
      key: Key('session_state_badge_$normalized'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isNeedsYou
            ? palette.accent.withValues(alpha: 0.12)
            : palette.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(
          color: isNeedsYou
              ? palette.accent.withValues(alpha: 0.40)
              : palette.line,
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
              color: isNeedsYou ? palette.accent : palette.fg,
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
    final palette = context.palette;

    return Container(
      key: Key('session_agent_badge_$agent'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 11,
            color: palette.info,
          ),
          const SizedBox(width: 4),
          Text(
            agent,
            style: TextStyle(
              color: palette.fg,
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
    final palette = context.palette;
    final bg = _resolveAvatarBg(agent);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Center(
        child: Text(
          agent.isNotEmpty ? agent[0].toUpperCase() : 'A',
          style: TextStyle(
            color: const Color(0xFFFFFFFF),
            fontSize: size * 0.46,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
