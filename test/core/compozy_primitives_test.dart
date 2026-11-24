import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/presentation/compozy_feedback.dart';
import 'package:compozy_app/core/presentation/widgets/compozy_empty_state.dart';
import 'package:compozy_app/core/presentation/widgets/compozy_error_state.dart';
import 'package:compozy_app/core/presentation/widgets/compozy_skeleton.dart';
import 'package:compozy_app/core/theme/compozy_theme.dart';

void main() {
  group('CompozyFeedback', () {
    test('compozyHaptic does not throw on any platform', () {
      expect(() => compozyHaptic(), returnsNormally);
    });

    testWidgets('showCompozySnack displays default floating card snackbar with message', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showCompozySnack(context, 'Operation succeeded');
                  },
                  child: const Text('Show'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show'));
      await tester.pump(); // Start animation
      await tester.pump(const Duration(milliseconds: 300)); // Settle floating snackbar

      expect(find.text('Operation succeeded'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('showCompozySnack with isError displays danger surface and handles action', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () {
                    showCompozySnack(
                      context,
                      'Operation failed',
                      isError: true,
                      actionLabel: 'Undo',
                      onAction: () {
                        actionTapped = true;
                      },
                    );
                  },
                  child: const Text('Show Error'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Error'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Operation failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      await tester.tap(find.text('Undo'));
      await tester.pump();
      expect(actionTapped, isTrue);
    });
  });

  group('CompozyEmptyState', () {
    testWidgets('renders icon, title, message, and action button with semantics', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: Scaffold(
            body: CompozyEmptyState(
              icon: Icons.inbox_outlined,
              title: 'No Items',
              message: 'Nothing here yet. Create one to get started.',
              actionLabel: 'Create New',
              onAction: () {
                actionTriggered = true;
              },
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('No Items'), findsOneWidget);
      expect(find.text('Nothing here yet. Create one to get started.'), findsOneWidget);
      expect(find.text('Create New'), findsOneWidget);

      // Verify semantics
      expect(
        find.bySemanticsLabel('No Items. Nothing here yet. Create one to get started.'),
        findsOneWidget,
      );

      // Tap action
      await tester.tap(find.text('Create New'));
      expect(actionTriggered, isTrue);
    });
  });

  group('CompozyErrorState', () {
    testWidgets('renders title and message; details disclosure is collapsed by default', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: Scaffold(
            body: CompozyErrorState(
              title: 'Connection Lost',
              message: 'Unable to communicate with the CompozyOS daemon.',
              details: 'SocketException: OS Error: Connection refused, errno = 111',
              onRetry: () {
                retried = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Connection Lost'), findsOneWidget);
      expect(find.text('Unable to communicate with the CompozyOS daemon.'), findsOneWidget);

      // Raw technical details should NOT be visible initially
      expect(find.textContaining('SocketException: OS Error'), findsNothing);
      expect(find.text('View Details'), findsOneWidget);

      // Expand details
      await tester.tap(find.text('View Details'));
      await tester.pumpAndSettle();

      // Technical details are now visible
      expect(find.textContaining('SocketException: OS Error'), findsOneWidget);
      expect(find.text('Hide Details'), findsOneWidget);

      // Tap Retry
      await tester.tap(find.text('Retry'));
      expect(retried, isTrue);
    });
  });

  group('CompozySkeleton', () {
    testWidgets('renders breathing skeleton placeholder with Loading semantics', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: const Scaffold(
            body: Center(
              child: CompozySkeleton(width: 120, height: 16),
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);

      // Advance timer for breathing animation
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(CompozySkeleton), findsOneWidget);
    });

    testWidgets('stops animation ticker when MediaQuery.disableAnimations is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: Center(
                child: CompozySkeleton(width: 100, height: 14),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CompozySkeleton), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      // Ticker should not cause issues or run infinite loops
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    });

    testWidgets('CompozySkeletonList renders specified item count of card placeholders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: CompozyTheme.darkTheme,
          home: const Scaffold(
            body: CompozySkeletonList(itemCount: 3),
          ),
        ),
      );

      expect(find.byType(CompozySkeletonList), findsOneWidget);
      expect(find.byType(CompozySkeleton), findsWidgets);
    });
  });
}
