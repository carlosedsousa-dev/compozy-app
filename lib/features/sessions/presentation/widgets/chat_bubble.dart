import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';
import '../../domain/models/turn.dart';

/// User chat bubble strictly styled with Compozy tokens:
/// Right-aligned, `#242424` background, border `1px solid #303030`,
/// radius `12px`, text `--fg: #F5F5F5`.
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
            color: CompozyColors.surface2,
            border: Border.all(color: CompozyColors.line, width: 1),
            borderRadius: CompozyRadius.card,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                style: const TextStyle(
                  color: CompozyColors.fg,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              if (status == 'queued' || status == 'in_progress') ...[
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: CompozyColors.muted,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      status == 'queued' ? 'Queued' : 'Running...',
                      style: const TextStyle(
                        color: CompozyColors.muted,
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
/// Left-aligned, `#1A1A1A` background, border `1px solid #303030`,
/// radius `12px`, with markdown rendering.
class AgentChatBubble extends StatelessWidget {
  final String message;
  final String? turnId;
  final String? agentName;

  const AgentChatBubble({
    super.key,
    required this.message,
    this.turnId,
    this.agentName,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        child: Container(
          key: turnId != null ? Key('agent_bubble_$turnId') : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: CompozyColors.canvas,
            border: Border.all(color: CompozyColors.line, width: 1),
            borderRadius: CompozyRadius.card,
          ),
          child: MarkdownView(text: message),
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
    final blocks = _parseMarkdownBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  List<Widget> _parseMarkdownBlocks(String content) {
    final widgets = <Widget>[];
    final lines = content.split('\n');

    bool inCodeBlock = false;
    final codeBlockLines = <String>[];
    String? codeLanguage;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().startsWith('```')) {
        if (inCodeBlock) {
          widgets.add(_buildCodeBlock(codeBlockLines.join('\n'), codeLanguage));
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
        widgets.add(_buildHeading(trimmed.substring(4), 14, FontWeight.w600));
      } else if (trimmed.startsWith('## ')) {
        widgets.add(_buildHeading(trimmed.substring(3), 15, FontWeight.w600));
      } else if (trimmed.startsWith('# ')) {
        widgets.add(_buildHeading(trimmed.substring(2), 16, FontWeight.w700));
      } else if (trimmed.startsWith('- ') || trimmed.startsWith('* ')) {
        widgets.add(_buildBulletPoint(trimmed.substring(2)));
      } else {
        widgets.add(_buildParagraph(trimmed));
      }
    }

    if (inCodeBlock && codeBlockLines.isNotEmpty) {
      widgets.add(_buildCodeBlock(codeBlockLines.join('\n'), codeLanguage));
    }

    return widgets;
  }

  Widget _buildHeading(String text, double fontSize, FontWeight fontWeight) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Text.rich(
        TextSpan(
          children: _parseInlineSpans(
            text,
            baseStyle: TextStyle(
              color: CompozyColors.fgStrong,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: CompozyColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: _parseInlineSpans(
                  text,
                  baseStyle: const TextStyle(
                    color: CompozyColors.fg,
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

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: _parseInlineSpans(
            text,
            baseStyle: const TextStyle(
              color: CompozyColors.fg,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCodeBlock(String code, String? language) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CompozyColors.desk,
        borderRadius: CompozyRadius.input,
        border: Border.all(color: CompozyColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (language != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                language.toLowerCase(),
                style: const TextStyle(
                  color: CompozyColors.subtle,
                  fontFamily: 'monospace',
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: CompozyColors.fg,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InlineSpan> _parseInlineSpans(String text, {required TextStyle baseStyle}) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*(.*?)\*\*|\*(.*?)\*|`([^`]+)`|([^*`]+))');
    final matches = pattern.allMatches(text);

    for (final match in matches) {
      final raw = match.group(0) ?? '';
      if (raw.startsWith('**') && raw.endsWith('**') && raw.length >= 4) {
        spans.add(TextSpan(
          text: raw.substring(2, raw.length - 2),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.bold,
            color: CompozyColors.fgStrong,
          ),
        ));
      } else if (raw.startsWith('*') && raw.endsWith('*') && raw.length >= 2) {
        spans.add(TextSpan(
          text: raw.substring(1, raw.length - 1),
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (raw.startsWith('`') && raw.endsWith('`') && raw.length >= 2) {
        spans.add(TextSpan(
          text: raw.substring(1, raw.length - 1),
          style: baseStyle.copyWith(
            fontFamily: 'monospace',
            backgroundColor: CompozyColors.desk,
            color: CompozyColors.fgStrong,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: raw,
          style: baseStyle,
        ));
      }
    }

    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }

    return spans;
  }
}

/// Collapsible tool execution pill widget strictly styled with Compozy tokens:
/// Monospace font, sunken fill (`#101010`), and 1px line border.
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

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header toggle pill
          InkWell(
            key: Key('tool_pill_toggle_${widget.turnId}'),
            borderRadius: CompozyRadius.pill,
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: CompozyColors.desk,
                borderRadius: CompozyRadius.pill,
                border: Border.all(color: CompozyColors.line, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.terminal,
                    size: 13,
                    color: CompozyColors.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.toolCalls.length == 1
                        ? widget.toolCalls.first
                        : '${widget.toolCalls.length} tools executed',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: CompozyColors.muted,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: CompozyColors.muted,
                  ),
                ],
              ),
            ),
          ),

          // Expanded tool calls list
          if (_isExpanded) ...[
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.toolCalls.map((tool) {
                  return Container(
                    key: Key('tool_call_${widget.turnId}_$tool'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: CompozyColors.desk,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: CompozyColors.line, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.code,
                          size: 11,
                          color: CompozyColors.info,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tool,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: CompozyColors.fg,
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

  const TurnWidget({
    super.key,
    required this.turn,
    this.agentName,
  });

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }
}
