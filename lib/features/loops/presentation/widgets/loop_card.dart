import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/compozy_theme.dart';
import '../../domain/loop_definition.dart';
import '../run_loop_sheet.dart';

/// Visual card representing one Loop definition in the catalog, strictly mirroring loops.jpg.
/// Includes metadata, tags, and a prominent "Run Loop" inverted monochrome action pill.
class LoopCard extends StatelessWidget {
  final LoopDefinition loop;
  final VoidCallback? onTap;
  final VoidCallback? onRunTap;

  const LoopCard({
    super.key,
    required this.loop,
    this.onTap,
    this.onRunTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('loop_card_${loop.name}'),
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Loop title + Category badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        loop.name,
                        style: const TextStyle(
                          color: CompozyColors.fgStrong,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CategoryBadge(
                      category: loop.categoryDisplay,
                      loopName: loop.name,
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  loop.description,
                  style: const TextStyle(
                    color: CompozyColors.fg,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Footer metadata row + Run Loop action pill (mirrors loops.jpg & US-007)
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (loop.inputs.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: CompozyColors.surface2,
                                  borderRadius: CompozyRadius.pill,
                                  border: Border.all(
                                    color: CompozyColors.line,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  '${loop.inputs.length} inputs',
                                  style: const TextStyle(
                                    color: CompozyColors.muted,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (loop.definitionOfDone.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: CompozyColors.surface2,
                                  borderRadius: CompozyRadius.pill,
                                  border: Border.all(
                                    color: CompozyColors.line,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.verified_outlined,
                                      size: 11,
                                      color: CompozyColors.success,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Contract',
                                      style: TextStyle(
                                        color: CompozyColors.muted,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // "Run Loop" action button (Inverted Monochrome Pill)
                    _RunLoopButton(
                      loop: loop,
                      onPressed: onRunTap ?? () => _openRunSheet(context),
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

  void _openRunSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CompozyColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => RunLoopSheet(loop: loop),
    );
  }
}

/// Category pill badge for loop classification with subtle slate/violet tone.
class _CategoryBadge extends StatelessWidget {
  final String category;
  final String? loopName;

  const _CategoryBadge({
    required this.category,
    this.loopName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: loopName != null ? Key('loop_category_pill_$loopName') : null,
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
            Icons.folder_outlined,
            size: 11,
            color: CompozyColors.info,
          ),
          const SizedBox(width: 4),
          Text(
            category,
            style: const TextStyle(
              color: CompozyColors.info,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inverted monochrome action pill button for triggering a Loop run.
class _RunLoopButton extends StatelessWidget {
  final LoopDefinition loop;
  final VoidCallback onPressed;

  const _RunLoopButton({
    required this.loop,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('run_loop_button_${loop.name}'),
        borderRadius: CompozyRadius.pill,
        onTap: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            color: CompozyColors.primary,
            borderRadius: CompozyRadius.pill,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(
                Icons.play_arrow_rounded,
                size: 14,
                color: CompozyColors.primaryInk,
              ),
              SizedBox(width: 4),
              Text(
                'Run Loop',
                style: TextStyle(
                  color: CompozyColors.primaryInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
