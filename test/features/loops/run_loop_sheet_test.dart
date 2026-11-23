import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/loops/data/loop_repository_impl.dart';
import 'package:compozy_app/features/loops/domain/repositories/loop_repository.dart';
import 'package:compozy_app/features/loops/presentation/run_loop_sheet.dart';

class _MockLoopRepository implements LoopRepository {
  final Map<String, dynamic> lastSubmittedInputs = {};
  String? lastSubmittedLoopName;
  bool shouldThrow = false;
  String errorMessage = 'Failed to launch loop';

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
    lastSubmittedLoopName = name;
    lastSubmittedInputs.clear();
    lastSubmittedInputs.addAll(inputs);

    if (shouldThrow) {
      throw Exception(errorMessage);
    }

    return const LoopRunResult(
      runId: 'run-loop-8831',
      status: 'queued',
      loopName: 'implement-tasks',
    );
  }
}

void main() {
  const testLoopWithInputs = LoopDefinition(
    name: 'implement-tasks',
    category: 'Engineering',
    description: 'Implement pending CompozyOS task files in dependency order.',
    contract: {
      'goal': 'Implement authored tasks under .compozy/tasks',
      'definition_of_done': 'All ready tasks completed and verified',
    },
    inputs: {
      'slug': {
        'type': 'string',
        'required': true,
        'description': 'Target task directory slug under .compozy/tasks',
      },
      'auto_commit': {
        'type': 'boolean',
        'default': false,
        'description': 'Whether to create atomic git commits per completed task',
      },
      'gate_command': {
        'type': 'string',
        'default': 'flutter test',
        'description': 'Verification command to run before task settlement',
      },
      'max_attempts': {
        'type': 'integer',
        'default': 3,
        'description': 'Maximum execution attempts per task node',
      },
    },
  );

  const testLoopWithoutInputs = LoopDefinition(
    name: 'quick-verify',
    category: 'Quality',
    description: 'Runs standard sanity verification across all services.',
    inputs: {},
  );

  group('testRunLoopSheet (IT-007)', () {
    testWidgets(
        'opens bottom sheet, parses loop inputs dynamically, and renders form fields (US-007.AC-1)',
        (tester) async {
      final mockRepo = _MockLoopRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const Scaffold(
              body: RunLoopSheet(loop: testLoopWithInputs),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and description
      expect(find.byKey(const Key('run_loop_bottom_sheet')), findsOneWidget);
      expect(find.text('Run implement-tasks'), findsOneWidget);
      expect(find.text('Engineering'), findsOneWidget);
      expect(
        find.text('Implement pending CompozyOS task files in dependency order.'),
        findsOneWidget,
      );

      // Verify parameters section header
      expect(find.text('PARAMETERS'), findsOneWidget);

      // Verify dynamic form fields parsed from loop.inputs
      expect(find.text('slug'), findsOneWidget);
      expect(find.text('* required'), findsWidgets);
      expect(find.text('auto_commit'), findsOneWidget);
      expect(find.text('gate_command'), findsOneWidget);
      expect(find.text('max_attempts'), findsOneWidget);

      // Verify default prefilled values
      expect(find.text('flutter test'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      // Verify submit button is rendered
      expect(find.byKey(const Key('run_loop_submit_button')), findsOneWidget);
      expect(find.text('Run Loop'), findsOneWidget);
    });

    testWidgets(
        'validates required parameters and prevents submission when required inputs are empty',
        (tester) async {
      final mockRepo = _MockLoopRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const Scaffold(
              body: RunLoopSheet(loop: testLoopWithInputs),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 'slug' is required and currently empty. Tap Run Loop without entering slug
      await tester.tap(find.byKey(const Key('run_loop_submit_button')));
      await tester.pumpAndSettle();

      // Repository runLoop should not have been called
      expect(mockRepo.lastSubmittedLoopName, isNull);

      // Validation error message should be displayed for slug
      expect(find.text('slug is required'), findsOneWidget);
    });

    testWidgets(
        'submits valid inputs, calls POST /api/loops/run, and displays resulting run ID and status (US-007.AC-2)',
        (tester) async {
      final mockRepo = _MockLoopRepository();
      LoopRunResult? completedResult;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: Scaffold(
              body: RunLoopSheet(
                loop: testLoopWithInputs,
                onRunCompleted: (result) => completedResult = result,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter required slug value
      await tester.enterText(
        find.byKey(const Key('run_loop_input_slug')),
        'compozy-app-v2',
      );

      // Toggle auto_commit switch to true
      await tester.tap(find.byKey(const Key('run_loop_input_auto_commit')));

      await tester.pumpAndSettle();

      // Tap submit button
      await tester.tap(find.byKey(const Key('run_loop_submit_button')));
      await tester.pumpAndSettle();

      // Verify repository was invoked with correct arguments
      expect(mockRepo.lastSubmittedLoopName, equals('implement-tasks'));
      expect(mockRepo.lastSubmittedInputs['slug'], equals('compozy-app-v2'));
      expect(mockRepo.lastSubmittedInputs['auto_commit'], equals(true));
      expect(mockRepo.lastSubmittedInputs['gate_command'], equals('flutter test'));
      expect(mockRepo.lastSubmittedInputs['max_attempts'], equals(3));

      // Verify callback was invoked
      expect(completedResult, isNotNull);
      expect(completedResult?.runId, equals('run-loop-8831'));
      expect(completedResult?.status, equals('queued'));

      // Verify UI displays resulting run ID and status (US-007.AC-2)
      expect(find.byKey(const Key('run_loop_success_banner')), findsOneWidget);
      expect(find.text('Loop Execution Dispatched'), findsOneWidget);
      expect(find.byKey(const Key('run_loop_result_id')), findsOneWidget);
      expect(find.text('run-loop-8831'), findsOneWidget);
      expect(find.byKey(const Key('run_loop_result_status')), findsOneWidget);
      expect(find.text('queued'), findsOneWidget);

      // Verify Done button is present
      expect(find.byKey(const Key('run_loop_done_button')), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('displays error banner when runLoop fails', (tester) async {
      final mockRepo = _MockLoopRepository()..shouldThrow = true;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const Scaffold(
              body: RunLoopSheet(loop: testLoopWithInputs),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter valid input so validation passes
      await tester.enterText(
        find.byKey(const Key('run_loop_input_slug')),
        'compozy-app-v2',
      );
      await tester.pumpAndSettle();

      // Tap submit
      await tester.tap(find.byKey(const Key('run_loop_submit_button')));
      await tester.pumpAndSettle();

      // Verify error view is rendered
      expect(find.byKey(const Key('run_loop_error')), findsOneWidget);
      expect(find.textContaining('Failed to launch loop'), findsOneWidget);
      expect(find.byKey(const Key('run_loop_success_banner')), findsNothing);
    });

    testWidgets('handles loop without inputs and submits successfully', (tester) async {
      final mockRepo = _MockLoopRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            loopRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: const Scaffold(
              body: RunLoopSheet(loop: testLoopWithoutInputs),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Empty parameters notice
      expect(find.byKey(const Key('run_loop_no_inputs')), findsOneWidget);
      expect(find.text('No input parameters required for this loop.'), findsOneWidget);

      // Submit immediately
      await tester.tap(find.byKey(const Key('run_loop_submit_button')));
      await tester.pumpAndSettle();

      expect(mockRepo.lastSubmittedLoopName, equals('quick-verify'));
      expect(find.byKey(const Key('run_loop_success_banner')), findsOneWidget);
    });
  });
}
