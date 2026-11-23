import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/compozy_theme.dart';
import '../../connection/presentation/connection_banner.dart';
import '../data/session_repository_impl.dart';
import '../domain/models/session.dart';
import 'session_chat_screen.dart';
import 'widgets/session_badges.dart';

/// Screen displaying the list of active/idle/stopped CompozyOS sessions
/// strictly styled after board.jpg and hero.jpg.
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
          // Connection banner if offline
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
              backgroundColor: CompozyColors.elevated,
              onRefresh: () async {
                ref.invalidate(sessionsProvider);
                await ref.read(sessionsProvider.future);
              },
              child: filteredAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                backgroundColor: CompozyColors.card,
                side: BorderSide(
                  color: isSelected
                      ? CompozyColors.lineStrong
                      : CompozyColors.line,
                  width: 1,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: CompozyRadius.pill,
                ),
                labelStyle: TextStyle(
                  color: isSelected
                      ? CompozyColors.fgStrong
                      : CompozyColors.muted,
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
            if (onSessionTap != null) {
              onSessionTap!(session);
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
                      size: 44,
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
                      size: 44,
                      color: CompozyColors.danger,
                    ),
                    SizedBox(height: 16),
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
                    // Monochrome inverted primary action button
                    ElevatedButton(
                      onPressed: () => ref.invalidate(sessionsProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CompozyColors.primary,
                        foregroundColor: CompozyColors.primaryInk,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: const RoundedRectangleBorder(
                          borderRadius: CompozyRadius.pill,
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
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
}

/// Visual card representing one session in the list, strictly mirroring board.jpg.
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
        color: CompozyColors.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: CompozyColors.line, width: 1),
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
                // Top Header: Context tag + State badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        session.id,
                        style: const TextStyle(
                          color: CompozyColors.subtle,
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StateBadge(state: session.state),
                  ],
                ),
                const SizedBox(height: 8),

                // Main Title: Session Name in high contrast
                Text(
                  session.name,
                  style: const TextStyle(
                    color: CompozyColors.fgStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 12),

                // Bottom Footer: Agent Avatar + Agent pill + Relative timestamp
                Row(
                  children: [
                    AgentAvatar(
                      agent: session.agent,
                      state: session.state,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    AgentBadge(agent: session.agent),
                    const Spacer(),
                    Text(
                      _formatRelativeTime(session.updatedAt),
                      style: const TextStyle(
                        color: CompozyColors.muted,
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
