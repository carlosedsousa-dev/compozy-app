import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/widgets/compozy_skeleton.dart';
import '../../../../core/theme/compozy_theme.dart';
import '../../data/agents_repository_provider.dart';
import 'agent_avatar.dart';
import 'agent_status_badge.dart';

/// Modal bottom sheet displaying deep agent inspection, toolsets, skills,
/// effective runtime, and asynchronous telemetry from /api/agents/{name}/activity.
class AgentDetailsSheet extends ConsumerWidget {
  final AgentPresence presence;

  const AgentDetailsSheet({
    super.key,
    required this.presence,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final agent = presence.agent;
    final activityAsync = ref.watch(agentActivityProvider(agent.name));

    return Container(
      key: const Key('agent_details_bottom_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: palette.line, width: 1),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: palette.lineStrong,
                  borderRadius: CompozyRadius.pill,
                ),
              ),
            ),

            // Sheet Header: Avatar, Name & Labels, Close Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  AgentAvatar(
                    appearance: agent.appearance,
                    label: agent.label,
                    name: agent.name,
                    status: presence.status,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                agent.label,
                                style: TextStyle(
                                  color: palette.fgStrong,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            AgentStatusBadge(status: presence.status),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              agent.name,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: palette.surface2,
                                borderRadius: CompozyRadius.pill,
                                border: Border.all(color: palette.lineSoft, width: 1),
                              ),
                              child: Text(
                                agent.origin,
                                style: TextStyle(
                                  color: palette.subtle,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('close_agent_details_sheet_button'),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    tooltip: 'Close',
                    icon: Icon(
                      Icons.close,
                      color: palette.muted,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Divider(color: palette.line, height: 1),

            // Scrollable Details Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section: Presence & Sessions
                    _buildSectionTitle(context, 'SESSION PRESENCE', Icons.sensors),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        borderRadius: CompozyRadius.input,
                        border: Border.all(color: palette.line, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Active Sessions:',
                                style: TextStyle(color: palette.muted, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${presence.workingSessionsCount} working · ${presence.waitingSessionsCount} waiting',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    color: palette.fgStrong,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Total Workspace Sessions:',
                                style: TextStyle(color: palette.muted, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${presence.totalSessionsCount}',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    color: palette.fg,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section: Effective Runtime
                    _buildSectionTitle(context, 'EFFECTIVE RUNTIME', Icons.settings_suggest_outlined),
                    const SizedBox(height: 8),
                    _buildRuntimeSection(context, agent),
                    const SizedBox(height: 20),

                    // Section: Toolsets
                    _buildSectionTitle(context, 'TOOLSETS', Icons.handyman_outlined),
                    const SizedBox(height: 8),
                    _buildToolsetsSection(context, agent),
                    const SizedBox(height: 20),

                    // Section: Skills
                    _buildSectionTitle(context, 'SKILLS', Icons.auto_awesome_outlined),
                    const SizedBox(height: 8),
                    _buildSkillsSection(context, agent),
                    const SizedBox(height: 20),

                    // Section: Activity & Telemetry
                    _buildSectionTitle(context, 'ACTIVITY & TELEMETRY', Icons.query_stats_outlined),
                    const SizedBox(height: 8),
                    _buildActivitySection(context, activityAsync),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    final palette = context.palette;
    return Row(
      children: [
        Icon(icon, size: 14, color: palette.info),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            color: palette.muted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildRuntimeSection(BuildContext context, AgentDefinition agent) {
    final palette = context.palette;
    final runtime = agent.effectiveRuntime;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: CompozyRadius.input,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Model Pin:', style: TextStyle(color: palette.muted, fontSize: 13)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  agent.isPinned ? agent.pinnedRuntimeDisplay! : 'Not pinned (runtime default)',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: agent.isPinned ? palette.fgStrong : palette.muted,
                    fontSize: 12,
                    fontFamily: 'monospace',
                    fontWeight: agent.isPinned ? FontWeight.w600 : FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (runtime != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Effective Provider / Model:', style: TextStyle(color: palette.muted, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${runtime.provider} · ${runtime.model}',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      color: palette.fgStrong,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Reasoning Effort:', style: TextStyle(color: palette.muted, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    runtime.reasoningEffort,
                    textAlign: TextAlign.end,
                    style: TextStyle(color: palette.fg, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (runtime.permissions != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('Permissions:', style: TextStyle(color: palette.muted, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      runtime.permissions!,
                      textAlign: TextAlign.end,
                      style: TextStyle(color: palette.fg, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildToolsetsSection(BuildContext context, AgentDefinition agent) {
    final palette = context.palette;
    if (agent.toolsets.isEmpty) {
      return Text(
        'No toolsets declared for this agent.',
        style: TextStyle(color: palette.muted, fontSize: 13, fontStyle: FontStyle.italic),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: agent.toolsets.map((toolset) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: palette.surface2,
            borderRadius: CompozyRadius.pill,
            border: Border.all(color: palette.line, width: 1),
          ),
          child: Text(
            toolset,
            style: TextStyle(
              color: palette.fg,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSkillsSection(BuildContext context, AgentDefinition agent) {
    final palette = context.palette;
    if (agent.skills.isEmpty) {
      return Text(
        'No skills configured.',
        style: TextStyle(color: palette.muted, fontSize: 13, fontStyle: FontStyle.italic),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: agent.skills.keys.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: palette.surface2,
            borderRadius: CompozyRadius.pill,
            border: Border.all(color: palette.line, width: 1),
          ),
          child: Text(
            skill,
            style: TextStyle(
              color: palette.fg,
              fontSize: 12,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivitySection(
    BuildContext context,
    AsyncValue<AgentActivity> activityAsync,
  ) {
    final palette = context.palette;

    return activityAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: CompozySkeleton(height: 80, borderRadius: CompozyRadius.card),
      ),
      error: (error, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface2,
          borderRadius: CompozyRadius.input,
          border: Border.all(color: palette.line, width: 1),
        ),
        child: Text(
          'Telemetry unavailable from daemon.',
          style: TextStyle(color: palette.muted, fontSize: 13, fontStyle: FontStyle.italic),
        ),
      ),
      data: (activity) {
        if (activity.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surface2,
              borderRadius: CompozyRadius.input,
              border: Border.all(color: palette.line, width: 1),
            ),
            child: Text(
              'No activity recorded for this agent in current workspaces.',
              style: TextStyle(color: palette.muted, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          );
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: palette.surface2,
            borderRadius: CompozyRadius.input,
            border: Border.all(color: palette.line, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary Tokens & USD
              Row(
                children: [
                  Text('Total Tokens:', style: TextStyle(color: palette.muted, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatTokens(activity.totalTokens),
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: palette.fgStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('USD Estimate:', style: TextStyle(color: palette.muted, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '\$${activity.totalUsdEstimate.toStringAsFixed(3)}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: palette.fgStrong,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text('Activity Events:', style: TextStyle(color: palette.muted, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${activity.totalEvents} events (${activity.busyByHour.length} slots)',
                      textAlign: TextAlign.end,
                      style: TextStyle(color: palette.fg, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // Project Breakdown if multiple projects
              if (activity.costByProject.isNotEmpty) ...[
                const SizedBox(height: 10),
                Divider(color: palette.lineSoft, height: 1),
                const SizedBox(height: 8),
                Text(
                  'Workspaces breakdown:',
                  style: TextStyle(color: palette.muted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ...activity.costByProject.map((cost) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cost.scope.isNotEmpty ? cost.scope : cost.workspaceId,
                            style: TextStyle(color: palette.fg, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_formatTokens(cost.tokens)} (${'\$${cost.usdEstimate.toStringAsFixed(3)}'})',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 11,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatTokens(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}k';
    }
    return tokens.toString();
  }
}
