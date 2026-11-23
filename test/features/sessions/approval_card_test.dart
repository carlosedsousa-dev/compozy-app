import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/sessions/domain/models/turn.dart';
import 'package:compozy_app/features/sessions/presentation/widgets/approval_card.dart';
import 'package:compozy_app/features/sessions/presentation/widgets/chat_bubble.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('testApprovalCardRendering (IT-008)', () {
    testWidgets('renders "Needs you" banner with #E8572A accent, 8x8dp dot, and tool description (US-008.AC-1)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: const Scaffold(
            body: ApprovalCard(
              toolName: 'run_command',
              description: 'Agent requests permission to execute command: rm -rf /tmp/cache',
              details: {'command': 'rm -rf /tmp/cache', 'cwd': '/home/carlos/Projetos'},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "Needs you" banner container
      final bannerFinder = find.byKey(const Key('approval_card_needs_you_banner'));
      expect(bannerFinder, findsOneWidget);
      expect(find.text('Needs you'), findsOneWidget);

      final bannerWidget = tester.widget<Container>(bannerFinder);
      final bannerDecoration = bannerWidget.decoration as BoxDecoration;
      // Background container: #E8572A with 12% opacity
      expect(bannerDecoration.color, equals(CompozyColors.accent.withValues(alpha: 0.12)));

      // Border: 1px #E8572A with 30% opacity
      final border = bannerDecoration.border as Border;
      expect(border.top.color, equals(CompozyColors.accent.withValues(alpha: 0.30)));
      expect(border.top.width, equals(1.0));

      // Solid 8x8dp #E8572A dot
      final dotFinder = find.byKey(const Key('approval_card_needs_you_dot'));
      expect(dotFinder, findsOneWidget);
      final dotWidget = tester.widget<Container>(dotFinder);
      expect(dotWidget.constraints?.maxWidth ?? 8.0, equals(8.0));
      expect(dotWidget.constraints?.maxHeight ?? 8.0, equals(8.0));
      final dotDecoration = dotWidget.decoration as BoxDecoration;
      expect(dotDecoration.color, equals(CompozyColors.accent));
      expect(dotDecoration.shape, equals(BoxShape.circle));

      // Verify tool name and monospace styling
      expect(find.text('tool: run_command'), findsOneWidget);
      final toolTextWidget = tester.widget<Text>(find.text('tool: run_command'));
      expect(toolTextWidget.style?.fontFamily, 'monospace');
      expect(toolTextWidget.style?.fontWeight, FontWeight.w600);

      // Verify tool call description
      expect(find.text('Agent requests permission to execute command: rm -rf /tmp/cache'), findsOneWidget);

      // Verify formatted arguments / details box
      expect(find.byKey(const Key('approval_card_details_box')), findsOneWidget);
      expect(find.textContaining('rm -rf /tmp/cache'), findsWidgets);
      expect(find.textContaining('/home/carlos/Projetos'), findsWidgets);
    });

    testWidgets('renders "Approve" monochrome pill and "Reject" outlined pill (US-008.AC-2)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: const Scaffold(
            body: ApprovalCard(
              description: 'Permission to modify production database credentials.',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Approve button (strictly inverted monochrome pill: #F5F5F5 background, #0A0A0A bold text)
      final approveFinder = find.byKey(const Key('approval_card_approve_button'));
      expect(approveFinder, findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);

      final approveContainerFinder = find.ancestor(
        of: find.text('Approve'),
        matching: find.byType(Container),
      );
      final approveContainer = tester.widget<Container>(approveContainerFinder.first);
      final approveDecoration = approveContainer.decoration as BoxDecoration;
      expect(approveDecoration.color, equals(CompozyColors.primary)); // #F5F5F5
      expect(approveDecoration.borderRadius, equals(CompozyRadius.pill));

      final approveText = tester.widget<Text>(find.text('Approve'));
      expect(approveText.style?.color, equals(CompozyColors.primaryInk)); // #0A0A0A
      expect(approveText.style?.fontWeight, equals(FontWeight.w600));

      // Verify Reject button (outlined pill: transparent background, 1px border)
      final rejectFinder = find.byKey(const Key('approval_card_reject_button'));
      expect(rejectFinder, findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      final rejectContainerFinder = find.ancestor(
        of: find.text('Reject'),
        matching: find.byType(Container),
      );
      final rejectContainer = tester.widget<Container>(rejectContainerFinder.first);
      final rejectDecoration = rejectContainer.decoration as BoxDecoration;
      expect(rejectDecoration.color, equals(Colors.transparent));
      expect(rejectDecoration.borderRadius, equals(CompozyRadius.pill));
      expect(rejectDecoration.border, isNotNull);

      final rejectText = tester.widget<Text>(find.text('Reject'));
      expect(rejectText.style?.color, equals(CompozyColors.fg));
      expect(rejectText.style?.fontWeight, equals(FontWeight.w600));
    });

    testWidgets('renders resolved status badges when decision is already settled', (tester) async {
      // Approved state
      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: const Scaffold(
            body: ApprovalCard(
              description: 'Command execution',
              isApproved: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('approval_card_resolved_approved')), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);

      // Rejected state
      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: const Scaffold(
            body: ApprovalCard(
              description: 'File deletion',
              isApproved: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('approval_card_resolved_rejected')), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('embeds into TurnWidget when turn status is waiting_for_approval', (tester) async {
      const turn = Turn(
        turnId: 'turn-approval-1',
        userMessage: 'Delete unneeded files',
        agentMessage: 'I need your confirmation before deleting /var/log/app.log.',
        status: 'waiting_for_approval',
        toolCalls: ['file_delete'],
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: const Scaffold(
            body: TurnWidget(
              turn: turn,
              agentName: 'fixer',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify TurnWidget renders ApprovalCard with "Needs you" banner
      expect(find.byKey(const Key('turn_approval_card_turn-approval-1')), findsOneWidget);
      expect(find.text('Needs you'), findsOneWidget);
      expect(find.text('tool: file_delete'), findsOneWidget);
      expect(find.text('I need your confirmation before deleting /var/log/app.log.'), findsWidgets);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
    });
  });
}
