import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/compozy_feedback.dart';
import '../../../../core/theme/compozy_theme.dart';
import '../../domain/models/turn.dart';
import 'approval_card.dart';
import 'session_badges.dart';

/// Pulsing typing indicator cursor matching Compozy tokens:
/// Monospace block cursor with subtle opacity pulse (mirrors hero.jpg and UI/UX specs).
class PulsingCursor extends StatefulWidget {
  const PulsingCursor({super.key});

  @override
  State<PulsingCursor> createState() => _PulsingCursorState();
}

class _PulsingCursorState extends State<PulsingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    if (!isTest) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 7,
        height: 14,
        margin: const EdgeInsets.only(left: 2, top: 4),
        decoration: BoxDecoration(
          color: palette.fgStrong,
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }
}

/// User chat bubble strictly styled with Compozy tokens:
/// Right-aligned, elevated background, subtle border,
/// radius `16px` with bottom-right `4px` (mirrors hero.jpg and REFERENCE_GUIDE.md).
class UserChatBubble extends StatelessWidget {
  final String message;
  final String? status;
  final String? turnId;

  const UserChatBubble({
    super.key,
    required this.message,
    this.status,
    this.turnId,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        child: Container(
          key: turnId != null ? Key('user_bubble_$turnId') : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: palette.elevated,
            border: Border.all(
              color: palette.lineStrong,
              width: 1,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (status == 'queued' || status == 'in_progress') ...[
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: palette.muted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status == 'queued' ? 'Queued' : 'Running...',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Agent chat bubble strictly styled with Compozy tokens:
/// Left-aligned, includes circular agent avatar on the left, card container,
/// subtle border, radius `14px`, and discoverable copy action (mirrors hero.jpg and handoff.jpg).
class AgentChatBubble extends StatelessWidget {
  final String message;
  final String? turnId;
  final String? agentName;
  final bool isStreaming;

  const AgentChatBubble({
    super.key,
    required this.message,
    this.turnId,
    this.agentName,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final effectiveAgent = agentName ?? 'agent';

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.90,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Circular agent avatar (mirrors hero.jpg)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: AgentAvatar(agent: effectiveAgent, size: 24),
            ),
            const SizedBox(width: 8),

            // Message container with markdown and discoverable copy action
            Expanded(
              child: Container(
                key: turnId != null ? Key('agent_bubble_$turnId') : null,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                decoration: BoxDecoration(
                  color: palette.card,
                  border: Border.all(
                    color: palette.line,
                    width: 1,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MarkdownView(text: message),
                    if (isStreaming)
                      const PulsingCursor(key: Key('streaming_typing_cursor')),
                    if (!isStreaming && message.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Semantics(
                            button: true,
                            label: 'Copy message',
                            child: InkWell(
                              key: Key(
                                'copy_agent_message_${turnId ?? "active"}',
                              ),
                              borderRadius: CompozyRadius.pill,
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(text: message),
                                );
                                showCompozySnack(
                                  context,
                                  'Message copied to clipboard',
                                  isError: false,
                                );
                              },
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.copy_outlined,
                                        size: 13,
                                        color: palette.muted,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Copy',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: palette.muted,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
          ],
        ),
      ),
    );
  }
}

/// Lightweight, deterministic Markdown renderer strictly adhering to Compozy tokens.
/// Supports headings (`#`, `##`, `###`), bullets (`-`, `*`), bold (`**`),
/// italic (`*`), inline code (`` ` ``), and fenced code blocks (```` ``` ````).
class MarkdownView extends StatelessWidget {
  final String text;

  const MarkdownView({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final blocks = _parseMarkdownBlocks(context, palette, text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  List<Widget> _parseMarkdownBlocks(
    BuildContext context,
    CompozyPalette palette,
    String content,
  ) {
    final widgets = <Widget>[];
    final lines = content.split('\n');

    bool inCodeBlock = false;
    final codeBlockLines = <String>[];
    String? codeLanguage;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          widgets.add(
            _buildCodeBlock(
              context,
              palette,
              codeBlockLines.join('\n'),
              codeLanguage,
            ),
          );
          codeBlockLines.clear();
          codeLanguage = null;
          inCodeBlock = false;
        } else {
          inCodeBlock = true;
          final lang = line.trim().substring(3).trim();
          codeLanguage = lang.isNotEmpty ? lang : null;
        }
        continue;
      }

      if (inCodeBlock) {
        codeBlockLines.add(line);
        continue;
      }

      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (widgets.isNotEmpty) {
          widgets.add(const SizedBox(height: 6));
        }
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(
          _buildHeading(
            palette,
            trimmed.substring(4),
            14,
            FontWeight.w600,
          ),
        );
      } else if (trimmed.startsWith('## ')) {
        widgets.add(
          _buildHeading(
            palette,
            trimmed.substring(3),
            15,
            FontWeight.w600,
          ),
        );
      } else if (trimmed.startsWith('# ')) {
        widgets.add(
          _buildHeading(
            palette,
            trimmed.substring(2),
            16,
            FontWeight.w700,
          ),
        );
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        widgets.add(_buildBulletPoint(palette, trimmed.substring(2)));
      } else {
        widgets.add(_buildParagraph(palette, trimmed));
      }
    }

    if (inCodeBlock && codeBlockLines.isNotEmpty) {
      widgets.add(
        _buildCodeBlock(
          context,
          palette,
          codeBlockLines.join('\n'),
          codeLanguage,
        ),
      );
    }

    return widgets;
  }

  Widget _buildHeading(
    CompozyPalette palette,
    String text,
    double fontSize,
    FontWeight fontWeight,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text.rich(
        TextSpan(
          children: _parseInlineSpans(
            palette,
            text,
            baseStyle: TextStyle(
              color: palette.fgStrong,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(CompozyPalette palette, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              color: palette.muted,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: _parseInlineSpans(
                  palette,
                  text,
                  baseStyle: TextStyle(
                    color: palette.fg,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraph(CompozyPalette palette, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: _parseInlineSpans(
            palette,
            text,
            baseStyle: TextStyle(
              color: palette.fg,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBlock(
    BuildContext context,
    CompozyPalette palette,
    String code,
    String? language,
  ) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.desk,
        borderRadius: CompozyRadius.input,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (language != null)
                Text(
                  language.toLowerCase(),
                  style: TextStyle(
                    color: palette.subtle,
                    fontFamily: 'monospace',
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                )
              else
                const SizedBox.shrink(),
              Semantics(
                button: true,
                label: 'Copy code',
                child: IconButton(
                  icon: Icon(
                    Icons.copy_outlined,
                    size: 14,
                    color: palette.muted,
                  ),
                  tooltip: 'Copy code',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: code));
                    showCompozySnack(
                      context,
                      'Code copied to clipboard',
                      isError: false,
                    );
                  },
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              code,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: palette.fg,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _parseInlineSpans(
    CompozyPalette palette,
    String text, {
    required TextStyle baseStyle,
  }) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*(.*?)\*\*|\*(.*?)\*|`([^`]+)`|([^*`]+))');
    final matches = pattern.allMatches(text);

    for (final match in matches) {
      final raw = match.group(0) ?? '';
      if (raw.startsWith('**') && raw.endsWith('**') && raw.length >= 4) {
        spans.add(
          TextSpan(
            text: raw.substring(2, raw.length - 2),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: palette.fgStrong,
            ),
          ),
        );
      } else if (raw.startsWith('*') && raw.endsWith('*') && raw.length >= 2) {
        spans.add(
          TextSpan(
            text: raw.substring(1, raw.length - 1),
            style: baseStyle.copyWith(
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      } else if (raw.startsWith('`') && raw.endsWith('`') && raw.length >= 2) {
        spans.add(
          TextSpan(
            text: raw.substring(1, raw.length - 1),
            style: baseStyle.copyWith(
              fontFamily: 'monospace',
              backgroundColor: palette.desk,
              color: palette.fgStrong,
            ),
          ),
        );
      } else {
        spans.add(
          TextSpan(
            text: raw,
            style: baseStyle,
          ),
        );
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }

    return spans;
  }
}

/// Collapsible tool execution pill widget strictly styled with Compozy tokens:
/// Monospace font, sunken surface, and 1px line border (mirrors handoff.jpg).
class ToolInvocationPills extends StatefulWidget {
  final List<String> toolCalls;
  final String turnId;

  const ToolInvocationPills({
    super.key,
    required this.toolCalls,
    required this.turnId,
  });

  @override
  State<ToolInvocationPills> createState() => _ToolInvocationPillsState();
}

class _ToolInvocationPillsState extends State<ToolInvocationPills> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.toolCalls.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;
    final summaryLabel = widget.toolCalls.length == 1
        ? widget.toolCalls.first
        : '${widget.toolCalls.length} tools executed';

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header toggle pill with 48dp minimum touch target
          Semantics(
            button: true,
            expanded: _isExpanded,
            label: '$summaryLabel, ${_isExpanded ? "expanded" : "collapsed"}',
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Center(
                  child: InkWell(
                    key: Key('tool_pill_toggle_${widget.turnId}'),
                    borderRadius: CompozyRadius.pill,
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface2,
                        borderRadius: CompozyRadius.pill,
                        border: Border.all(
                          color: palette.line,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.terminal,
                            size: 13,
                            color: palette.muted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            summaryLabel,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 12,
                              color: palette.muted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 16,
                            color: palette.muted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Expanded tool calls list
          if (_isExpanded) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.toolCalls.map((tool) {
                  return Container(
                    key: Key('tool_call_${widget.turnId}_$tool'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: palette.line,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.code,
                          size: 11,
                          color: palette.info,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tool,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: palette.fg,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Composite widget for rendering a complete conversation [Turn].
class TurnWidget extends StatelessWidget {
  final Turn turn;
  final String? agentName;
  final ValueChanged<bool>? onApprovalDecision;

  const TurnWidget({
    super.key,
    required this.turn,
    this.agentName,
    this.onApprovalDecision,
  });

  @override
  Widget build(BuildContext context) {
    final isWaitingForApproval = turn.status == 'waiting_for_approval' ||
        turn.status == 'pending_approval' ||
        turn.status == 'needs_approval' ||
        turn.status == 'decision_pending';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // User Turn Bubble
        if (turn.userMessage != null && turn.userMessage!.isNotEmpty) ...[
          UserChatBubble(
            turnId: turn.turnId,
            message: turn.userMessage!,
            status: turn.status,
          ),
          const SizedBox(height: 10),
        ],

        // Tool Invocation Pills
        if (turn.toolCalls.isNotEmpty) ...[
          ToolInvocationPills(
            turnId: turn.turnId,
            toolCalls: turn.toolCalls,
          ),
          const SizedBox(height: 10),
        ],

        // Agent Turn Bubble
        if (turn.agentMessage != null && turn.agentMessage!.isNotEmpty) ...[
          AgentChatBubble(
            turnId: turn.turnId,
            message: turn.agentMessage!,
            agentName: agentName,
          ),
        ],

        // Approval Card when turn is waiting for approval
        if (isWaitingForApproval) ...[
          const SizedBox(height: 10),
          ApprovalCard(
            key: Key('turn_approval_card_${turn.turnId}'),
            toolName: turn.toolCalls.isNotEmpty ? turn.toolCalls.first : null,
            description: turn.agentMessage ??
                'The agent is requesting permission or a decision before proceeding.',
            onApprove: () => onApprovalDecision?.call(true),
            onReject: () => onApprovalDecision?.call(false),
            onDecision: onApprovalDecision,
          ),
        ],
      ],
    );
  }
}
