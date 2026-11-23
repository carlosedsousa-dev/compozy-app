import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/compozy_theme.dart';
import '../../connection/presentation/connection_banner.dart';
import '../data/session_repository_impl.dart';
import '../domain/models/session.dart';

/// Screen displaying the list of active/idle/stopped CompozyOS sessions
/// with filtering chips and pull-to-refresh.
class SessionsListScreen extends ConsumerWidget {
  final ValueChanged<Session>? onSessionTap;

  const SessionsListScreen({
    super.key,
    this.onSessionTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(sessionFilterProvider);
    final filteredAsync = ref.watch(filteredSessionsProvider);
    final isOnline = ref.watch(connectionStatusProvider).value ?? true;

    return Scaffold(
      backgroundColor: CompozyColors.desk,
      body: Column(
        children: [
          // If offline, display connection banner
          if (!isOnline)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ConnectionBanner(),
            ),

          // Filter row
          _buildFilterRow(context, ref, selectedFilter),

          // Main list area with pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              key: const Key('sessions_refresh_indicator'),
              color: CompozyColors.fgStrong,
              backgroundColor: CompozyColors.surface2,
              onRefresh: () async {
                ref.invalidate(sessionsProvider);
                await ref.read(sessionsProvider.future);
              },
              child: filteredAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: CompozyColors.fg,
                  ),
                ),
                error: (error, stack) => _buildErrorView(ref, error),
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return _buildEmptyView();
                  }
                  return _buildSessionList(sessions);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(
    BuildContext context,
    WidgetRef ref,
    String selectedFilter,
  ) {
    const filters = ['All', 'Active', 'Idle', 'Stopped'];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((filter) {
            final isSelected =
                selectedFilter.toLowerCase() == filter.toLowerCase();

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('filter_chip_${filter.toLowerCase()}'),
                label: Text(filter),
                selected: isSelected,
                selectedColor: CompozyColors.elevated,
                backgroundColor: CompozyColors.surface2,
                side: BorderSide(
                  color: isSelected
                      ? CompozyColors.lineStrong
                      : CompozyColors.line,
                ),
                labelStyle: TextStyle(
                  color: isSelected
                      ? CompozyColors.fgStrong
                      : CompozyColors.muted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
          onTap: () => onSessionTap?.call(session),
        );
      },
    );
  }

  Widget _buildEmptyView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: CompozyColors.muted,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No sessions found',
                      style: TextStyle(
                        color: CompozyColors.fgStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No active or recorded sessions in this workspace.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: CompozyColors.muted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorView(WidgetRef ref, Object error) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: CompozyColors.danger,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load sessions',
                      style: TextStyle(
                        color: CompozyColors.fgStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: CompozyColors.muted,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () => ref.invalidate(sessionsProvider),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: CompozyColors.fg,
                        side: const BorderSide(color: CompozyColors.line),
                        shape: const RoundedRectangleBorder(
                          borderRadius: CompozyRadius.pill,
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Visual card representing one session in the list.
class _SessionCard extends StatelessWidget {
  final Session session;
  final VoidCallback? onTap;

  const _SessionCard({
    required this.session,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('session_card_${session.id}'),
      decoration: BoxDecoration(
        color: CompozyColors.canvas,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: CompozyColors.line, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: CompozyRadius.card,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Session name + State badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        session.name,
                        style: const TextStyle(
                          color: CompozyColors.fgStrong,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StateBadge(state: session.state),
                  ],
                ),
                const SizedBox(height: 12),

                // Subtitle: Agent pill + Relative time
                Row(
                  children: [
                    _AgentBadge(agent: session.agent),
                    const Spacer(),
                    Text(
                      _formatRelativeTime(session.updatedAt),
                      style: const TextStyle(
                        color: CompozyColors.muted,
                        fontSize: 12,
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

/// Status badge pill reflecting session lifecycle state.
class _StateBadge extends StatelessWidget {
  final String state;

  const _StateBadge({required this.state});

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
class _AgentBadge extends StatelessWidget {
  final String agent;

  const _AgentBadge({required this.agent});

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
