import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';
import '../../domain/models/agent_presence.dart';

/// Status pill badge reflecting an agent's presence status
/// (Working in green, Needs you in orange accent, Idle in neutral slate).
class AgentStatusBadge extends StatelessWidget {
  final AgentPresenceStatus status;

  const AgentStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final Color color;
    final String label;

    switch (status) {
      case AgentPresenceStatus.working:
        color = palette.success;
        label = 'Working';
        break;
      case AgentPresenceStatus.needsYou:
        color = palette.accent;
        label = 'Needs you';
        break;
      case AgentPresenceStatus.idle:
        color = palette.subtle;
        label = 'Idle';
        break;
    }

    final isNeedsYou = status == AgentPresenceStatus.needsYou;

    return Container(
      key: Key('agent_status_badge_${status.name}'),
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
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
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
