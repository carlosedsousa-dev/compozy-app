import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/presentation/widgets/compozy_empty_state.dart';
import '../../../core/presentation/widgets/compozy_error_state.dart';
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
    final palette = context.palette;
    final loopsAsync = ref.watch(loopsProvider);
    final filteredAsync = ref.watch(filteredLoopsProvider);
    final selectedCategory = ref.watch(loopCategoryFilterProvider);
    final isOnline = ref.watch(connectionStatusProvider).value ?? true;

    return Scaffold(
      backgroundColor: palette.desk,
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
              return _buildCategoryFilterRow(context, ref, allLoops, selectedCategory);
            },
            orElse: () => const SizedBox.shrink(),
          ),

          // Main list / grid area with pull-to-refresh
          Expanded(
            child: RefreshIndicator(
              key: const Key('loops_refresh_indicator'),
              color: palette.fgStrong,
              backgroundColor: palette.card,
              onRefresh: () async {
                ref.invalidate(loopsProvider);
                await ref.read(loopsProvider.future);
              },
              child: filteredAsync.when(
                loading: () => _buildLoadingSkeleton(context),
                error: (error, stack) => _buildErrorView(ref, error),
                data: (loops) {
                  if (loops.isEmpty) {
                    return _buildEmptyView(ref, selectedCategory);
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
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            'Loops Catalog',
            style: TextStyle(
              color: palette.fgStrong,
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
                color: palette.surface2,
                borderRadius: CompozyRadius.pill,
                border: Border.all(color: palette.line, width: 1),
              ),
              child: Text(
                '${loops.length}',
                style: TextStyle(
                  color: palette.muted,
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
    BuildContext context,
    WidgetRef ref,
    List<LoopDefinition> allLoops,
    String selectedCategory,
  ) {
    final palette = context.palette;
    final categories = <String>['All'];
    for (final loop in allLoops) {
      final cat = loop.categoryDisplay;
      if (!categories.contains(cat)) {
        categories.add(cat);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: categories.map((category) {
            final isSelected =
                selectedCategory.toLowerCase() == category.toLowerCase();

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                selected: isSelected,
                button: true,
                label: '$category category filter',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Center(
                    child: ChoiceChip(
                      key: Key('filter_chip_${category.toLowerCase()}'),
                      label: Text(category),
                      selected: isSelected,
                      selectedColor: palette.elevated,
                      backgroundColor: palette.card,
                      side: BorderSide(
                        color: isSelected
                            ? palette.lineStrong
                            : palette.line,
                        width: 1,
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: CompozyRadius.pill,
                      ),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? palette.fgStrong
                            : palette.muted,
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
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final textScaler = MediaQuery.textScalerOf(context);
        final cardExtent = textScaler.scale(180.0).clamp(180.0, 360.0);

        if (isMobile) {
          return ListView.separated(
            key: const Key('loops_loading_skeletons'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) => const LoopCardSkeleton(),
          );
        } else {
          return GridView.builder(
            key: const Key('loops_loading_skeletons'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 480,
              mainAxisExtent: cardExtent,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 6,
            itemBuilder: (context, index) => const LoopCardSkeleton(),
          );
        }
      },
    );
  }

  Widget _buildLoopsContent(BuildContext context, List<LoopDefinition> loops) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final textScaler = MediaQuery.textScalerOf(context);
        // Adaptive height based on text scaling to prevent overflow clipping
        final cardExtent = textScaler.scale(180.0).clamp(180.0, 360.0);

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
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 480,
              mainAxisExtent: cardExtent,
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
        backgroundColor: context.palette.card,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) => LoopDetailsSheet(loop: loop),
      );
    }
  }

  Widget _buildEmptyView(WidgetRef ref, String selectedCategory) {
    final isFiltered = selectedCategory.toLowerCase() != 'all';

    return CompozyEmptyState(
      key: const Key('loops_empty_view'),
      icon: Icons.all_inclusive,
      title: isFiltered ? 'No loops in $selectedCategory' : 'No loops found',
      message: isFiltered
          ? 'No loops match the "$selectedCategory" category filter.'
          : 'No workspace loops are registered in this workspace.',
      actionLabel: isFiltered ? 'Reset Filter' : 'Refresh',
      onAction: () {
        if (isFiltered) {
          ref.read(loopCategoryFilterProvider.notifier).state = 'All';
        }
        ref.invalidate(loopsProvider);
      },
    );
  }

  Widget _buildErrorView(WidgetRef ref, Object error) {
    return CompozyErrorState(
      key: const Key('loops_error_view'),
      title: 'Failed to load loops',
      message: 'Unable to retrieve workspace loops. Check daemon connection and try again.',
      details: error.toString(),
      onRetry: () => ref.invalidate(loopsProvider),
      retryLabel: 'Retry',
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
    final palette = context.palette;

    return Container(
      key: const Key('loop_details_bottom_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: palette.line, width: 1),
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
                decoration: BoxDecoration(
                  color: palette.lineStrong,
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
                            style: TextStyle(
                              color: palette.fgStrong,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
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
                  ),
                  IconButton(
                    key: const Key('close_loop_details_sheet_button'),
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    tooltip: 'Close',
                    icon: Icon(
                      Icons.close,
                      color: palette.muted,
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Divider(color: palette.line, height: 1),

            // Scrollable contract and input body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Description
                    Text(
                      'DESCRIPTION',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loop.description,
                      style: TextStyle(
                        color: palette.fg,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Contract Section
                    _buildContractSection(context),
                    const SizedBox(height: 20),

                    // Input Schema Section
                    _buildInputsSection(context),
                    const SizedBox(height: 24),

                    // Run Loop Action Button (Inverted Monochrome Pill)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        key: const Key('details_run_loop_button'),
                        onPressed: () {
                          Navigator.of(context).pop();
                          showModalBottomSheet<void>(
                            context: context,
                            backgroundColor: palette.card,
                            isScrollControlled: true,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                            ),
                            builder: (_) => RunLoopSheet(loop: loop),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: palette.primary,
                          foregroundColor: palette.primaryInk,
                          elevation: 0,
                          shape: const RoundedRectangleBorder(
                            borderRadius: CompozyRadius.pill,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.play_arrow_rounded,
                              size: 16,
                              color: palette.primaryInk,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Run Loop',
                              style: TextStyle(
                                color: palette.primaryInk,
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

  Widget _buildContractSection(BuildContext context) {
    final palette = context.palette;
    final hasGoal = loop.goal.isNotEmpty;
    final hasDod = loop.definitionOfDone.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.assignment_outlined,
              size: 14,
              color: palette.info,
            ),
            const SizedBox(width: 6),
            Text(
              'CONTRACT',
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (!hasGoal && !hasDod)
          Text(
            'No contract specified.',
            style: TextStyle(
              color: palette.muted,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          )
        else ...[
          if (hasGoal) ...[
            Text(
              'Goal',
              style: TextStyle(
                color: palette.fg,
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
                color: palette.surface2,
                borderRadius: CompozyRadius.input,
                border: Border.all(color: palette.line, width: 1),
              ),
              child: Text(
                loop.goal,
                style: TextStyle(
                  color: palette.fg,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (hasDod) ...[
            Text(
              'Definition of Done',
              style: TextStyle(
                color: palette.fg,
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
                color: palette.surface2,
                borderRadius: CompozyRadius.input,
                border: Border.all(color: palette.line, width: 1),
              ),
              child: Text(
                loop.definitionOfDone,
                style: TextStyle(
                  color: palette.fg,
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

  Widget _buildInputsSection(BuildContext context) {
    final palette = context.palette;
    final inputs = loop.inputs;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.input_outlined, size: 14, color: palette.info),
            const SizedBox(width: 6),
            Text(
              'INPUT SCHEMA',
              style: TextStyle(
                color: palette.muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (inputs.isEmpty)
          Text(
            'No input parameters required.',
            style: TextStyle(
              color: palette.muted,
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
                  color: palette.surface2,
                  borderRadius: CompozyRadius.input,
                  border: Border.all(color: palette.line, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          entry.key,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            color: palette.fgStrong,
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
                              color: palette.canvas,
                              borderRadius: CompozyRadius.pill,
                              border: Border.all(
                                color: palette.lineSoft,
                              ),
                            ),
                            child: Text(
                              typeStr,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: palette.info,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                        if (defaultStr.isNotEmpty) ...[
                          const Spacer(),
                          Text(
                            'default: $defaultStr',
                            style: TextStyle(
                              color: palette.muted,
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
                        style: TextStyle(
                          color: palette.muted,
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
