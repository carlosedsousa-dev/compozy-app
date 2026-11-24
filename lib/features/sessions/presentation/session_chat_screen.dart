import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/presentation/compozy_feedback.dart';
import '../../../core/presentation/widgets/compozy_empty_state.dart';
import '../../../core/presentation/widgets/compozy_error_state.dart';
import '../../../core/presentation/widgets/compozy_skeleton.dart';
import '../../../core/theme/compozy_theme.dart';
import '../data/session_repository_impl.dart';
import '../domain/models/session.dart';
import '../domain/models/turn.dart';
import 'session_draft_provider.dart';
import 'widgets/approval_card.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/session_badges.dart';
import 'widgets/subagents_drawer.dart';
import 'widgets/tool_execution_pill.dart';

/// Screen displaying the conversation turn transcript for a CompozyOS session,
/// collapsible tool execution pills, and an interactive prompt input container,
/// strictly mirroring hero.jpg, handoff.jpg, and REFERENCE_GUIDE.md.
class SessionChatScreen extends ConsumerStatefulWidget {
  final Session session;
  final List<Turn>? initialTurns;

  const SessionChatScreen({
    super.key,
    required this.session,
    this.initialTurns,
  });

  @override
  ConsumerState<SessionChatScreen> createState() => _SessionChatScreenState();
}

