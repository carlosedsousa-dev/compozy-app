import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/network/api_exceptions.dart';
import '../../../core/theme/compozy_theme.dart';
import '../data/session_repository_impl.dart';
import '../domain/models/session.dart';
import '../domain/models/turn.dart';
import 'widgets/chat_bubble.dart';
import 'widgets/session_badges.dart';

/// Screen displaying the conversation turn transcript for a CompozyOS session,
/// collapsible tool execution pills, and an interactive prompt input bar.
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

  bool get _isSessionBusy {
    final state = widget.session.state.toLowerCase();
    return state == 'busy' || state == 'waiting';
  }

  bool get _isSessionStopped {
    final state = widget.session.state.toLowerCase();
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

  @override
  Widget build(BuildContext context) {
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
                        color: CompozyColors.fg,
                      ),
                    ),
                    error: (error, stack) => _buildErrorTranscript(error),
                    data: (history) => _buildTranscriptView(history),
                  ),
          ),

          // Docked prompt input bar
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
          color: CompozyColors.rail,
          border: Border(
            bottom: BorderSide(color: CompozyColors.line, width: 1),
          ),
        ),
        child: AppBar(
          toolbarHeight: 52,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            key: const Key('chat_back_button'),
            icon: const Icon(Icons.arrow_back, color: CompozyColors.fg),
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
              StateBadge(state: widget.session.state),
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
          Icon(icon, size: 16, color: color),
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

  Widget _buildTranscriptView(List<Turn> turns) {
    final allTurns = [...turns, ..._optimisticTurns];

    return RefreshIndicator(
      key: const Key('chat_refresh_indicator'),
      color: CompozyColors.fgStrong,
      backgroundColor: CompozyColors.surface2,
      onRefresh: () async {
        ref.invalidate(sessionHistoryProvider(widget.session.id));
        await ref.read(sessionHistoryProvider(widget.session.id).future);
      },
      child: allTurns.isEmpty
          ? _buildEmptyTranscript()
          : ListView.separated(
              key: const Key('transcript_list_view'),
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: allTurns.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final turn = allTurns[index];
                return TurnWidget(
                  turn: turn,
                  agentName: widget.session.agent,
                );
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
                      size: 48,
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
                      size: 48,
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
                    OutlinedButton(
                      onPressed: () => ref.invalidate(sessionHistoryProvider(widget.session.id)),
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

  Widget _buildPromptInputBar() {
    final isInputEnabled = !_isSessionBusy && !_isSessionStopped && !_isSubmitting;

    return Container(
      decoration: const BoxDecoration(
        color: CompozyColors.rail,
        border: Border(
          top: BorderSide(color: CompozyColors.line, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Input field
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: CompozyColors.canvas,
                  borderRadius: CompozyRadius.input,
                  border: Border.all(
                    color: isInputEnabled ? CompozyColors.line : CompozyColors.lineSoft,
                    width: 1,
                  ),
                ),
                child: TextField(
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Inverted primary send pill
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    final isEnabled = _canSend;

    return Container(
      width: 40,
      height: 40,
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
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: CompozyColors.primaryInk,
                    ),
                  )
                : Icon(
                    Icons.arrow_upward,
                    size: 20,
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
