import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/presentation/widgets/compozy_empty_state.dart';
import '../../../core/presentation/widgets/compozy_error_state.dart';
import '../../../core/presentation/widgets/compozy_skeleton.dart';
import '../../../core/theme/compozy_theme.dart';
import '../data/agents_repository_provider.dart';
import 'widgets/agent_card.dart';
import 'widgets/agent_details_sheet.dart';

export 'widgets/agent_avatar.dart';
export 'widgets/agent_card.dart';
export 'widgets/agent_details_sheet.dart';
export 'widgets/agent_status_badge.dart';

/// Screen displaying the read-only CompozyOS agent presence hub.
/// Joins static agent catalog with dynamic session presence, answering
/// "who is working and who is blocked on me" at a glance.
class AgentsScreen extends ConsumerStatefulWidget {
  const AgentsScreen({super.key});

  @override
  ConsumerState<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends ConsumerState<AgentsScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final presenceAsync = ref.watch(agentsPresenceProvider);
    final filteredAsync = ref.watch(filteredAgentsProvider);
    final selectedFilter = ref.watch(agentFilterProvider);
    final searchQuery = ref.watch(agentSearchProvider);

    return Scaffold(
      backgroundColor: palette.desk,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Title and Live Presence Summary Counters
          _buildHeader(context, presenceAsync),

          // Search Field
          _buildSearchField(palette),

          // Filter Chips Row
          _buildFilterRow(palette, selectedFilter),

          // Main Presence List with Pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              key: const Key('agents_refresh_indicator'),
              color: palette.fgStrong,
              backgroundColor: palette.card,
              onRefresh: () async {
                ref.invalidate(agentsPresenceProvider);
                await ref.read(agentsPresenceProvider.future);
              },
              child: filteredAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: CompozySkeletonList(
                    key: Key('agents_loading_skeletons'),
                    itemCount: 5,
                    itemHeight: 110,
                  ),
                ),
                error: (error, _) => _buildErrorView(ref, error),
                data: (agents) {
                  if (agents.isEmpty) {
                    final hasFilterOrSearch =
                        selectedFilter != 'All' || searchQuery.trim().isNotEmpty;
                    return _buildEmptyView(ref, hasFilterOrSearch: hasFilterOrSearch);
                  }
                  return _buildAgentsContent(context, agents);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<List<AgentPresence>> presenceAsync,
  ) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Agents',
                style: TextStyle(
                  color: palette.fgStrong,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(width: 8),
              presenceAsync.maybeWhen(
                data: (all) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.surface2,
                    borderRadius: CompozyRadius.pill,
                    border: Border.all(color: palette.line, width: 1),
                  ),
                  child: Text(
                    '${all.length}',
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Summary Metrics Strip: Active vs Total, Needs you
          presenceAsync.maybeWhen(
            data: (all) {
              final workingCount = all.where((a) => a.isWorking).length;
              final needsYouCount = all.where((a) => a.isNeedsYou).length;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Working Signal Pill
                    _buildSummaryPill(
                      palette: palette,
                      dotColor: palette.success,
                      label: '$workingCount working',
                      isSelected: ref.watch(agentFilterProvider) == 'Working',
                      onTap: () {
                        ref.read(agentFilterProvider.notifier).state =
                            ref.read(agentFilterProvider) == 'Working' ? 'All' : 'Working';
                      },
                    ),
                    const SizedBox(width: 8),

                    // Needs Attention Signal Pill
                    _buildSummaryPill(
                      palette: palette,
                      dotColor: palette.accent,
                      label: '$needsYouCount needs attention',
                      highlightAccent: needsYouCount > 0,
                      isSelected: ref.watch(agentFilterProvider) == 'Needs you',
                      onTap: () {
                        ref.read(agentFilterProvider.notifier).state =
                            ref.read(agentFilterProvider) == 'Needs you' ? 'All' : 'Needs you';
                      },
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryPill({
    required CompozyPalette palette,
    required Color dotColor,
    required String label,
    required VoidCallback onTap,
    bool highlightAccent = false,
    bool isSelected = false,
  }) {
    return InkWell(
      borderRadius: CompozyRadius.pill,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: highlightAccent
              ? palette.accent.withValues(alpha: 0.12)
              : (isSelected ? palette.elevated : palette.card),
          borderRadius: CompozyRadius.pill,
          border: Border.all(
            color: highlightAccent
                ? palette.accent.withValues(alpha: 0.45)
                : (isSelected ? palette.lineStrong : palette.line),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: highlightAccent ? palette.accent : palette.fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(CompozyPalette palette) {
    final query = ref.watch(agentSearchProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: CompozyRadius.input,
          border: Border.all(color: palette.line, width: 1),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Icon(Icons.search, size: 18, color: palette.muted),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: const Key('agents_search_field'),
                controller: _searchController,
                style: TextStyle(color: palette.fg, fontSize: 13),
                cursorColor: palette.fgStrong,
                decoration: InputDecoration(
                  hintText: 'Search agents by name, label, or category...',
                  hintStyle: TextStyle(color: palette.subtle, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (val) {
                  ref.read(agentSearchProvider.notifier).state = val;
                },
              ),
            ),
            if (query.isNotEmpty)
              Semantics(
                button: true,
                label: 'Clear search query',
                child: IconButton(
                  key: const Key('agents_search_clear_button'),
                  icon: Icon(Icons.clear, size: 16, color: palette.muted),
                  tooltip: 'Clear search',
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () {
                    _searchController.clear();
                    ref.read(agentSearchProvider.notifier).state = '';
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(CompozyPalette palette, String selectedFilter) {
    const filters = ['All', 'Working', 'Needs you', 'Idle'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected = selectedFilter.toLowerCase() == filter.toLowerCase();
            final isNeedsYou = filter == 'Needs you';
            final isWorking = filter == 'Working';

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                selected: isSelected,
                button: true,
                label: '$filter filter',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    child: ChoiceChip(
                      key: Key('filter_chip_${filter.toLowerCase().replaceAll(' ', '_')}'),
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isNeedsYou || isWorking) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isNeedsYou ? palette.accent : palette.success,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(filter),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: isNeedsYou
                          ? palette.accent.withValues(alpha: 0.16)
                          : palette.elevated,
                      backgroundColor: palette.card,
                      side: BorderSide(
                        color: isSelected
                            ? (isNeedsYou
                                ? palette.accent.withValues(alpha: 0.5)
                                : palette.lineStrong)
                            : palette.line,
                        width: 1,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: CompozyRadius.pill,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? (isNeedsYou ? palette.accent : palette.fgStrong)
                            : palette.muted,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 13,
                      ),
                      onSelected: (selected) {
                        if (selected) {
                          ref.read(agentFilterProvider.notifier).state = filter;
                        }
                      },
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildAgentsContent(BuildContext context, List<AgentPresence> agents) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final textScaler = MediaQuery.textScalerOf(context);
        final cardExtent = textScaler.scale(180.0).clamp(170.0, 360.0);

        if (isMobile) {
          return ListView.separated(
            key: const Key('agents_list_view'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: agents.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final presence = agents[index];
              return AgentCard(
                presence: presence,
                onTap: () => _handleCardTap(context, presence),
              );
            },
          );
        } else {
          return GridView.builder(
            key: const Key('agents_grid_view'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 480,
              mainAxisExtent: cardExtent,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: agents.length,
            itemBuilder: (context, index) {
              final presence = agents[index];
              return AgentCard(
                presence: presence,
                onTap: () => _handleCardTap(context, presence),
              );
            },
          );
        }
      },
    );
  }

  void _handleCardTap(BuildContext context, AgentPresence presence) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => AgentDetailsSheet(presence: presence),
    );
  }

  Widget _buildEmptyView(WidgetRef ref, {required bool hasFilterOrSearch}) {
    if (hasFilterOrSearch) {
      return CompozyEmptyState(
        key: const Key('agents_empty_view'),
        icon: Icons.filter_alt_off_outlined,
        title: 'No matching agents',
        message: 'No agents match your active filter or search criteria.',
        actionLabel: 'Clear filters',
        onAction: () {
          _searchController.clear();
          ref.read(agentFilterProvider.notifier).state = 'All';
          ref.read(agentSearchProvider.notifier).state = '';
        },
      );
    }

    return CompozyEmptyState(
      key: const Key('agents_empty_view'),
      icon: Icons.smart_toy_outlined,
      title: 'No agents found',
      message: 'No agent definitions were returned by the CompozyOS daemon.',
      actionLabel: 'Retry',
      onAction: () => ref.invalidate(agentsPresenceProvider),
    );
  }

  Widget _buildErrorView(WidgetRef ref, Object error) {
    return CompozyErrorState(
      key: const Key('agents_error_view'),
      title: 'Failed to load agents',
      message: 'Unable to retrieve agents from CompozyOS daemon. Check connection.',
      details: error.toString(),
      onRetry: () => ref.invalidate(agentsPresenceProvider),
      retryLabel: 'Retry',
    );
  }
}