class _SessionChatScreenState extends ConsumerState<SessionChatScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final TextEditingController _promptController;
  late final FocusNode _promptFocusNode;
  late final ScrollController _scrollController;
  final List<Turn> _optimisticTurns = [];
  bool _isSubmitting = false;
  bool _canSend = false;

  // Scroll-to-latest and unread tracking
  bool _showScrollToLatest = false;
  bool _hasUnreadWhileAway = false;

  // Real-time live streaming state (US-006.AC-3, US-006.AC-4)
  String? _currentSessionState;
  String? _streamingText;
  String? _streamingTurnId;
  final Map<String, SessionToolExecutionEvent> _activeToolExecutions = {};
  final Map<String, SessionApprovalRequestEvent> _pendingApprovals = {};
  List<Turn>? _streamTurns;
  bool _isStreaming = false;

  bool get _isSessionBusy {
    final state = (_currentSessionState ?? widget.session.state).toLowerCase();
    return state == 'busy' || state == 'waiting' || _isStreaming;
  }

  bool get _isSessionStopped {
    final state = (_currentSessionState ?? widget.session.state).toLowerCase();
    return state == 'stopped' || state == 'failed' || state == 'canceled';
  }

  @override
  void initState() {
    super.initState();
    final initialDraft = ref.read(sessionDraftPromptProvider(widget.session.id));
    _promptController = TextEditingController(text: initialDraft);
    _promptFocusNode = FocusNode();
    _scrollController = ScrollController();
    _promptController.addListener(_onTextChanged);
    _canSend = initialDraft.trim().isNotEmpty &&
        !_isSessionBusy &&
        !_isSessionStopped &&
        !_isSubmitting;
  }

  @override
  void dispose() {
    _promptController.removeListener(_onTextChanged);
    _promptController.dispose();
    _promptFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _promptController.text;
    ref.read(sessionDraftPromptProvider(widget.session.id).notifier).state =
        text;
    final hasContent = text.trim().isNotEmpty;
    final canSend =
        hasContent && !_isSessionBusy && !_isSessionStopped && !_isSubmitting;
    if (canSend != _canSend) {
      setState(() {
        _canSend = canSend;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendPrompt() async {
    final text = _promptController.text.trim();
    if (text.isEmpty || _isSessionBusy || _isSessionStopped || _isSubmitting) {
      return;
    }

    compozyHaptic();

    final optimisticTurn = Turn(
      turnId: 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      userMessage: text,
      agentMessage: null,
      status: 'queued',
      toolCalls: const [],
    );

    setState(() {
      _optimisticTurns.add(optimisticTurn);
      _promptController.clear();
      _canSend = false;
      _isSubmitting = true;
    });

    ref.read(sessionDraftPromptProvider(widget.session.id).notifier).state = '';

    _scrollToBottom();

    try {
      final repository = ref.read(sessionRepositoryProvider);
      await repository.sendPrompt(widget.session.id, text);

      ref.invalidate(sessionHistoryProvider(widget.session.id));
      await ref.read(sessionHistoryProvider(widget.session.id).future);

      if (mounted) {
        setState(() {
          _optimisticTurns.remove(optimisticTurn);
          _streamTurns = null;
          _isSubmitting = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _optimisticTurns.remove(optimisticTurn);
          _promptController.text = text;
          _canSend = true;
          _isSubmitting = false;
        });

        ref.read(sessionDraftPromptProvider(widget.session.id).notifier).state =
            text;

        final String message;
        if (e is SessionBusyException) {
          message = 'Session is busy. Please wait before sending another prompt.';
        } else if (e is ArgumentError) {
          message = e.message.toString();
        } else {
          message = 'Failed to send prompt: ${e.toString()}';
        }

        showCompozySnack(context, message, isError: true);
      }
    }
  }

  void _handleStreamEvent(SessionStreamEvent event) {
    if (_showScrollToLatest) {
      _hasUnreadWhileAway = true;
    }

    if (event is SessionTextDeltaEvent) {
      setState(() {
        _isStreaming = true;
        _streamingTurnId ??= event.turnId;
        _streamingText = (_streamingText ?? '') + event.textDelta;
      });
      if (!_showScrollToLatest) _scrollToBottom();
    } else if (event is SessionApprovalRequestEvent) {
      setState(() {
        final key = event.approvalId ??
            event.toolName ??
            'approval_${DateTime.now().millisecondsSinceEpoch}';
        _pendingApprovals[key] = event;
      });
      if (!_showScrollToLatest) _scrollToBottom();
    } else if (event is SessionToolExecutionEvent) {
      if (event.isWaitingForApproval) {
        setState(() {
          final key = event.toolCallId ?? event.toolName;
          _pendingApprovals[key] = SessionApprovalRequestEvent(
            toolName: event.toolName,
            description:
                'Permission approval requested to execute ${event.toolName}.',
            input: event.input,
            approvalId: event.toolCallId,
            sessionId: event.sessionId,
            turnId: event.turnId,
          );
        });
        if (!_showScrollToLatest) _scrollToBottom();
      } else {
        setState(() {
          final key = event.toolCallId ?? event.toolName;
          _activeToolExecutions[key] = event;
        });
        if (!_showScrollToLatest) _scrollToBottom();
      }
    } else if (event is SessionTurnEvent) {
      setState(() {
        if (event.status == 'started' || event.status == 'turn_start') {
          _isStreaming = true;
          _streamingTurnId = event.turnId;
          _streamingText = '';
          _activeToolExecutions.clear();
        } else if (event.status == 'completed' ||
            event.status == 'turn_complete' ||
            event.status == 'turn_completed') {
          if (event.turn != null) {
            _streamTurns ??= List.from(widget.initialTurns ??
                ref.read(sessionHistoryProvider(widget.session.id)).value ??
                []);
            final existingIdx = _streamTurns!
                .indexWhere((t) => t.turnId == event.turn!.turnId);
            if (existingIdx >= 0) {
              _streamTurns![existingIdx] = event.turn!;
            } else {
              _streamTurns!.add(event.turn!);
            }
          } else if (_streamingText != null && _streamingText!.isNotEmpty) {
            _streamTurns ??= List.from(widget.initialTurns ??
                ref.read(sessionHistoryProvider(widget.session.id)).value ??
                []);
            final turnId = event.turnId ??
                _streamingTurnId ??
                'turn_${DateTime.now().millisecondsSinceEpoch}';
            _streamTurns!.add(Turn(
              turnId: turnId,
              userMessage: event.userMessage,
              agentMessage: event.agentMessage ?? _streamingText,
              status: 'completed',
              toolCalls:
                  _activeToolExecutions.values.map((e) => e.toolName).toList(),
            ));
          }
          _streamingText = null;
          _streamingTurnId = null;
          _activeToolExecutions.clear();
          _isStreaming = false;
          if (event.userMessage != null) {
            _optimisticTurns
                .removeWhere((t) => t.userMessage == event.userMessage);
          }
        }
      });
      if (!_showScrollToLatest) _scrollToBottom();
    } else if (event is SessionTranscriptSnapshotEvent) {
      setState(() {
        _streamTurns = List.from(event.turns);
        _streamingText = null;
        _streamingTurnId = null;
        _activeToolExecutions.clear();
        _isStreaming = false;
      });
      if (!_showScrollToLatest) _scrollToBottom();
    } else if (event is SessionStateChangedEvent) {
      setState(() {
        _currentSessionState = event.state;
      });
    }
  }

  Future<void> _handleApprovalDecision({
    required String approvalKey,
    required bool approved,
    String? toolName,
  }) async {
    setState(() {
      _pendingApprovals.remove(approvalKey);
    });

    try {
      final repository = ref.read(sessionRepositoryProvider);
      await repository.respondToApproval(
        widget.session.id,
        approved: approved,
        approvalId: approvalKey,
      );
    } catch (_) {}

    if (mounted) {
      showCompozySnack(
        context,
        approved ? 'Tool execution approved.' : 'Tool execution rejected.',
        isError: false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SessionStreamEvent>>(
      sessionStreamProvider(widget.session.id),
      (previous, next) {
        next.whenData((event) {
          _handleStreamEvent(event);
        });
      },
    );

    final palette = context.palette;
    final historyAsync = ref.watch(sessionHistoryProvider(widget.session.id));

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: palette.desk,
      appBar: _buildTopAppBar(context, palette),
      endDrawer: SubagentsDrawer(
        session: widget.session,
        onClose: () => Navigator.of(context).maybePop(),
      ),
      body: Column(
        children: [
          // Guidance banner if session is in non-promptable state
          if (_isSessionStopped)
            _buildGuidanceBanner(
              palette: palette,
              icon: Icons.stop_circle_outlined,
              message: 'Session is stopped. Prompting is disabled.',
              color: palette.danger,
            )
          else if (_isSessionBusy)
            _buildGuidanceBanner(
              palette: palette,
              icon: Icons.hourglass_top_outlined,
              message: 'Session is currently busy running a turn.',
              color: palette.warning,
            ),

          // Main transcript area with Scroll-to-latest button overlay
          Expanded(
            child: Stack(
              children: [
                widget.initialTurns != null
                    ? _buildTranscriptView(palette, widget.initialTurns!)
                    : historyAsync.when(
                        loading: () => const CompozySkeletonList(
                          itemCount: 4,
                          itemHeight: 80,
                        ),
                        error: (error, stack) => _buildErrorTranscript(error),
                        data: (history) => _buildTranscriptView(palette, history),
                      ),
                if (_showScrollToLatest)
                  Positioned(
                    right: 16,
                    bottom: 12,
                    child: _buildScrollToLatestButton(palette),
                  ),
              ],
            ),
          ),

          // Docked prompt input bar container (mirrors hero.jpg)
          _buildPromptInputBar(palette),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(
    BuildContext context,
    CompozyPalette palette,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Container(
        decoration: BoxDecoration(
          color: palette.canvas,
          border: Border(
            bottom: BorderSide(color: palette.line, width: 1),
          ),
        ),
        child: AppBar(
          toolbarHeight: 52,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Semantics(
            button: true,
            label: 'Back to sessions',
            child: IconButton(
              key: const Key('chat_back_button'),
              icon: Icon(Icons.arrow_back, color: palette.fg, size: 20),
              tooltip: 'Back to sessions',
              constraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 48,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  widget.session.name,
                  style: TextStyle(
                    color: palette.fgStrong,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              AgentBadge(agent: widget.session.agent),
              const SizedBox(width: 8),
              StateBadge(state: _currentSessionState ?? widget.session.state),
              const SizedBox(width: 4),
              Semantics(
                button: true,
                label: 'Subagents Hierarchy',
                child: IconButton(
                  key: const Key('chat_subagents_button'),
                  icon: Icon(
                    Icons.account_tree_outlined,
                    size: 20,
                    color: palette.fg,
                  ),
                  tooltip: 'Subagents Hierarchy',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () {
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidanceBanner({
    required CompozyPalette palette,
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface2,
        border: Border(
          bottom: BorderSide(color: palette.line, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToLatestButton(CompozyPalette palette) {
    return Semantics(
      button: true,
      label: 'Scroll to latest messages',
      child: Material(
        color: palette.elevated,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          key: const Key('chat_scroll_to_latest_button'),
          customBorder: const CircleBorder(),
          onTap: () {
            setState(() {
              _hasUnreadWhileAway = false;
              _showScrollToLatest = false;
            });
            _scrollToBottom();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: palette.fgStrong,
                    size: 22,
                  ),
                  if (_hasUnreadWhileAway)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        key: const Key('scroll_to_latest_unread_dot'),
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: palette.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTranscriptView(CompozyPalette palette, List<Turn> turns) {
    final currentTurns = _streamTurns ?? turns;
    final allTurns = [...currentTurns, ..._optimisticTurns];
    final activeToolEvents = _activeToolExecutions.values.toList();
    final pendingApprovalEvents = _pendingApprovals.values.toList();
    final hasStreamingBubble =
        _streamingText != null && _streamingText!.isNotEmpty;
    final isStreamingWaiting = _isStreaming &&
        !hasStreamingBubble &&
        activeToolEvents.isEmpty;
    final hasLiveItems = activeToolEvents.isNotEmpty ||
        hasStreamingBubble ||
        pendingApprovalEvents.isNotEmpty ||
        isStreamingWaiting;

    return RefreshIndicator(
      key: const Key('chat_refresh_indicator'),
      color: palette.fgStrong,
      backgroundColor: palette.elevated,
      onRefresh: () async {
        ref.invalidate(sessionHistoryProvider(widget.session.id));
        await ref.read(sessionHistoryProvider(widget.session.id).future);
        setState(() {
          _streamTurns = null;
        });
      },
      child: (allTurns.isEmpty && !hasLiveItems)
          ? _buildEmptyTranscript()
          : NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.maxScrollExtent > 0) {
                  final distanceFromBottom =
                      notification.metrics.maxScrollExtent -
                          notification.metrics.pixels;
                  final isAway = distanceFromBottom > 200;
                  if (isAway != _showScrollToLatest) {
                    setState(() {
                      _showScrollToLatest = isAway;
                      if (!isAway) {
                        _hasUnreadWhileAway = false;
                      }
                    });
                  }
                }
                return false;
              },
              child: ListView.separated(
                key: const Key('transcript_list_view'),
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                itemCount: allTurns.length +
                    activeToolEvents.length +
                    (hasStreamingBubble ? 1 : 0) +
                    (isStreamingWaiting ? 1 : 0) +
                    pendingApprovalEvents.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  if (index < allTurns.length) {
                    final turn = allTurns[index];
                    return TurnWidget(
                      turn: turn,
                      agentName: widget.session.agent,
                      onApprovalDecision: (approved) =>
                          _handleApprovalDecision(
                        approvalKey: turn.turnId,
                        approved: approved,
                        toolName: turn.toolCalls.isNotEmpty
                            ? turn.toolCalls.first
                            : null,
                      ),
                    );
                  }

                  final liveToolIndex = index - allTurns.length;
                  if (liveToolIndex < activeToolEvents.length) {
                    final toolEvent = activeToolEvents[liveToolIndex];
                    return ToolExecutionPill.fromEvent(toolEvent);
                  }

                  final afterLiveToolsIndex =
                      liveToolIndex - activeToolEvents.length;
                  if (hasStreamingBubble && afterLiveToolsIndex == 0) {
                    return AgentChatBubble(
                      key: const Key('streaming_agent_bubble'),
                      message: _streamingText!,
                      agentName: widget.session.agent,
                      isStreaming: true,
                    );
                  }

                  if (isStreamingWaiting &&
                      afterLiveToolsIndex == (hasStreamingBubble ? 1 : 0)) {
                    return _buildThinkingIndicator(palette);
                  }

                  final approvalIndex = afterLiveToolsIndex -
                      (hasStreamingBubble ? 1 : 0) -
                      (isStreamingWaiting ? 1 : 0);
                  if (approvalIndex >= 0 &&
                      approvalIndex < pendingApprovalEvents.length) {
                    final approvalEvent =
                        pendingApprovalEvents[approvalIndex];
                    final key = approvalEvent.approvalId ??
                        approvalEvent.toolName ??
                        'approval_$approvalIndex';
                    return ApprovalCard(
                      key: Key('live_approval_card_$key'),
                      toolName: approvalEvent.toolName,
                      description: approvalEvent.description,
                      details: approvalEvent.input,
                      onApprove: () => _handleApprovalDecision(
                        approvalKey: key,
                        approved: true,
                        toolName: approvalEvent.toolName,
                      ),
                      onReject: () => _handleApprovalDecision(
                        approvalKey: key,
                        approved: false,
                        toolName: approvalEvent.toolName,
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
    );
  }

  Widget _buildThinkingIndicator(CompozyPalette palette) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: palette.surface2,
          borderRadius: CompozyRadius.pill,
          border: Border.all(color: palette.line, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: palette.muted,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking…',
              style: TextStyle(
                fontSize: 12,
                color: palette.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTranscript() {
    return CompozyEmptyState(
      icon: Icons.chat_bubble_outline,
      title: 'No messages yet',
      message: 'Start the conversation by sending a prompt below.',
      actionLabel: 'Inspect workspace',
      onAction: () {
        _promptController.text = 'Inspect workspace status and report';
        _promptFocusNode.requestFocus();
        _onTextChanged();
      },
    );
  }

  Widget _buildErrorTranscript(Object error) {
    return CompozyErrorState(
      title: 'Failed to load transcript',
      message: "We couldn't reach the daemon to load conversation history.",
      details: error.toString(),
      onRetry: () => ref.invalidate(sessionHistoryProvider(widget.session.id)),
    );
  }

  Widget _buildPromptInputBar(CompozyPalette palette) {
    final isInputEnabled =
        !_isSessionBusy && !_isSessionStopped && !_isSubmitting;

    return Container(
      decoration: BoxDecoration(
        color: palette.canvas,
        border: Border(
          top: BorderSide(color: palette.line, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isInputEnabled ? palette.line : palette.lineSoft,
              width: 1,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Prompt TextField
              TextField(
                key: const Key('prompt_input_field'),
                controller: _promptController,
                focusNode: _promptFocusNode,
                enabled: isInputEnabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendPrompt(),
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 14,
                ),
                cursorColor: palette.fgStrong,
                decoration: InputDecoration(
                  hintText: _isSessionStopped
                      ? 'Session is stopped'
                      : (_isSessionBusy
                          ? 'Session is busy...'
                          : 'Send a prompt to agent...'),
                  hintStyle: TextStyle(
                    color: palette.subtle,
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),

              // Bottom control bar (mirrors hero.jpg)
              Row(
                children: [
                  // Tool/capability indicator chips
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surface2,
                      borderRadius: CompozyRadius.pill,
                      border: Border.all(color: palette.line, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: palette.info,
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.terminal,
                          size: 12,
                          color: palette.muted,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Inverted primary send button (strictly monochrome, ≥48dp touch target)
                  _buildSendButton(palette),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(CompozyPalette palette) {
    final isEnabled = _canSend;

    return Semantics(
      button: true,
      label: 'Send prompt',
      enabled: isEnabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('prompt_send_button'),
          borderRadius: CompozyRadius.pill,
          onTap: isEnabled
              ? () {
                  compozyHaptic();
                  _sendPrompt();
                }
              : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isEnabled ? palette.primary : palette.surface2,
                  borderRadius: CompozyRadius.pill,
                  border: Border.all(
                    color: isEnabled ? palette.primary : palette.line,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: _isSubmitting
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.primaryInk,
                          ),
                        )
                      : Icon(
                          Icons.arrow_upward,
                          size: 17,
                          color: isEnabled
                              ? palette.primaryInk
                              : palette.subtle,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
