import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/compozy_theme.dart';
import '../../connection/presentation/connection_banner.dart';
import '../data/loop_repository_impl.dart';
import '../domain/loop_definition.dart';
import 'run_loop_sheet.dart';
import 'widgets/loop_card.dart';

export 'run_loop_sheet.dart';
export 'widgets/loop_card.dart';

/// Screen displaying the catalog of available workspace Loops with
/// category filtering, contract inspection, and responsive layout,
/// strictly mirroring loops.jpg and automations.jpg.
class LoopsCatalogScreen extends ConsumerWidget {
  final ValueChanged<LoopDefinition>? onLoopTap;

  const LoopsCatalogScreen({
    super.key,
    this.onLoopTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loopsAsync = ref.watch(loopsProvider);
    final filteredAsync = ref.watch(filteredLoopsProvider);
    final selectedCategory = ref.watch(loopCategoryFilterProvider);
    final isOnline = ref.watch(connectionStatusProvider).value ?? true;

    return Scaffold(
      backgroundColor: CompozyColors.desk,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connection banner when offline
          if (!isOnline)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ConnectionBanner(),
            ),

          // Header
          _buildHeader(context, loopsAsync),

          // Category filter row
          loopsAsync.maybeWhen(
            data: (allLoops) {
              if (allLoops.isEmpty) return const SizedBox.shrink();
              return _buildCategoryFilterRow(ref, allLoops, selectedCategory);
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // Main list / grid area with pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              key: const Key('loops_refresh_indicator'),
              color: CompozyColors.fgStrong,
              backgroundColor: CompozyColors.elevated,
              onRefresh: () async {
                ref.invalidate(loopsProvider);
                await ref.read(loopsProvider.future);
              },
              child: filteredAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: CompozyColors.fg,
                  ),
                ),
                error: (error, stack) => _buildErrorView(ref, error),
                data: (loops) {
                  if (loops.isEmpty) {
                    return _buildEmptyView();
                  }
                  return _buildLoopsContent(context, loops);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AsyncValue<List<LoopDefinition>> loopsAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Text(
            'Loops Catalog',
            style: TextStyle(
              color: CompozyColors.fgStrong,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(width: 8),
          loopsAsync.maybeWhen(
            data: (loops) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: CompozyColors.elevated,
                borderRadius: CompozyRadius.pill,
                border: Border.all(color: CompozyColors.line, width: 1),
              ),
              child: Text(
                '${loops.length}',
                style: const TextStyle(
                  color: CompozyColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterRow(
    WidgetRef ref,
    List<LoopDefinition> allLoops,
    String selectedCategory,
  ) {
    final categories = <String>['All'];
    for (final loop in allLoops) {
      final cat = loop.categoryDisplay;
      if (!categories.contains(cat)) {
        categories.add(cat);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((category) {
            final isSelected =
                selectedCategory.toLowerCase() == category.toLowerCase();

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                key: Key('filter_chip_${category.toLowerCase()}'),
                label: Text(category),
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
                    ref.read(loopCategoryFilterProvider.notifier).state =
                        category;
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLoopsContent(BuildContext context, List<LoopDefinition> loops) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return ListView.separated(
            key: const Key('loops_list_view'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: loops.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final loop = loops[index];
              return LoopCard(
                loop: loop,
                onTap: () => _handleCardTap(context, loop),
              );
            },
          );
        } else {
          return GridView.builder(
            key: const Key('loops_grid_view'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 480,
              mainAxisExtent: 180,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: loops.length,
            itemBuilder: (context, index) {
              final loop = loops[index];
              return LoopCard(
                loop: loop,
                onTap: () => _handleCardTap(context, loop),
              );
            },
          );
        }
      },
    );
  }

  void _handleCardTap(BuildContext context, LoopDefinition loop) {
    if (onLoopTap != null) {
      onLoopTap!(loop);
    } else {
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: CompozyColors.card,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => LoopDetailsSheet(loop: loop),
      );
    }
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
                  key: const Key('loops_empty_view'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.all_inclusive,
                      size: 44,
                      color: CompozyColors.muted,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No loops found',
                      style: TextStyle(
                        color: CompozyColors.fgStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'No workspace loops are registered in this workspace.',
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
                  key: const Key('loops_error_view'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 44,
                      color: CompozyColors.danger,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load loops',
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
                      onPressed: () => ref.invalidate(loopsProvider),
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

/// Bottom sheet displaying the full loop contract, goal, definition of done,
/// and input schema specifications.
class LoopDetailsSheet extends StatelessWidget {
  final LoopDefinition loop;

  const LoopDetailsSheet({
    super.key,
    required this.loop,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('loop_details_bottom_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: CompozyColors.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: CompozyColors.line, width: 1),
        ),
      ),
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

            // Header: loop title, category badge, close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            loop.name,
                            style: const TextStyle(
                              color: CompozyColors.fgStrong,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CategoryBadge(category: loop.categoryDisplay),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('close_loop_details_sheet_button'),
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

            // Scrollable contract and input body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    const Text(
                      'DESCRIPTION',
                      style: TextStyle(
                        color: CompozyColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loop.description,
                      style: const TextStyle(
                        color: CompozyColors.fg,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Contract Section
                    _buildContractSection(),
                    const SizedBox(height: 20),

                    // Input Schema Section
                    _buildInputsSection(),
                    const SizedBox(height: 24),

                    // Run Loop Action Button (Inverted Monochrome Pill)
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        key: const Key('details_run_loop_button'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: CompozyColors.card,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (_) => RunLoopSheet(loop: loop),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CompozyColors.primary,
                          foregroundColor: CompozyColors.primaryInk,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: CompozyRadius.pill,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 16,
                              color: CompozyColors.primaryInk,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Run Loop',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContractSection() {
    final hasGoal = loop.goal.isNotEmpty;
    final hasDod = loop.definitionOfDone.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(
              Icons.assignment_outlined,
              size: 14,
              color: CompozyColors.info,
            ),
            SizedBox(width: 6),
            Text(
              'CONTRACT',
              style: TextStyle(
                color: CompozyColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (!hasGoal && !hasDod)
          const Text(
            'No contract specified.',
            style: TextStyle(
              color: CompozyColors.muted,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          )
        else ...[
          if (hasGoal) ...[
            const Text(
              'Goal',
              style: TextStyle(
                color: CompozyColors.fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              key: const Key('loop_details_goal'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CompozyColors.surface2,
                borderRadius: CompozyRadius.input,
                border: Border.all(color: CompozyColors.line, width: 1),
              ),
              child: Text(
                loop.goal,
                style: const TextStyle(
                  color: CompozyColors.fg,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (hasDod) ...[
            const Text(
              'Definition of Done',
              style: TextStyle(
                color: CompozyColors.fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              key: const Key('loop_details_definition_of_done'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CompozyColors.surface2,
                borderRadius: CompozyRadius.input,
                border: Border.all(color: CompozyColors.line, width: 1),
              ),
              child: Text(
                loop.definitionOfDone,
                style: const TextStyle(
                  color: CompozyColors.fg,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildInputsSection() {
    final inputs = loop.inputs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.input_outlined, size: 14, color: CompozyColors.info),
            SizedBox(width: 6),
            Text(
              'INPUT SCHEMA',
              style: TextStyle(
                color: CompozyColors.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (inputs.isEmpty)
          const Text(
            'No input parameters required.',
            style: TextStyle(
              color: CompozyColors.muted,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          )
        else
          Column(
            children: inputs.entries.map((entry) {
              final val = entry.value;
              String typeStr = '';
              String descStr = '';
              String defaultStr = '';

              if (val is Map<String, dynamic>) {
                typeStr = val['type']?.toString() ?? '';
                descStr = val['description']?.toString() ?? '';
                if (val.containsKey('default')) {
                  defaultStr = val['default']?.toString() ?? '';
                }
              } else if (val != null) {
                typeStr = val.toString();
              }

              return Container(
                key: Key('loop_input_${entry.key}'),
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
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
                          entry.key,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: CompozyColors.fgStrong,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (typeStr.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: CompozyColors.canvas,
                              borderRadius: CompozyRadius.pill,
                              border: Border.all(
                                color: CompozyColors.lineSoft,
                              ),
                            ),
                            child: Text(
                              typeStr,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                color: CompozyColors.info,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                        if (defaultStr.isNotEmpty) ...[
                          const Spacer(),
                          Text(
                            'default: $defaultStr',
                            style: const TextStyle(
                              color: CompozyColors.muted,
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (descStr.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        descStr,
                        style: const TextStyle(
                          color: CompozyColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
