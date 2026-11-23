import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/sessions/domain/models/session_stream_event.dart';
import 'package:compozy_app/features/sessions/presentation/widgets/tool_execution_pill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('testToolExecutionPill (WT-005)', () {
    testWidgets('renders active state with spinner, active dot, and monospace font (US-006.AC-4)', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ToolExecutionPill(
              toolName: 'compozy__tool_search',
              status: 'in_progress',
              toolCallId: 'call_active_1',
            ),
          ),
        ),
      );

      await tester.pump();

      // Tool name text with "tool: <name>" format
      expect(find.text('tool: compozy__tool_search'), findsOneWidget);

      // Verify monospace typography and 11sp font size
      final textWidget = tester.widget<Text>(find.text('tool: compozy__tool_search'));
      expect(textWidget.style?.fontFamily, 'monospace');
      expect(textWidget.style?.fontSize, 11);
      expect(textWidget.style?.color, CompozyColors.fg);

      // Verify active indicators: spinner and active status dot
      expect(find.byKey(const Key('tool_pill_spinner')), findsOneWidget);
      expect(find.byKey(const Key('tool_pill_active_dot')), findsOneWidget);

      // Verify background container styling (#1A1A1A and pill radius)
      final containerFinder = find.ancestor(
        of: find.text('tool: compozy__tool_search'),
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);
      final container = tester.widget<Container>(containerFinder.first);
      final boxDecoration = container.decoration as BoxDecoration;
      expect(boxDecoration.color, const Color(0xFF1A1A1A));
      expect(boxDecoration.borderRadius, CompozyRadius.pill);
    });

    testWidgets('renders completed state with check icon and muted styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ToolExecutionPill(
              toolName: 'read_file',
              status: 'completed',
              toolCallId: 'call_completed_1',
            ),
          ),
        ),
      );

      await tester.pump();

      // Tool name text
      expect(find.text('tool: read_file'), findsOneWidget);

      // Check icon is displayed
      expect(find.byKey(const Key('tool_pill_check_icon')), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      // No active spinner or active dot
      expect(find.byKey(const Key('tool_pill_spinner')), findsNothing);
      expect(find.byKey(const Key('tool_pill_active_dot')), findsNothing);

      // Text color is muted for completed state
      final textWidget = tester.widget<Text>(find.text('tool: read_file'));
      expect(textWidget.style?.color, CompozyColors.muted);
    });

    testWidgets('renders failed state with error icon and danger styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ToolExecutionPill(
              toolName: 'run_command',
              status: 'failed',
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('tool: run_command'), findsOneWidget);
      expect(find.byKey(const Key('tool_pill_error_icon')), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      final textWidget = tester.widget<Text>(find.text('tool: run_command'));
      expect(textWidget.style?.color, CompozyColors.danger);
    });

    testWidgets('constructs from SessionToolExecutionEvent and handles expansion for details', (tester) async {
      const event = SessionToolExecutionEvent(
        toolName: 'git_status',
        status: 'completed',
        toolCallId: 'call_details_1',
        input: {'path': 'lib/', 'verbose': true},
        output: 'workspace clean',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ToolExecutionPill.fromEvent(event),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('tool: git_status'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);

      // Details container is initially collapsed
      expect(find.byKey(const Key('tool_pill_details_call_details_1')), findsNothing);

      // Tap to expand
      await tester.tap(find.text('tool: git_status'));
      await tester.pump();

      // Details container is now visible
      expect(find.byKey(const Key('tool_pill_details_call_details_1')), findsOneWidget);
      expect(find.textContaining('workspace clean'), findsOneWidget);
      expect(find.textContaining('verbose'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);

      // Tap to collapse
      await tester.tap(find.text('tool: git_status'));
      await tester.pump();

      expect(find.byKey(const Key('tool_pill_details_call_details_1')), findsNothing);
    });
  });
}
