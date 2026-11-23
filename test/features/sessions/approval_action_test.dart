import 'dart:async';

import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/features/sessions/domain/models/session.dart';
import 'package:compozy_app/features/sessions/domain/models/session_stream_event.dart';
import 'package:compozy_app/features/sessions/domain/models/turn.dart';
import 'package:compozy_app/features/sessions/domain/repositories/session_repository.dart';
import 'package:compozy_app/features/sessions/presentation/session_chat_screen.dart';
import 'package:compozy_app/features/sessions/presentation/widgets/approval_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _MockSessionRepository implements SessionRepository {
  List<Turn> turns = [];
  String? lastApprovedSessionId;
  bool? lastApprovalDecision;
  String? lastApprovalId;

  _MockSessionRepository({List<Turn>? initialTurns})
      : turns = initialTurns ?? [];

  @override
  Future<List<Session>> getSessions({String? state, int? limit}) async => [];

  @override
  Future<Session> getSession(String sessionId) async => throw UnimplementedError();

  @override
  Future<List<Turn>> getSessionHistory(String sessionId, {int? limit}) async => turns;

  @override
  Future<void> sendPrompt(String sessionId, String message) async {}

  @override
  Future<void> respondToApproval(
    String sessionId, {
    required bool approved,
    String? approvalId,
  }) async {
    lastApprovedSessionId = sessionId;
    lastApprovalDecision = approved;
    lastApprovalId = approvalId;
  }
}

void main() {
  final testSession = Session(
    id: 'sess-approval-1',
    name: 'Approval Test Session',
    agent: 'designer',
    state: 'active',
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    updatedAt: DateTime.now(),
  );

  group('testApprovalActionTrigger (WT-007)', () {
    testWidgets('triggers onApprove and onDecision(true) when Approve button is pressed (US-008.AC-2)', (tester) async {
      bool approvedCalled = false;
      bool? decisionValue;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: Scaffold(
            body: ApprovalCard(
              toolName: 'shell_exec',
              description: 'Run deployment script',
              onApprove: () => approvedCalled = true,
              onDecision: (val) => decisionValue = val,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(approvedCalled, isFalse);
      expect(decisionValue, isNull);

      // Tap Approve
      await tester.tap(find.byKey(const Key('approval_card_approve_button')));
      await tester.pumpAndSettle();

      expect(approvedCalled, isTrue);
      expect(decisionValue, isTrue);
    });

    testWidgets('triggers onReject and onDecision(false) when Reject button is pressed (US-008.AC-2)', (tester) async {
      bool rejectCalled = false;
      bool? decisionValue;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: Scaffold(
            body: ApprovalCard(
              toolName: 'write_file',
              description: 'Overwrite config.json',
              onReject: () => rejectCalled = true,
              onDecision: (val) => decisionValue = val,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(rejectCalled, isFalse);
      expect(decisionValue, isNull);

      // Tap Reject
      await tester.tap(find.byKey(const Key('approval_card_reject_button')));
      await tester.pumpAndSettle();

      expect(rejectCalled, isTrue);
      expect(decisionValue, isFalse);
    });

    testWidgets('disables action triggers when isProcessing is true', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: Scaffold(
            body: ApprovalCard(
              description: 'Pending processing...',
              isProcessing: true,
              onApprove: () => tapped = true,
              onReject: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify spinner is rendered
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Tap Approve while processing
      await tester.tap(find.byKey(const Key('approval_card_approve_button')));
      await tester.pump();
      expect(tapped, isFalse);

      // Tap Reject while processing
      await tester.tap(find.byKey(const Key('approval_card_reject_button')));
      await tester.pump();
      expect(tapped, isFalse);
    });

    testWidgets('SessionChatScreen handles live approval request stream event and invokes respondToApproval', (tester) async {
      final mockRepo = _MockSessionRepository(initialTurns: const []);
      final streamController = StreamController<SessionStreamEvent>.broadcast();
      addTearDown(() => streamController.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(mockRepo),
            sessionStreamProvider(testSession.id).overrideWith((ref) => streamController.stream),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially no approval cards
      expect(find.byType(ApprovalCard), findsNothing);

      // 1. Emit live SessionApprovalRequestEvent
      streamController.add(
        const SessionApprovalRequestEvent(
          toolName: 'execute_migration',
          description: 'Permission required to run DB schema migration.',
          input: {'migration': '001_init.sql', 'target': 'production'},
          approvalId: 'appr-req-99',
          sessionId: 'sess-approval-1',
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // ApprovalCard is now visible in the live chat flow with "Needs you" banner
      expect(find.byType(ApprovalCard), findsOneWidget);
      expect(find.text('Needs you'), findsOneWidget);
      expect(find.text('tool: execute_migration'), findsOneWidget);
      expect(find.text('Permission required to run DB schema migration.'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      // 2. User taps Approve button
      await tester.tap(find.byKey(const Key('approval_card_approve_button')));
      await tester.pumpAndSettle();

      // Verify repository method was called
      expect(mockRepo.lastApprovedSessionId, equals('sess-approval-1'));
      expect(mockRepo.lastApprovalDecision, isTrue);
      expect(mockRepo.lastApprovalId, equals('appr-req-99'));

      // Feedback snackbar appears and card is resolved
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Tool execution approved.'), findsOneWidget);
      expect(find.byType(ApprovalCard), findsNothing);
    });

    testWidgets('SessionChatScreen handles tool execution event waiting_for_approval and invokes respondToApproval with reject', (tester) async {
      final mockRepo = _MockSessionRepository(initialTurns: const []);
      final streamController = StreamController<SessionStreamEvent>.broadcast();
      addTearDown(() => streamController.close());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionRepositoryProvider.overrideWithValue(mockRepo),
            sessionStreamProvider(testSession.id).overrideWith((ref) => streamController.stream),
          ],
          child: MaterialApp(
            theme: CompozyTheme.darkTheme,
            home: SessionChatScreen(session: testSession),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Emit tool execution event with status waiting_for_approval
      streamController.add(
        const SessionToolExecutionEvent(
          toolName: 'delete_branch',
          status: 'waiting_for_approval',
          toolCallId: 'tool-call-del-1',
          sessionId: 'sess-approval-1',
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // ApprovalCard is rendered
      expect(find.byType(ApprovalCard), findsOneWidget);
      expect(find.text('Needs you'), findsOneWidget);
      expect(find.text('tool: delete_branch'), findsOneWidget);

      // User taps Reject button
      await tester.tap(find.byKey(const Key('approval_card_reject_button')));
      await tester.pumpAndSettle();

      // Verify repository method was called with false
      expect(mockRepo.lastApprovedSessionId, equals('sess-approval-1'));
      expect(mockRepo.lastApprovalDecision, isFalse);
      expect(mockRepo.lastApprovalId, equals('tool-call-del-1'));

      // SnackBar shows rejected feedback
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Tool execution rejected.'), findsOneWidget);
      expect(find.byType(ApprovalCard), findsNothing);
    });
  });
}
