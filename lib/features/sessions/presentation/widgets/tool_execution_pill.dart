import 'dart:convert';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';
import '../../domain/models/session_stream_event.dart';

/// Compact tool execution pill displaying real-time tool calls (active, settled, error).
/// Strictly styled with Compozy tokens:
/// Background `#1A1A1A`, 1px solid border `#2C2C2C`, monospaced 11sp typography.
/// Mirrors hero.jpg, handoff.jpg, and REFERENCE_GUIDE.md.
class ToolExecutionPill extends StatefulWidget {
  final String toolName;
  final String status;
  final String? toolCallId;
  final dynamic input;
  final dynamic output;

  const ToolExecutionPill({
    super.key,
    required this.toolName,
    this.status = 'completed',
    this.toolCallId,
    this.input,
    this.output,
  });

  /// Factory constructor to create a [ToolExecutionPill] from a [SessionToolExecutionEvent].
  factory ToolExecutionPill.fromEvent(SessionToolExecutionEvent event) {
    return ToolExecutionPill(
      key: Key('tool_execution_pill_${event.toolCallId ?? event.toolName}'),
      toolName: event.toolName,
      status: event.status,
      toolCallId: event.toolCallId,
      input: event.input,
      output: event.output,
    );
  }

  /// Whether the tool execution is currently active / in progress.
  bool get isActive =>
      status == 'active' ||
      status == 'in_progress' ||
      status == 'running' ||
      status == 'started';

  /// Whether the tool execution has completed / settled.
  bool get isCompleted =>
      status == 'completed' ||
      status == 'settled' ||
      status == 'done' ||
      status == 'success';

  /// Whether the tool execution encountered an error / failed.
  bool get isFailed =>
      status == 'failed' || status == 'error';

  @override
  State<ToolExecutionPill> createState() => _ToolExecutionPillState();
}

class _ToolExecutionPillState extends State<ToolExecutionPill> {
  bool _isExpanded = false;

  bool get _hasDetails =>
      widget.input != null || widget.output != null;

  String _formatPayload(dynamic payload) {
    if (payload == null) return '';
    if (payload is String) return payload;
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(payload);
    } catch (_) {
      return payload.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveKey = widget.key ??
        Key('tool_pill_${widget.isActive ? 'active' : 'completed'}_${widget.toolName}');

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: effectiveKey,
              borderRadius: CompozyRadius.pill,
              onTap: _hasDetails
                  ? () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    }
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: CompozyRadius.pill,
                  border: Border.all(
                    color: widget.isActive
                        ? const Color(0xFF383838)
                        : const Color(0xFF2C2C2C),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Status indicator icon
                    if (widget.isActive)
                      const SizedBox(
                        key: Key('tool_pill_spinner'),
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: CompozyColors.success,
                        ),
                      )
                    else if (widget.isFailed)
                      const Icon(
                        Icons.error_outline,
                        key: Key('tool_pill_error_icon'),
                        size: 12,
                        color: CompozyColors.danger,
                      )
                    else
                      const Icon(
                        Icons.check,
                        key: Key('tool_pill_check_icon'),
                        size: 12,
                        color: CompozyColors.success,
                      ),
                    const SizedBox(width: 6),

                    // Monospaced 11sp tool name text
                    Text(
                      'tool: ${widget.toolName}',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: widget.isActive
                            ? CompozyColors.fg
                            : (widget.isFailed
                                ? CompozyColors.danger
                                : CompozyColors.muted),
                        fontWeight:
                            widget.isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),

                    if (widget.isActive) ...[
                      const SizedBox(width: 6),
                      Container(
                        key: const Key('tool_pill_active_dot'),
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: CompozyColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],

                    if (_hasDetails) ...[
                      const SizedBox(width: 4),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 14,
                        color: CompozyColors.subtle,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // Collapsible input / output details view
          if (_isExpanded && _hasDetails) ...[
            const SizedBox(height: 6),
            Container(
              key: Key('tool_pill_details_${widget.toolCallId ?? widget.toolName}'),
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: CompozyColors.desk,
                borderRadius: CompozyRadius.input,
                border: Border.all(color: CompozyColors.line, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.input != null) ...[
                    const Text(
                      'Input:',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: CompozyColors.subtle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      _formatPayload(widget.input),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: CompozyColors.fg,
                      ),
                    ),
                  ],
                  if (widget.input != null && widget.output != null)
                    const SizedBox(height: 8),
                  if (widget.output != null) ...[
                    const Text(
                      'Output:',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        color: CompozyColors.subtle,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SelectableText(
                      _formatPayload(widget.output),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: CompozyColors.fg,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
