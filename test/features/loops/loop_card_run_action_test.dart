import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/loops/data/loop_repository_impl.dart';
import 'package:compozy_app/features/loops/domain/loop_definition.dart';
import 'package:compozy_app/features/loops/domain/loop_run_result.dart';
import 'package:compozy_app/features/loops/domain/repositories/loop_repository.dart';
import 'package:compozy_app/features/loops/presentation/run_loop_sheet.dart';
import 'package:compozy_app/features/loops/presentation/widgets/loop_card.dart';

class _FakeLoopRepository implements LoopRepository {
  @override
  Future<List<LoopDefinition>> getLoops() async => [];

  @override
  Future<LoopDefinition> getLoopDetails(String name) async =>
      throw UnimplementedError();

  @override
  Future<LoopRunResult> runLoop(
    String name, {
    Map<String, dynamic> inputs = const {},
  }) async {
    return const LoopRunResult(runId: 'run-mock-1', status: 'queued');
  }
}

void main() {
  const testLoop = LoopDefinition(
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
        'required': true,
        'description': 'The architectural decision topic to debate',
      },
      'seats': {
        'type': 'integer',
        'default': 3,
        'description': 'Number of independent advisory seats',
      },
    },
  );

  group('testLoopCardRunAction (WT-006)', () {
    testWidgets(
        'renders LoopCard with metadata and shows Run Loop action button',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: const Scaffold(
            body: LoopCard(loop: testLoop),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title, category, description
      expect(find.text('council'), findsOneWidget);
      expect(find.text('Engineering'), findsOneWidget);
      expect(
        find.text(
          'Three independent seats analyze one architectural question and synthesize findings.',
        ),
        findsOneWidget,
      );

      // Verify inputs badge and contract badge
      expect(find.text('2 inputs'), findsOneWidget);
      expect(find.text('Contract'), findsOneWidget);

      // Verify "Run Loop" action button is visible (WT-006)
      expect(find.text('Run Loop'), findsOneWidget);
      expect(
        find.byKey(const Key('run_loop_button_council')),
        findsOneWidget,
      );

      // Verify button styling (inverted monochrome pill)
      final textWidget = tester.widget<Text>(find.text('Run Loop'));
      expect(textWidget.style?.color, CompozyColors.primaryInk);
      expect(textWidget.style?.fontWeight, FontWeight.w600);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('tapping Run Loop button triggers onRunTap callback when provided',
        (tester) async {
      bool runTapped = false;
      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: Scaffold(
            body: LoopCard(
              loop: testLoop,
              onTap: () => cardTapped = true,
              onRunTap: () => runTapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on "Run Loop" button specifically
      await tester.tap(find.text('Run Loop'));
      await tester.pumpAndSettle();

      expect(runTapped, isTrue);
      // Main card tap should not fire when tapping run button
      expect(cardTapped, isFalse);
    });

    testWidgets('tapping Run Loop button opens RunLoopSheet when onRunTap is null',
        (tester) async {
      final fakeRepo = _FakeLoopRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const Scaffold(
              body: LoopCard(loop: testLoop),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Run Loop" action pill
      await tester.tap(find.text('Run Loop'));
      await tester.pumpAndSettle();

      // Verify RunLoopSheet bottom sheet opened
      expect(find.byType(RunLoopSheet), findsOneWidget);
      expect(find.byKey(const Key('run_loop_bottom_sheet')), findsOneWidget);
      expect(find.text('Run council'), findsOneWidget);
    });
  });
}
