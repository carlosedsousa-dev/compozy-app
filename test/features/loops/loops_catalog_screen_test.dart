import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/features/connection/presentation/connection_banner.dart';
import 'package:compozy_app/features/loops/data/loop_repository_impl.dart';
import 'package:compozy_app/features/loops/domain/loop_definition.dart';
import 'package:compozy_app/features/loops/presentation/loops_catalog_screen.dart';

void main() {
  final testLoops = [
    const LoopDefinition(
      name: 'council',
      category: 'Engineering',
      description:
          'Three independent seats analyze one architectural question and synthesize findings.',
      contract: {
        'goal': 'Deliver consensus recommendation with trade-offs',
        'definition_of_done':
            'All three seats conclude analysis with unanimous or split recommendation',
      },
      inputs: {
        'topic': {
          'type': 'string',
          'description': 'The architectural decision topic to debate',
        },
        'seats': {
          'type': 'integer',
          'default': 3,
          'description': 'Number of independent advisory seats',
        },
      },
    ),
    const LoopDefinition(
      name: 'overnight',
      category: 'Automation',
      description:
          'Runs continuous overnight task queue execution until all ready tasks complete.',
      contract: {
        'goal': 'Execute all ready tasks in dependency order',
        'definition_of_done': 'No remaining ready tasks in task graph',
      },
      inputs: {
        'max_hours': {
          'type': 'number',
          'default': 8,
          'description': 'Maximum execution duration in hours',
        },
      },
    ),
    const LoopDefinition(
      name: 'deliver-phases',
      category: 'Engineering',
      description:
          'Autonomous spec-driven multi-phase feature delivery pipeline.',
      contract: {
        'goal': 'Implement and verify all phases sequentially',
        'definition_of_done': 'All phase gates pass with verification',
      },
      inputs: {},
    ),
  ];

  group('testLoopsCatalogScreen (IT-004)', () {
    testWidgets(
        'renders loop cards with title, category, and description (US-004.AC-1)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopsProvider.overrideWith((ref) => Future.value(testLoops)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: LoopsCatalogScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and total count
      expect(find.text('Loops Catalog'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Verify loop titles
      expect(find.text('council'), findsOneWidget);
      expect(find.text('overnight'), findsOneWidget);
      expect(find.text('deliver-phases'), findsOneWidget);

      // Verify category badges
      expect(find.text('Engineering'), findsWidgets);
      expect(find.text('Automation'), findsWidgets);

      // Verify descriptions
      expect(
        find.text(
          'Three independent seats analyze one architectural question and synthesize findings.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Runs continuous overnight task queue execution until all ready tasks complete.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'Autonomous spec-driven multi-phase feature delivery pipeline.',
        ),
        findsOneWidget,
      );

      // Verify input count badge and contract indicator
      expect(find.text('2 inputs'), findsOneWidget);
      expect(find.text('1 inputs'), findsOneWidget);
      expect(find.text('Contract'), findsWidgets);
    });

    testWidgets(
        'shows details bottom sheet with contract goal, definition of done, and inputs on card tap (US-004.AC-2)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopsProvider.overrideWith((ref) => Future.value(testLoops)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: LoopsCatalogScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on council loop card
      await tester.tap(find.text('council'));
      await tester.pumpAndSettle();

      // Bottom sheet should now be visible
      expect(find.byKey(const Key('loop_details_bottom_sheet')), findsOneWidget);

      // Verify goal
      expect(
        find.text('Deliver consensus recommendation with trade-offs'),
        findsOneWidget,
      );

      // Verify definition of done
      expect(
        find.text(
          'All three seats conclude analysis with unanimous or split recommendation',
        ),
        findsOneWidget,
      );

      // Verify inputs schema rendered
      expect(find.text('topic'), findsOneWidget);
      expect(find.text('seats'), findsOneWidget);
      expect(find.text('The architectural decision topic to debate'), findsOneWidget);
      expect(find.text('default: 3'), findsOneWidget);

      // Close bottom sheet
      await tester.tap(find.byKey(const Key('close_loop_details_sheet_button')));
      await tester.pumpAndSettle();

      // Bottom sheet should be dismissed
      expect(find.byKey(const Key('loop_details_bottom_sheet')), findsNothing);
    });

    testWidgets('renders empty state when no loops exist (US-004.EC-1)',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopsProvider.overrideWith((ref) => Future.value(const [])),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: LoopsCatalogScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loops_empty_view')), findsOneWidget);
      expect(find.text('No loops found'), findsOneWidget);
      expect(
        find.text('No workspace loops are registered in this workspace.'),
        findsOneWidget,
      );
    });

    testWidgets('handles pull-to-refresh trigger', (tester) async {
      int fetchCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopsProvider.overrideWith((ref) {
              fetchCount++;
              return Future.value(testLoops);
            }),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: LoopsCatalogScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(fetchCount, 1);

      // Pull down to trigger refresh
      await tester.fling(
        find.byKey(const Key('loops_refresh_indicator')),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(fetchCount, greaterThanOrEqualTo(2));
    });

    testWidgets('renders error view with retry action on failure',
        (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopsProvider.overrideWith((ref) {
              if (retried) {
                return Future.value(testLoops);
              }
              return Future.error(Exception('Network error'));
            }),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: LoopsCatalogScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('loops_error_view')), findsOneWidget);
      expect(find.text('Failed to load loops'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      retried = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('council'), findsOneWidget);
      expect(find.text('overnight'), findsOneWidget);
    });

    testWidgets('filters loops by category when category chip is selected',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopsProvider.overrideWith((ref) => Future.value(testLoops)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: LoopsCatalogScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('council'), findsOneWidget);
      expect(find.text('overnight'), findsOneWidget);
      expect(find.text('deliver-phases'), findsOneWidget);

      // Select 'Automation' category chip
      await tester.tap(find.byKey(const Key('filter_chip_automation')));
      await tester.pumpAndSettle();

      expect(find.text('overnight'), findsOneWidget);
      expect(find.text('council'), findsNothing);
      expect(find.text('deliver-phases'), findsNothing);

      // Select 'All' category chip
      await tester.tap(find.byKey(const Key('filter_chip_all')));
      await tester.pumpAndSettle();

      expect(find.text('council'), findsOneWidget);
      expect(find.text('overnight'), findsOneWidget);
      expect(find.text('deliver-phases'), findsOneWidget);
    });

    testWidgets('renders mobile layout (<600dp) with ListView',
        (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopsProvider.overrideWith((ref) => Future.value(testLoops)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: LoopsCatalogScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loops_list_view')), findsOneWidget);
      expect(find.byKey(const Key('loops_grid_view')), findsNothing);
    });

    testWidgets('renders desktop layout (>=600dp) with GridView',
        (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopsProvider.overrideWith((ref) => Future.value(testLoops)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: LoopsCatalogScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loops_grid_view')), findsOneWidget);
      expect(find.byKey(const Key('loops_list_view')), findsNothing);
    });

    testWidgets('custom onLoopTap callback triggers when provided',
        (tester) async {
      LoopDefinition? tappedLoop;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopsProvider.overrideWith((ref) => Future.value(testLoops)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: MaterialApp(
            home: LoopsCatalogScreen(
              onLoopTap: (l) => tappedLoop = l,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('council'));
      await tester.pump();

      expect(tappedLoop?.name, 'council');
      expect(find.byKey(const Key('loop_details_bottom_sheet')), findsNothing);
    });
  });
}
