import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';
import '../../domain/models/agent_presence.dart';
import 'agent_avatar.dart';
import 'agent_status_badge.dart';

/// Visual card representing an agent in the catalog, strictly mirroring
/// always-on.jpg and board.jpg design tokens.
class AgentCard extends StatelessWidget {
  final AgentPresence presence;
  final VoidCallback? onTap;

  const AgentCard({
    super.key,
    required this.presence,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final agent = presence.agent;
    final isNeedsYou = presence.isNeedsYou;

    return Semantics(
      button: true,
      label: '${agent.label} agent, status ${presence.status.name}',
      child: Container(
        key: Key('agent_card_${agent.name}'),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: CompozyRadius.card,
          border: Border.all(
            color: isNeedsYou
                ? palette.accent.withValues(alpha: 0.40)
                : palette.line,
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: CompozyRadius.card,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Top Row: Avatar + Title & Identifiers + Status Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AgentAvatar(
                        appearance: agent.appearance,
                        label: agent.label,
                        name: agent.name,
                        status: presence.status,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    agent.label,
                                    style: TextStyle(
                                      color: palette.fgStrong,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.1,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AgentStatusBadge(status: presence.status),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              agent.name,
                              style: TextStyle(
                                color: palette.subtle,
                                fontSize: 11,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Metadata Row: Kind pill, Category pill, Pinned runtime monospace pill
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      // Kind Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.surface2,
                          borderRadius: CompozyRadius.pill,
                          border: Border.all(color: palette.line, width: 1),
                        ),
                        child: Text(
                          agent.kindDisplay,
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Category Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: palette.surface2,
                          borderRadius: CompozyRadius.pill,
                          border: Border.all(color: palette.line, width: 1),
                        ),
                        child: Text(
                          agent.categoryDisplay,
                          style: TextStyle(
                            color: palette.info,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Pinned Provider / Model Monospace Pill (when present)
                      if (agent.pinnedRuntimeDisplay != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: palette.surface2,
                            borderRadius: CompozyRadius.pill,
                            border: Border.all(color: palette.lineStrong, width: 1),
                          ),
                          child: Text(
                            agent.pinnedRuntimeDisplay!,
                            style: TextStyle(
                              color: palette.fg,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Divider(color: palette.lineSoft, height: 1),
                  const SizedBox(height: 10),

                  // Bottom Line: Running/Waiting session counters + Chevron hint
                  Row(
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (presence.workingSessionsCount > 0 || presence.waitingSessionsCount > 0) ...[
                              if (presence.workingSessionsCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: palette.surface2,
                                    borderRadius: CompozyRadius.pill,
                                    border: Border.all(color: palette.line, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: palette.success,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${presence.workingSessionsCount} running',
                                        style: TextStyle(
                                          color: palette.fg,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (presence.waitingSessionsCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: palette.accent.withValues(alpha: 0.12),
                                    borderRadius: CompozyRadius.pill,
                                    border: Border.all(
                                      color: palette.accent.withValues(alpha: 0.35),
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
                                          color: palette.accent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${presence.waitingSessionsCount} waiting',
                                        style: TextStyle(
                                          color: palette.accent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ] else ...[
                              Text(
                                'Idle · No active sessions',
                                style: TextStyle(
                                  color: palette.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: palette.subtle,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
