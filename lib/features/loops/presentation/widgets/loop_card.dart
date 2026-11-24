import 'package:material_ui/material_ui.dart';

import '../../../../core/presentation/widgets/compozy_skeleton.dart';
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
    final palette = context.palette;

    return Container(
      key: Key('loop_card_${loop.name}'),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: CompozyRadius.card,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header: Loop title + Category badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          loop.name,
                          style: TextStyle(
                            color: palette.fgStrong,
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
                    style: TextStyle(
                      color: palette.fg,
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
                                    color: palette.surface2,
                                    borderRadius: CompozyRadius.pill,
                                    border: Border.all(
                                      color: palette.line,
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${loop.inputs.length} inputs',
                                    style: TextStyle(
                                      color: palette.muted,
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
                                        Icons.verified_outlined,
                                        size: 11,
                                        color: palette.success,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Contract',
                                        style: TextStyle(
                                          color: palette.muted,
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
      ),
    );
  }

  void _openRunSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.palette.card,
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
    final palette = context.palette;

    return Container(
      key: loopName != null ? Key('loop_category_pill_$loopName') : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.surface2,
        borderRadius: CompozyRadius.pill,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 11,
            color: palette.info,
          ),
          const SizedBox(width: 4),
          Text(
            category,
            style: TextStyle(
              color: palette.info,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Inverted monochrome action pill button for triggering a Loop run with ≥48dp touch target.
class _RunLoopButton extends StatelessWidget {
  final LoopDefinition loop;
  final VoidCallback onPressed;

  const _RunLoopButton({
    required this.loop,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: 'Run loop ${loop.name}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: Key('run_loop_button_${loop.name}'),
              borderRadius: CompozyRadius.pill,
              onTap: onPressed,
              child: Ink(
                decoration: BoxDecoration(
                  color: palette.primary,
                  borderRadius: CompozyRadius.pill,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 14,
                      color: palette.primaryInk,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Run Loop',
                      style: TextStyle(
                        color: palette.primaryInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Breathing skeleton placeholder matching real [LoopCard] geometry to prevent layout shift.
class LoopCardSkeleton extends StatelessWidget {
  const LoopCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: CompozyRadius.card,
        border: Border.all(color: palette.line, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              CompozySkeleton(width: 120, height: 16),
              CompozySkeleton(
                width: 68,
                height: 18,
                borderRadius: CompozyRadius.pill,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const CompozySkeleton(width: double.infinity, height: 12),
          const SizedBox(height: 6),
          const CompozySkeleton(width: 180, height: 12),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              CompozySkeleton(
                width: 72,
                height: 18,
                borderRadius: CompozyRadius.pill,
              ),
              CompozySkeleton(
                width: 88,
                height: 28,
                borderRadius: CompozyRadius.pill,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
