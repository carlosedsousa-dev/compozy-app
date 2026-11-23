import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';
import '../../domain/models/session.dart';
import 'session_badges.dart';

/// Data representation of a subagent or worker lane in the delegation hierarchy tree.
class SubagentItem {
  final String id;
  final String role;
  final String name;
  final String state;
  final String? model;
  final String? runtimeTag;
  final int depth;
  final String? brief;
  final List<SubagentItem> children;

  const SubagentItem({
    required this.id,
    required this.role,
    required this.name,
    this.state = 'working',
    this.model,
    this.runtimeTag,
    this.depth = 0,
    this.brief,
    this.children = const [],
  });

  factory SubagentItem.fromSession(
    Session session, {
    int depth = 0,
    String? model,
    String? runtimeTag,
    String? brief,
    List<SubagentItem> children = const [],
  }) {
    return SubagentItem(
      id: session.id,
      role: session.agent,
      name: session.name,
      state: session.state,
      depth: depth,
      model: model,
      runtimeTag: runtimeTag,
      brief: brief,
      children: children,
    );
  }
}

/// Riverpod family provider supplying subagents for a session id.
/// Can be overridden in tests or dynamically populated.
final subagentsProvider =
    Provider.family<List<SubagentItem>, String>((ref, sessionId) {
  return const [];
});

/// Drawer displaying the multi-agent worker hierarchy tree and spawned child lanes,
/// strictly mirroring handoff.jpg, with role badges, status dots, model badges,
/// and runtime tags.
class SubagentsDrawer extends ConsumerWidget {
  final Session? session;
  final List<SubagentItem>? subagents;
  final ValueChanged<SubagentItem>? onSubagentTap;
  final VoidCallback? onClose;

  const SubagentsDrawer({
    super.key,
    this.session,
    this.subagents,
    this.onSubagentTap,
    this.onClose,
  });

  List<SubagentItem> _flattenTree(List<SubagentItem> items, [int currentDepth = 0]) {
    final List<SubagentItem> result = [];
    for (final item in items) {
      final effectiveItem = item.depth != currentDepth
          ? SubagentItem(
              id: item.id,
              role: item.role,
              name: item.name,
              state: item.state,
              model: item.model,
              runtimeTag: item.runtimeTag,
              depth: currentDepth,
              brief: item.brief,
              children: item.children,
            )
          : item;
      result.add(effectiveItem);
      if (item.children.isNotEmpty) {
        result.addAll(_flattenTree(item.children, currentDepth + 1));
      }
    }
    return result;
  }

