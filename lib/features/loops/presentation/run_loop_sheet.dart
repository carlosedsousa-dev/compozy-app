import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/compozy_theme.dart';
import '../data/loop_repository_impl.dart';
import '../domain/loop_definition.dart';
import '../domain/loop_run_result.dart';
import '../domain/repositories/loop_repository.dart';

/// Modal bottom sheet for configuring and dispatching a CompozyOS Loop run.
/// Parses loop inputs dynamically, validates required parameters,
/// and dispatches POST /api/loops/run to the daemon.
class RunLoopSheet extends ConsumerStatefulWidget {
  final LoopDefinition loop;
  final LoopRepository? repository;
  final ValueChanged<LoopRunResult>? onRunCompleted;

  const RunLoopSheet({
    super.key,
    required this.loop,
    this.repository,
    this.onRunCompleted,
  });

  @override
  ConsumerState<RunLoopSheet> createState() => _RunLoopSheetState();
}

class _RunLoopSheetState extends ConsumerState<RunLoopSheet> {
  final _formKey = GlobalKey<FormState>();

  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _boolValues = {};

  bool _isLoading = false;
  String? _errorMessage;
  LoopRunResult? _result;

  @override
  void initState() {
    super.initState();
    _initializeFormFields();
  }

  void _initializeFormFields() {
    widget.loop.inputs.forEach((key, rawSpec) {
      String type = 'string';
      dynamic defaultValue;

      if (rawSpec is Map) {
        type = rawSpec['type']?.toString().toLowerCase() ?? 'string';
        defaultValue = rawSpec['default'];
      } else if (rawSpec is String) {
        type = rawSpec.toLowerCase();
      }

      if (type == 'boolean' || type == 'bool') {
        _boolValues[key] = defaultValue is bool ? defaultValue : false;
      } else {
        _textControllers[key] = TextEditingController(
          text: defaultValue != null ? defaultValue.toString() : '',
        );
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  LoopRepository get _effectiveRepository {
    return widget.repository ?? ref.read(loopRepositoryProvider);
  }

  Future<void> _submitRun() async {
    if (_isLoading) return;

    // Clear previous errors
    setState(() {
      _errorMessage = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final inputs = <String, dynamic>{};
    widget.loop.inputs.forEach((key, rawSpec) {
      String type = 'string';
      if (rawSpec is Map) {
        type = rawSpec['type']?.toString().toLowerCase() ?? 'string';
      } else if (rawSpec is String) {
        type = rawSpec.toLowerCase();
      }

      if (type == 'boolean' || type == 'bool') {
        inputs[key] = _boolValues[key] ?? false;
      } else if (type == 'integer' || type == 'int') {
        final text = _textControllers[key]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          inputs[key] = int.tryParse(text) ?? text;
        }
      } else if (type == 'number') {
        final text = _textControllers[key]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          inputs[key] = num.tryParse(text) ?? text;
        }
      } else {
        final text = _textControllers[key]?.text.trim() ?? '';
        if (text.isNotEmpty) {
          inputs[key] = text;
        }
      }
    });

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _effectiveRepository.runLoop(
        widget.loop.name,
        inputs: inputs,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _result = result;
      });

      widget.onRunCompleted?.call(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('run_loop_bottom_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: CompozyColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: CompozyColors.line, width: 1),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 36,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: CompozyColors.lineStrong,
                    borderRadius: CompozyRadius.pill,
                  ),
                ),
              ),

              // Header: Loop title, Category badge, Close button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Run ${widget.loop.name}',
                                  style: const TextStyle(
                                    color: CompozyColors.fgStrong,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _CategoryPill(category: widget.loop.categoryDisplay),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Configure workflow inputs and trigger daemon execution',
                            style: TextStyle(
                              color: CompozyColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('close_run_loop_sheet_button'),
                      icon: const Icon(
                        Icons.close,
                        color: CompozyColors.muted,
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(color: CompozyColors.line, height: 1),

              // Main Body: Result View OR Form View
              if (_result != null)
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: _buildResultView(),
                  ),
                )
              else ...[
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: _buildFormView(),
                  ),
                ),
                const Divider(color: CompozyColors.line, height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: _buildSubmitButton(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        key: const Key('run_loop_submit_button'),
        onPressed: _isLoading ? null : _submitRun,
        style: ElevatedButton.styleFrom(
          backgroundColor: CompozyColors.primary,
          foregroundColor: CompozyColors.primaryInk,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: CompozyRadius.pill,
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CompozyColors.primaryInk,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.play_arrow_rounded,
                    size: 18,
                    color: CompozyColors.primaryInk,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Run Loop',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildResultView() {
    final result = _result!;

    return Column(
      key: const Key('run_loop_success_banner'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: CompozyColors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: CompozyColors.success.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.check_circle_outline,
            color: CompozyColors.success,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Loop Execution Dispatched',
          style: TextStyle(
            color: CompozyColors.fgStrong,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'The daemon has accepted the execution request.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: CompozyColors.muted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 20),

        // Result Details Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: CompozyColors.surface2,
            borderRadius: CompozyRadius.card,
            border: Border.all(color: CompozyColors.line, width: 1),
          ),
          child: Column(
            children: [
              _buildResultRow(
                label: 'Run ID',
                value: result.runId,
                valueKey: const Key('run_loop_result_id'),
                monospace: true,
              ),
              const Divider(color: CompozyColors.line, height: 24),
              _buildResultRow(
                label: 'Status',
                value: result.status,
                valueKey: const Key('run_loop_result_status'),
                badgeColor: CompozyColors.success,
              ),
              if (result.loopName != null) ...[
                const Divider(color: CompozyColors.line, height: 24),
                _buildResultRow(
                  label: 'Loop Name',
                  value: result.loopName!,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Done Action Button (Inverted Monochrome Pill)
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            key: const Key('run_loop_done_button'),
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: CompozyColors.primary,
              foregroundColor: CompozyColors.primaryInk,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: CompozyRadius.pill,
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow({
    required String label,
    required String value,
    Key? valueKey,
    bool monospace = false,
    Color? badgeColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: CompozyColors.muted,
            fontSize: 13,
          ),
        ),
        if (badgeColor != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: CompozyRadius.pill,
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              value,
              key: valueKey,
              style: TextStyle(
                color: badgeColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          )
        else
          Text(
            value,
            key: valueKey,
            style: TextStyle(
              color: CompozyColors.fgStrong,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: monospace ? 'monospace' : null,
            ),
          ),
      ],
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Error Banner if present
          if (_errorMessage != null) ...[
            Container(
              key: const Key('run_loop_error'),
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CompozyColors.danger.withValues(alpha: 0.1),
                borderRadius: CompozyRadius.input,
                border: Border.all(color: CompozyColors.danger, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: CompozyColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: CompozyColors.danger,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Description
          Text(
            widget.loop.description,
            style: const TextStyle(
              color: CompozyColors.fg,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Goal if available
          if (widget.loop.goal.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: CompozyColors.surface2,
                borderRadius: CompozyRadius.input,
                border: Border.all(color: CompozyColors.line, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.flag_outlined,
                    size: 14,
                    color: CompozyColors.info,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.loop.goal,
                      style: const TextStyle(
                        color: CompozyColors.muted,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Section Title
          const Text(
            'PARAMETERS',
            style: TextStyle(
              color: CompozyColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),

          // Inputs Form Fields
          if (widget.loop.inputs.isEmpty)
            Container(
              key: const Key('run_loop_no_inputs'),
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CompozyColors.surface2,
                borderRadius: CompozyRadius.input,
                border: Border.all(color: CompozyColors.line, width: 1),
              ),
              child: const Text(
                'No input parameters required for this loop.',
                style: TextStyle(
                  color: CompozyColors.muted,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...widget.loop.inputs.entries.map(_buildFieldForEntry),
        ],
      ),
    );
  }

  Widget _buildFieldForEntry(MapEntry<String, dynamic> entry) {
    final key = entry.key;
    final spec = entry.value;

    String type = 'string';
    String description = '';
    bool isRequired = false;
    dynamic defaultValue;

    if (spec is Map) {
      type = spec['type']?.toString().toLowerCase() ?? 'string';
      description = spec['description']?.toString() ?? '';
      isRequired = spec['required'] == true;
      defaultValue = spec['default'];
    } else if (spec is String) {
      type = spec.toLowerCase();
    }

    // Default required rule: slug is required if not specified
    if (key == 'slug' && !isRequired && defaultValue == null) {
      isRequired = true;
    }

    final isBool = type == 'boolean' || type == 'bool';
    final isNumber = type == 'integer' || type == 'number' || type == 'int';

    if (isBool) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: CompozyColors.surface2,
          borderRadius: CompozyRadius.input,
          border: Border.all(color: CompozyColors.line, width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        key,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: CompozyColors.fgStrong,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TypePill(type: 'boolean'),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: CompozyColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Switch(
              key: Key('run_loop_input_$key'),
              value: _boolValues[key] ?? false,
              activeColor: CompozyColors.fgStrong,
              activeTrackColor: CompozyColors.lineStrong,
              inactiveThumbColor: CompozyColors.muted,
              inactiveTrackColor: CompozyColors.desk,
              onChanged: (val) {
                setState(() {
                  _boolValues[key] = val;
                });
              },
            ),
          ],
        ),
      );
    }

    // Number or text field
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: CompozyColors.surface2,
        borderRadius: CompozyRadius.input,
        border: Border.all(color: CompozyColors.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                key,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: CompozyColors.fgStrong,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              _TypePill(type: type),
              if (isRequired) ...[
                const SizedBox(width: 6),
                const Text(
                  '* required',
                  style: TextStyle(
                    color: CompozyColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                color: CompozyColors.muted,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextFormField(
            key: Key('run_loop_input_$key'),
            controller: _textControllers[key],
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: const TextStyle(
              color: CompozyColors.fgStrong,
              fontSize: 13,
              fontFamily: 'monospace',
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: CompozyColors.card,
              hintText: defaultValue != null ? 'default: $defaultValue' : 'Enter $key',
              hintStyle: const TextStyle(
                color: CompozyColors.subtle,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(color: CompozyColors.line, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(color: CompozyColors.line, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(color: CompozyColors.fgStrong, width: 1),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: CompozyRadius.input,
                borderSide: const BorderSide(color: CompozyColors.danger, width: 1),
              ),
            ),
            validator: (value) {
              if (isRequired && (value == null || value.trim().isEmpty)) {
                return '$key is required';
              }
              if (isNumber && value != null && value.trim().isNotEmpty) {
                if (num.tryParse(value.trim()) == null) {
                  return '$key must be a valid number';
                }
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String category;

  const _CategoryPill({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: CompozyColors.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: CompozyColors.line, width: 1),
      ),
      child: Text(
        category,
        style: const TextStyle(
          color: CompozyColors.info,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String type;

  const _TypePill({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: CompozyColors.canvas,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: CompozyColors.lineSoft, width: 1),
      ),
      child: Text(
        type,
        style: const TextStyle(
          fontFamily: 'monospace',
          color: CompozyColors.info,
          fontSize: 11,
        ),
      ),
    );
  }
}
