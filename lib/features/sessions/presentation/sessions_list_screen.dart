import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/presentation/widgets/compozy_empty_state.dart';
import '../../../core/presentation/widgets/compozy_error_state.dart';
import '../../../core/presentation/widgets/compozy_skeleton.dart';
import '../../../core/theme/compozy_theme.dart';
import '../../connection/presentation/connection_banner.dart';
import '../data/session_repository_impl.dart';
import '../domain/models/session.dart';
import 'session_chat_screen.dart';
import 'widgets/session_badges.dart';

/// Screen displaying the list of active/idle/stopped CompozyOS sessions
/// strictly styled after board.jpg and hero.jpg, with "Needs you" attention triage,
/// search filtering, and theme-aware design tokens.
class SessionsListScreen extends ConsumerStatefulWidget {
  final ValueChanged<Session>? onSessionTap;

  const SessionsListScreen({
    super.key,
    this.onSessionTap,
  });

  @override
  ConsumerState<SessionsListScreen> createState() => _SessionsListScreenState();
}

class _SessionsListScreenState extends ConsumerState<SessionsListScreen> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

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
    final selectedFilter = ref.watch(sessionFilterProvider);
    final sessionsAsync = ref.watch(sessionsProvider);
    final isOnline = ref.watch(connectionStatusProvider).value ?? true;

    return Scaffold(
      backgroundColor: palette.desk,
      body: Column(
        children: [
          // Connection banner if offline
          if (!isOnline)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ConnectionBanner(),
            ),

          // Search Field
          _buildSearchField(palette),

          // Filter row
          _buildFilterRow(context, ref, palette, selectedFilter),

          // Main list area with pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              key: const Key('sessions_refresh_indicator'),
              color: palette.fgStrong,
              backgroundColor: palette.elevated,
              onRefresh: () async {
                ref.invalidate(sessionsProvider);
                await ref.read(sessionsProvider.future);
              },
              child: sessionsAsync.when(
                loading: () => const CompozySkeletonList(
                  itemCount: 5,
                  itemHeight: 96,
                ),
                error: (error, stack) => CompozyErrorState(
                  title: 'Failed to load sessions',
                  message:
                      "We couldn't reach the daemon. Check the connection and try again.",
                  details: error.toString(),
                  onRetry: () => ref.invalidate(sessionsProvider),
                ),
                data: (sessions) {
                  // 1. Filter by category chip
                  final chipFiltered = sessions.where((s) {
                    final normalized = selectedFilter.toLowerCase();
                    if (normalized == 'all') return true;
                    if (normalized == 'needs you' || normalized == 'needs_you') {
                      return isSessionAwaitingUser(s.state);
                    }
                    return s.state.toLowerCase() == normalized;
                  }).toList();

                  // 2. Filter by search query
                  final query = _searchQuery.trim().toLowerCase();
                  final searchFiltered = query.isEmpty
                      ? chipFiltered
                      : chipFiltered.where((s) {
                          return s.name.toLowerCase().contains(query) ||
                              s.agent.toLowerCase().contains(query) ||
                              s.id.toLowerCase().contains(query);
                        }).toList();

                  // 3. Sort: "Needs you" attention items first, then chronological
                  final sortedSessions = List<Session>.from(searchFiltered);
                  sortedSessions.sort((a, b) {
                    final aNeeds = isSessionAwaitingUser(a.state);
                    final bNeeds = isSessionAwaitingUser(b.state);
                    if (aNeeds && !bNeeds) return -1;
                    if (!aNeeds && bNeeds) return 1;
                    return b.updatedAt.compareTo(a.updatedAt);
                  });

                  if (sortedSessions.isEmpty) {
                    return _buildEmptyState(
                      query: query,
                      filter: selectedFilter,
                      hasAnySessions: sessions.isNotEmpty,
                    );
                  }

                  return _buildSessionList(sortedSessions);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(CompozyPalette palette) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
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
                key: const Key('sessions_search_field'),
                controller: _searchController,
                style: TextStyle(color: palette.fg, fontSize: 13),
                cursorColor: palette.fgStrong,
                decoration: InputDecoration(
                  hintText: 'Search sessions by name, agent, or id...',
                  hintStyle: TextStyle(color: palette.subtle, fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            if (_searchQuery.isNotEmpty)
              Semantics(
                button: true,
                label: 'Clear search query',
                child: IconButton(
                  key: const Key('sessions_search_clear_button'),
                  icon: Icon(Icons.clear, size: 16, color: palette.muted),
                  tooltip: 'Clear search',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(
    BuildContext context,
    WidgetRef ref,
    CompozyPalette palette,
    String selectedFilter,
  ) {
    const filters = ['All', 'Needs you', 'Active', 'Idle', 'Stopped'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected =
                selectedFilter.toLowerCase() == filter.toLowerCase();
            final isNeedsYouChip = filter == 'Needs you';

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key(
                  'filter_chip_${filter.toLowerCase().replaceAll(' ', '_')}',
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isNeedsYouChip) ...[
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Text(filter),
                  ],
                ),
                selected: isSelected,
                selectedColor: isNeedsYouChip
                    ? palette.accent.withValues(alpha: 0.16)
                    : palette.elevated,
                backgroundColor: palette.card,
                side: BorderSide(
                  color: isSelected
                      ? (isNeedsYouChip
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
                      ? (isNeedsYouChip ? palette.accent : palette.fgStrong)
                      : palette.muted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  fontSize: 13,
                ),
                onSelected: (selected) {
                  if (selected) {
                    ref.read(sessionFilterProvider.notifier).state = filter;
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSessionList(List<Session> sessions) {
    return ListView.separated(
      key: const Key('sessions_list_view'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionCard(
          session: session,
          onTap: () {
            if (widget.onSessionTap != null) {
              widget.onSessionTap!(session);
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SessionChatScreen(session: session),
                ),
              );
            }
          },
        );
      },
    );
  }

  Widget _buildEmptyState({
    required String query,
    required String filter,
    required bool hasAnySessions,
  }) {
    if (query.isNotEmpty) {
      return CompozyEmptyState(
        icon: Icons.search_off_outlined,
        title: 'No matching sessions',
        message: 'No sessions match "$query". Try a different search term.',
        actionLabel: 'Clear search',
        onAction: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
          });
        },
      );
    }

    if (filter != 'All') {
      return CompozyEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No sessions found',
        message: 'No sessions found with state "$filter".',
        actionLabel: 'Clear filter',
        onAction: () {
          ref.read(sessionFilterProvider.notifier).state = 'All';
        },
      );
    }

    return CompozyEmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No sessions found',
      message: 'No active or recorded sessions in this workspace.',
      actionLabel: 'Refresh',
      onAction: () {
        ref.invalidate(sessionsProvider);
      },
    );
  }
}

/// Visual card representing one session in the list, strictly mirroring board.jpg.
/// Prominently prioritizes session name and "Needs you" attention triage.
class _SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback? onTap;

  const _SessionCard({
    required this.session,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isNeedsYou = isSessionAwaitingUser(session.state);

    return Container(
      key: Key('session_card_${session.id}'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Primary Line: Session Name prominently in high contrast + State badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        session.name,
                        style: TextStyle(
                          color: palette.fgStrong,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StateBadge(state: session.state),
                  ],
                ),
                const SizedBox(height: 12),

                // Bottom Footer: Agent Avatar + Agent badge + demoted Monospace session.id + Relative timestamp
                Row(
                  children: [
                    AgentAvatar(
                      agent: session.agent,
                      state: session.state,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    AgentBadge(agent: session.agent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.id,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: palette.subtle,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatRelativeTime(session.updatedAt),
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative || difference.inSeconds < 45) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