  Color _getStatusDotColor(String state, bool isDark) {
    switch (state.toLowerCase()) {
      case 'working':
      case 'active':
      case 'running':
        return isDark ? CompozyColors.success : CompozyColorsLight.success;
      case 'waiting':
      case 'busy':
      case 'queued':
      case 'pending':
        return isDark ? CompozyColors.warning : CompozyColorsLight.warning;
      case 'stopped':
      case 'failed':
      case 'error':
      case 'killed':
      case 'cancelled':
        return isDark ? CompozyColors.danger : CompozyColorsLight.danger;
      default:
        return isDark ? CompozyColors.muted : CompozyColorsLight.muted;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? CompozyColors.desk : CompozyColorsLight.desk;
    final cardBg = isDark ? CompozyColors.card : CompozyColorsLight.card;
    final borderColor = isDark ? CompozyColors.line : CompozyColorsLight.line;
    final fgStrong = isDark ? CompozyColors.fgStrong : CompozyColorsLight.fgStrong;
    final fg = isDark ? CompozyColors.fg : CompozyColorsLight.fg;
    final muted = isDark ? CompozyColors.muted : CompozyColorsLight.muted;

    final List<SubagentItem> providedItems = subagents ??
        (session != null
            ? ref.watch(subagentsProvider(session!.id))
            : const <SubagentItem>[]);

    final flatItems = _flattenTree(providedItems);
    final activeCount = flatItems.where((i) {
      final s = i.state.toLowerCase();
      return s == 'working' || s == 'active' || s == 'running';
    }).length;

    return Drawer(
      key: const Key('subagents_drawer'),
      backgroundColor: bg,
      elevation: 0,
      shape: const RoundedRectangleBorder(),
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: borderColor, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? CompozyColors.canvas : CompozyColorsLight.canvas,
                  border: Border(
                    bottom: BorderSide(color: borderColor, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_tree_outlined, size: 20, color: fgStrong),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Subagents Hierarchy',
                              style: TextStyle(
                                color: fgStrong,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (flatItems.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? CompozyColors.elevated
                                    : CompozyColorsLight.elevated,
                                borderRadius: CompozyRadius.pill,
                                border: Border.all(color: borderColor, width: 1),
                              ),
                              child: Text(
                                activeCount > 0
                                    ? '$activeCount active'
                                    : '${flatItems.length} lanes',
                                style: TextStyle(
                                  color: muted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('subagents_drawer_close'),
                      icon: Icon(Icons.close, size: 20, color: fg),
                      tooltip: 'Close Drawer',
                      onPressed: onClose ?? () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),

              // Root / Coordinator Session summary (if session context exists)
              if (session != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: CompozyRadius.card,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark
                              ? CompozyColors.surface2
                              : CompozyColorsLight.surface2,
                          borderRadius: CompozyRadius.input,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.layers_outlined,
                            size: 18,
                            color: fgStrong,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Root Session',
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.2,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                StateBadge(state: session!.state),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              session!.name,
                              style: TextStyle(
                                color: fgStrong,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'SPAWNED CHILD LANES',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],

              // Main Tree or Empty State
              Expanded(
                child: flatItems.isEmpty
                    ? _buildEmptyState(isDark, muted, fgStrong)
                    : ListView.separated(
                        key: const Key('subagents_list_view'),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: flatItems.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final item = flatItems[index];
                          return _buildSubagentItemRow(
                            context: context,
                            item: item,
                            isDark: isDark,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            fgStrong: fgStrong,
                            fg: fg,
                            muted: muted,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color muted, Color fgStrong) {
    return Center(
      child: Padding(
        key: const Key('subagents_empty_state'),
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? CompozyColors.surface2 : CompozyColorsLight.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_tree_outlined,
                size: 24,
                color: muted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No Subagents Spawned',
              style: TextStyle(
                color: fgStrong,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This session has not delegated work to child lanes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubagentItemRow({
    required BuildContext context,
    required SubagentItem item,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    required Color fgStrong,
    required Color fg,
    required Color muted,
  }) {
    final dotColor = _getStatusDotColor(item.state, isDark);
    final indentPadding = item.depth * 18.0;

    return Padding(
      padding: EdgeInsets.only(
        left: 12.0 + indentPadding,
        right: 12.0,
      ),
      child: Material(
        color: cardBg,
        borderRadius: CompozyRadius.card,
        child: InkWell(
          key: Key('subagent_item_${item.id}'),
          borderRadius: CompozyRadius.card,
          onTap: () => onSubagentTap?.call(item),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: CompozyRadius.card,
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: State dot, Role badge, Name, Tree depth indicator
                Row(
                  children: [
                    // Status dot
                    Container(
                      key: Key('subagent_status_dot_${item.id}'),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Role badge
                    Container(
                      key: Key('subagent_role_${item.id}'),
                      child: AgentBadge(agent: item.role),
                    ),
                    const SizedBox(width: 8),

                    // Subagent name / Lane title
                    Expanded(
                      child: Text(
                        item.name,
                        key: Key('subagent_name_${item.id}'),
                        style: TextStyle(
                          color: fgStrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    if (item.depth > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: isDark
                              ? CompozyColors.surface2
                              : CompozyColorsLight.surface2,
                          borderRadius: CompozyRadius.pill,
                        ),
                        child: Text(
                          'L${item.depth}',
                          style: TextStyle(
                            color: muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),

                // Brief paragraph if present
                if (item.brief != null && item.brief!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.brief!,
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // Bottom row: Model badge and runtime tags
                if (item.model != null || item.runtimeTag != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Model badge
                      if (item.model != null)
                        Container(
                          key: Key('subagent_model_${item.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? CompozyColors.canvasSoft
                                : CompozyColorsLight.canvasSoft,
                            borderRadius: CompozyRadius.input,
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: Text(
                            item.model!,
                            style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                      // Runtime tag
                      if (item.runtimeTag != null)
                        Container(
                          key: Key('subagent_runtime_tag_${item.id}'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? CompozyColors.surface2
                                : CompozyColorsLight.surface2,
                            borderRadius: CompozyRadius.input,
                            border: Border.all(color: borderColor, width: 1),
                          ),
                          child: Text(
                            item.runtimeTag!,
                            style: TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Backward compatibility alias.
typedef SubagentHierarchyDrawer = SubagentsDrawer;
