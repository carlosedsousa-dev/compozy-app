import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/theme/compozy_theme.dart';
import '../data/session_repository_impl.dart';
import '../domain/models/session.dart';
import '../domain/models/turn.dart';
import 'widgets/approval_card.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/session_badges.dart';
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
  late final TextEditingController _promptController;
  late final ScrollController _scrollController;
  final List<Turn> _optimisticTurns = [];
  bool _isSubmitting = false;
  bool _canSend = false;

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
    _promptController = TextEditingController();
    _scrollController = ScrollController();
    _promptController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _promptController.removeListener(_onTextChanged);
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasContent = _promptController.text.trim().isNotEmpty;
    final canSend = hasContent && !_isSessionBusy && !_isSessionStopped && !_isSubmitting;
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

        final String message;
        if (e is SessionBusyException) {
          message = 'Session is busy. Please wait before sending another prompt.';
        } else if (e is ArgumentError) {
          message = e.message.toString();
        } else {
          message = 'Failed to send prompt: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: CompozyColors.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleStreamEvent(SessionStreamEvent event) {
    if (event is SessionTextDeltaEvent) {
      setState(() {
        _isStreaming = true;
        _streamingTurnId ??= event.turnId;
        _streamingText = (_streamingText ?? '') + event.textDelta;
      });
      _scrollToBottom();
    } else if (event is SessionApprovalRequestEvent) {
      setState(() {
        final key = event.approvalId ??
            event.toolName ??
            'approval_${DateTime.now().millisecondsSinceEpoch}';
        _pendingApprovals[key] = event;
      });
      _scrollToBottom();
    } else if (event is SessionToolExecutionEvent) {
      if (event.isWaitingForApproval) {
        setState(() {
          final key = event.toolCallId ?? event.toolName;
          _pendingApprovals[key] = SessionApprovalRequestEvent(
            toolName: event.toolName,
            description: 'Permission approval requested to execute ${event.toolName}.',
            input: event.input,
            approvalId: event.toolCallId,
            sessionId: event.sessionId,
            turnId: event.turnId,
          );
        });
        _scrollToBottom();
      } else {
        setState(() {
          final key = event.toolCallId ?? event.toolName;
          _activeToolExecutions[key] = event;
        });
        _scrollToBottom();
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
      _scrollToBottom();
    } else if (event is SessionTranscriptSnapshotEvent) {
      setState(() {
        _streamTurns = List.from(event.turns);
        _streamingText = null;
        _streamingTurnId = null;
        _activeToolExecutions.clear();
        _isStreaming = false;
      });
      _scrollToBottom();
    } else if (event is SessionStateChangedEvent) {
      setState(() {
        _currentSessionState = event.state;
      });
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

    final historyAsync = ref.watch(sessionHistoryProvider(widget.session.id));

    return Scaffold(
      backgroundColor: CompozyColors.desk,
      appBar: _buildTopAppBar(context),
      body: Column(
        children: [
          // Guidance banner if session is in non-promptable state
          if (_isSessionStopped)
            _buildGuidanceBanner(
              icon: Icons.stop_circle_outlined,
              message: 'Session is stopped. Prompting is disabled.',
              color: CompozyColors.danger,
            )
          else if (_isSessionBusy)
            _buildGuidanceBanner(
              icon: Icons.hourglass_top_outlined,
              message: 'Session is currently busy running a turn.',
              color: CompozyColors.warning,
            ),

          // Main transcript area
          Expanded(
            child: widget.initialTurns != null
                ? _buildTranscriptView(widget.initialTurns!)
                : historyAsync.when(
                    loading: () => const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: CompozyColors.fg,
                      ),
                    ),
                    error: (error, stack) => _buildErrorTranscript(error),
                    data: (history) => _buildTranscriptView(history),
                  ),
          ),

          // Docked prompt input bar container (mirrors hero.jpg)
          _buildPromptInputBar(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildTopAppBar(BuildContext context) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(52),
      child: Container(
        decoration: const BoxDecoration(
          color: CompozyColors.canvas,
          border: Border(
            bottom: BorderSide(color: Color(0xFF202020), width: 1),
          ),
        ),
        child: AppBar(
          toolbarHeight: 52,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            key: const Key('chat_back_button'),
            icon: const Icon(Icons.arrow_back, color: CompozyColors.fg, size: 20),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          titleSpacing: 0,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  widget.session.name,
                  style: const TextStyle(
                    color: CompozyColors.fgStrong,
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
              const SizedBox(width: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuidanceBanner({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: CompozyColors.surface2,
        border: const Border(
          bottom: BorderSide(color: CompozyColors.line, width: 1),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(approved ? 'Tool execution approved.' : 'Tool execution rejected.'),
          backgroundColor: approved ? CompozyColors.success : CompozyColors.muted,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildTranscriptView(List<Turn> turns) {
    final currentTurns = _streamTurns ?? turns;
    final allTurns = [...currentTurns, ..._optimisticTurns];
    final activeToolEvents = _activeToolExecutions.values.toList();
    final pendingApprovalEvents = _pendingApprovals.values.toList();
    final hasStreamingBubble =
        _streamingText != null && _streamingText!.isNotEmpty;
    final hasLiveItems = activeToolEvents.isNotEmpty ||
        hasStreamingBubble ||
        pendingApprovalEvents.isNotEmpty;

    return RefreshIndicator(
      key: const Key('chat_refresh_indicator'),
      color: CompozyColors.fgStrong,
      backgroundColor: CompozyColors.elevated,
      onRefresh: () async {
        ref.invalidate(sessionHistoryProvider(widget.session.id));
        await ref.read(sessionHistoryProvider(widget.session.id).future);
        setState(() {
          _streamTurns = null;
        });
      },
      child: (allTurns.isEmpty && !hasLiveItems)
          ? _buildEmptyTranscript()
          : ListView.separated(
              key: const Key('transcript_list_view'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: allTurns.length +
                  activeToolEvents.length +
                  (hasStreamingBubble ? 1 : 0) +
                  pendingApprovalEvents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                if (index < allTurns.length) {
                  final turn = allTurns[index];
                  return TurnWidget(
                    turn: turn,
                    agentName: widget.session.agent,
                    onApprovalDecision: (approved) => _handleApprovalDecision(
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

                final approvalIndex =
                    afterLiveToolsIndex - (hasStreamingBubble ? 1 : 0);
                if (approvalIndex >= 0 &&
                    approvalIndex < pendingApprovalEvents.length) {
                  final approvalEvent = pendingApprovalEvents[approvalIndex];
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
                    onDecision: (approved) => _handleApprovalDecision(
                      approvalKey: key,
                      approved: approved,
                      toolName: approvalEvent.toolName,
                    ),
                  );
                }

                return const SizedBox.shrink();
              },
            ),
    );
  }

  Widget _buildEmptyTranscript() {
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
                      'No messages yet',
                      style: TextStyle(
                        color: CompozyColors.fgStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Start the conversation by sending a prompt below.',
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

  Widget _buildErrorTranscript(Object error) {
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
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load transcript',
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
                    ElevatedButton(
                      onPressed: () => ref.invalidate(sessionHistoryProvider(widget.session.id)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CompozyColors.primary,
                        foregroundColor: CompozyColors.primaryInk,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: const RoundedRectangleBorder(
                          borderRadius: CompozyRadius.pill,
                        ),
                      ),
                      child: const Text(
                        'Retry',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
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

  Widget _buildPromptInputBar() {
    final isInputEnabled = !_isSessionBusy && !_isSessionStopped && !_isSubmitting;

    return Container(
      decoration: const BoxDecoration(
        color: CompozyColors.canvas,
        border: Border(
          top: BorderSide(color: Color(0xFF202020), width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: CompozyColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isInputEnabled ? CompozyColors.line : CompozyColors.lineSoft,
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
                enabled: isInputEnabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendPrompt(),
                style: const TextStyle(
                  color: CompozyColors.fg,
                  fontSize: 14,
                ),
                cursorColor: CompozyColors.fgStrong,
                decoration: InputDecoration(
                  hintText: _isSessionStopped
                      ? 'Session is stopped'
                      : (_isSessionBusy ? 'Session is busy...' : 'Send a prompt to agent...'),
                  hintStyle: const TextStyle(
                    color: CompozyColors.subtle,
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: CompozyColors.surface2,
                      borderRadius: CompozyRadius.pill,
                      border: Border.all(color: CompozyColors.line, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: CompozyColors.info,
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.terminal,
                          size: 12,
                          color: CompozyColors.muted,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Inverted primary send button (strictly monochrome #F5F5F5 / #0A0A0A)
                  _buildSendButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final isEnabled = _canSend;

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isEnabled ? CompozyColors.primary : CompozyColors.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(
          color: isEnabled ? CompozyColors.primary : CompozyColors.line,
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('prompt_send_button'),
          borderRadius: CompozyRadius.pill,
          onTap: isEnabled ? _sendPrompt : null,
          child: Center(
            child: _isSubmitting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CompozyColors.primaryInk,
                    ),
                  )
                : Icon(
                    Icons.arrow_upward,
                    size: 17,
                    color: isEnabled
                        ? CompozyColors.primaryInk
                        : CompozyColors.subtle,
                  ),
          ),
        ),
      ),
    );
  }
}
