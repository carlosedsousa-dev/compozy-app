import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/features/connection/presentation/connection_banner.dart';
import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/features/sessions/domain/models/session.dart';
import 'package:compozy_app/features/sessions/presentation/sessions_list_screen.dart';

void main() {
  final testSessions = [
    Session(
      id: 'sess-1',
      name: 'Loop Goal Designer',
      agent: 'designer',
      state: 'active',
      createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
    Session(
      id: 'sess-2',
      name: 'Bug Fixer Worker',
      agent: 'fixer',
      state: 'idle',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
    Session(
      id: 'sess-3',
      name: 'Strix Security Audit',
      agent: 'auditor',
      state: 'stopped',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];

  group('testSessionsListScreen (IT-002)', () {
    testWidgets('renders session cards with name, agent badge, and state badge', (tester) async {
      Session? tappedSession;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith((ref) => Future.value(testSessions)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: MaterialApp(
            home: SessionsListScreen(
              onSessionTap: (s) => tappedSession = s,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all session titles are rendered
      expect(find.text('Loop Goal Designer'), findsOneWidget);
      expect(find.text('Bug Fixer Worker'), findsOneWidget);
      expect(find.text('Strix Security Audit'), findsOneWidget);

      // Verify agent badges
      expect(find.text('designer'), findsOneWidget);
      expect(find.text('fixer'), findsOneWidget);
      expect(find.text('auditor'), findsOneWidget);

      // Verify state badges
      expect(find.text('active'), findsOneWidget);
      expect(find.text('idle'), findsOneWidget);
      expect(find.text('stopped'), findsOneWidget);

      // Tap on the first session card
      await tester.tap(find.text('Loop Goal Designer'));
      await tester.pump();
      expect(tappedSession?.id, 'sess-1');
    });

    testWidgets('handles pull-to-refresh trigger', (tester) async {
      int fetchCount = 0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith((ref) {
              fetchCount++;
              return Future.value(testSessions);
            }),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: SessionsListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(fetchCount, 1);

      // Pull down to trigger refresh
      await tester.fling(
        find.byKey(const Key('sessions_list_view')),
        const Offset(0.0, 300.0),
        1000.0,
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(fetchCount, greaterThanOrEqualTo(2));
    });

    testWidgets('filters sessions using filter chips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith((ref) => Future.value(testSessions)),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: SessionsListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially 'All' is selected -> all 3 cards present
      expect(find.text('Loop Goal Designer'), findsOneWidget);
      expect(find.text('Bug Fixer Worker'), findsOneWidget);
      expect(find.text('Strix Security Audit'), findsOneWidget);

      // Tap 'Active' filter chip
      await tester.tap(find.byKey(const Key('filter_chip_active')));
      await tester.pumpAndSettle();

      expect(find.text('Loop Goal Designer'), findsOneWidget);
      expect(find.text('Bug Fixer Worker'), findsNothing);
      expect(find.text('Strix Security Audit'), findsNothing);

      // Tap 'Stopped' filter chip
      await tester.tap(find.byKey(const Key('filter_chip_stopped')));
      await tester.pumpAndSettle();

      expect(find.text('Loop Goal Designer'), findsNothing);
      expect(find.text('Bug Fixer Worker'), findsNothing);
      expect(find.text('Strix Security Audit'), findsOneWidget);

      // Tap 'All' filter chip again
      await tester.tap(find.byKey(const Key('filter_chip_all')));
      await tester.pumpAndSettle();

      expect(find.text('Loop Goal Designer'), findsOneWidget);
      expect(find.text('Bug Fixer Worker'), findsOneWidget);
      expect(find.text('Strix Security Audit'), findsOneWidget);
    });

    testWidgets('renders empty state when no sessions found (US-002.AC-3)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith((ref) => Future.value(const [])),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: SessionsListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No sessions found'), findsOneWidget);
      expect(
        find.text('No active or recorded sessions in this workspace.'),
        findsOneWidget,
      );
    });

    testWidgets('renders error view with retry action on failure', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionsProvider.overrideWith((ref) {
              if (retried) {
                return Future.value(testSessions);
              }
              return Future.error(Exception('Network error'));
            }),
            connectionStatusProvider.overrideWith((ref) => Future.value(true)),
          ],
          child: const MaterialApp(
            home: SessionsListScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Failed to load sessions'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      retried = true;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Loop Goal Designer'), findsOneWidget);
    });
  });
}
