import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';

/// Status badge pill reflecting session lifecycle state.
class StateBadge extends StatelessWidget {
  final String state;

  const StateBadge({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final Color badgeColor;
    final normalized = state.toLowerCase();

    switch (normalized) {
      case 'active':
        badgeColor = CompozyColors.success;
        break;
      case 'waiting':
      case 'busy':
        badgeColor = CompozyColors.warning;
        break;
      case 'stopped':
      case 'failed':
      case 'canceled':
        badgeColor = CompozyColors.danger;
        break;
      case 'idle':
      default:
        badgeColor = CompozyColors.info;
        break;
    }

    return Container(
      key: Key('session_state_badge_$normalized'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: CompozyColors.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 1),
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
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Agent pill badge indicating agent identity.
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
            size: 12,
            color: CompozyColors.info,
          ),
          const SizedBox(width: 4),
          Text(
            agent,
            style: const TextStyle(
              color: CompozyColors.info,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
