import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/network/compozy_api_client.dart';
import 'package:compozy_app/core/theme/compozy_theme.dart';
import 'package:compozy_app/main.dart';

/// Deterministic mock HTTP adapter simulating CompozyOS REST daemon endpoints.
class _E2EMockHttpAdapter implements HttpClientAdapter {
  final List<Map<String, dynamic>> sessions;
  final Map<String, List<Map<String, dynamic>>> history;
  final List<Map<String, dynamic>> loops;
  bool isOnline;
  final List<String> receivedPrompts = [];

  _E2EMockHttpAdapter({
    required this.sessions,
    required this.history,
    required this.loops,
    this.isOnline = true,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!isOnline) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
        error: 'Failed to connect to localhost:2123',
      );
    }

    final path = options.path;

    // 1. Healthcheck: GET /api/openapi.json
    if (path == '/api/openapi.json') {
      return ResponseBody.fromString(
        jsonEncode({
          'openapi': '3.1.0',
          'info': {
            'title': 'CompozyOS Local Daemon',
            'version': '1.0.0',
          },
          'paths': {},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // 2. Sessions list: GET /api/sessions
    if (path == '/api/sessions') {
      return ResponseBody.fromString(
        jsonEncode({'sessions': sessions}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // 3. Single session details: GET /api/sessions/:id
    final sessionRegex = RegExp(r'^/api/sessions/([^/]+)$');
    final sessionMatch = sessionRegex.firstMatch(path);
    if (sessionMatch != null) {
      final id = sessionMatch.group(1);
      final found = sessions.firstWhere(
        (s) => s['id'] == id,
        orElse: () => {
          'id': id,
          'name': 'Session $id',
          'agent_name': 'general',
          'state': 'active',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      return ResponseBody.fromString(
        jsonEncode({'session': found}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // 4. Session history: GET /api/sessions/:id/history
    final historyRegex = RegExp(r'^/api/sessions/([^/]+)/history$');
    final historyMatch = historyRegex.firstMatch(path);
    if (historyMatch != null) {
      final id = historyMatch.group(1)!;
      final turns = history[id] ?? [];
      return ResponseBody.fromString(
        jsonEncode({'history': turns}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // 5. Prompt submit: POST /api/sessions/:id/prompt
    final promptRegex = RegExp(r'^/api/sessions/([^/]+)/prompt$');
    final promptMatch = promptRegex.firstMatch(path);
    if (promptMatch != null && options.method.toUpperCase() == 'POST') {
      final id = promptMatch.group(1)!;
      dynamic body = options.data;
      if (body is String) {
        body = jsonDecode(body);
      }
      final promptText = body is Map ? body['prompt']?.toString() ?? '' : '';
      receivedPrompts.add(promptText);

      // Append completed turn to history so next history fetch reflects the new turn
      final currentTurns = history.putIfAbsent(id, () => []);
      final nextTurnId = 'turn-${currentTurns.length + 1}';
      currentTurns.add({
        'turn_id': nextTurnId,
        'user_message': promptText,
        'agent_message':
            'Response to "$promptText" generated successfully.',
        'status': 'completed',
        'tool_calls': ['compozy__tool_search'],
      });

      return ResponseBody.fromString(
        jsonEncode({
          'status': 'queued',
          'turn_id': nextTurnId,
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // 6. Loops catalog: GET /api/loops
    if (path == '/api/loops') {
      return ResponseBody.fromString(
        jsonEncode({'loops': loops}),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }

    // Fallback 404
    return ResponseBody.fromString(
      jsonEncode({'error': 'Not found: $path'}),
      404,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('E2E-001: End-to-End Live Integration Flow', () {
    late List<Map<String, dynamic>> mockSessions;
    late Map<String, List<Map<String, dynamic>>> mockHistory;
    late List<Map<String, dynamic>> mockLoops;

    setUp(() {
      mockSessions = [
        {
          'id': 'sess-mvp-1',
          'name': 'Loop Goal Designer',
          'agent_name': 'designer',
          'state': 'active',
          'created_at':
              DateTime.now().subtract(const Duration(minutes: 20)).toIso8601String(),
          'updated_at':
              DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
        },
        {
          'id': 'sess-mvp-2',
          'name': 'Bug Fixer Worker',
          'agent_name': 'fixer',
          'state': 'idle',
          'created_at':
              DateTime.now().subtract(const Duration(hours: 1)).toIso8601String(),
          'updated_at':
              DateTime.now().subtract(const Duration(minutes: 15)).toIso8601String(),
        },
      ];

      mockHistory = {
        'sess-mvp-1': [
          {
            'turn_id': 'turn-1',
            'user_message': 'Analyze repository structure and dependencies',
            'agent_message':
                'Found Flutter application with Riverpod and Dio architecture.',
            'status': 'completed',
            'tool_calls': ['read_file', 'compozy__tool_search'],
          },
        ],
      };

      mockLoops = [
        {
          'name': 'council',
          'category': 'Engineering',
          'description':
              'Three independent seats analyze one architectural question and synthesize findings.',
          'contract': {
            'goal': 'Deliver consensus recommendation with trade-offs',
            'definition_of_done':
                'All three seats conclude analysis with unanimous or split recommendation',
          },
          'inputs': {
            'topic': {
              'type': 'string',
              'description': 'The architectural decision topic to debate',
            },
          },
        },
        {
          'name': 'overnight',
          'category': 'Automation',
          'description':
              'Runs continuous overnight task queue execution until all ready tasks complete.',
          'contract': {
            'goal': 'Execute all ready tasks in dependency order',
            'definition_of_done': 'No remaining ready tasks in task graph',
          },
          'inputs': {},
        },
      ];
    });

    testWidgets(
      'testCompleteSessionInteraction - complete user journey: connect -> list sessions -> open chat -> send prompt -> receive response',
      (tester) async {
        tester.view.physicalSize = const Size(400, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockAdapter = _E2EMockHttpAdapter(
          sessions: mockSessions,
          history: mockHistory,
          loops: mockLoops,
        );

        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
        dio.httpClientAdapter = mockAdapter;
        final apiClient = CompozyApiClient(dio: dio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              compozyApiClientProvider.overrideWithValue(apiClient),
            ],
            child: const MyApp(),
          ),
        );

        await tester.pumpAndSettle();

        // ---------------------------------------------------------------------
        // STEP 1: Connectivity check and App Shell (US-001.AC-1)
        // ---------------------------------------------------------------------
        // Verify workspace title in AppBar
        expect(find.text('compozy-app'), findsOneWidget);

        // Verify connection indicator displays online in green
        expect(find.byKey(const Key('connection_pill_online')), findsOneWidget);
        expect(find.text('online'), findsOneWidget);
        final statusText = tester.widget<Text>(find.text('online'));
        expect(statusText.style?.color, CompozyColors.success);

        // Verify offline error banner is NOT displayed
        expect(find.byKey(const Key('connection_banner_offline')), findsNothing);

        // Verify bottom navigation bar exists with destinations
        expect(find.text('Sessions'), findsOneWidget);
        expect(find.text('Loops'), findsOneWidget);
        expect(find.text('Settings'), findsOneWidget);

        // ---------------------------------------------------------------------
        // STEP 2: Sessions List display and filtering (US-002.AC-1)
        // ---------------------------------------------------------------------
        // Verify sessions are listed with name, agent badge, and state badge
        expect(find.text('Loop Goal Designer'), findsOneWidget);
        expect(find.text('Bug Fixer Worker'), findsOneWidget);

        expect(find.text('designer'), findsOneWidget);
        expect(find.text('fixer'), findsOneWidget);

        expect(find.text('active'), findsOneWidget);
        expect(find.text('idle'), findsOneWidget);

        // Verify filter chips work on the live list
        await tester.tap(find.byKey(const Key('filter_chip_active')));
        await tester.pumpAndSettle();

        expect(find.text('Loop Goal Designer'), findsOneWidget);
        expect(find.text('Bug Fixer Worker'), findsNothing);

        // Reset filter back to All
        await tester.tap(find.byKey(const Key('filter_chip_all')));
        await tester.pumpAndSettle();

        expect(find.text('Loop Goal Designer'), findsOneWidget);
        expect(find.text('Bug Fixer Worker'), findsOneWidget);

        // ---------------------------------------------------------------------
        // STEP 3: Navigate to Session Chat (US-003.AC-1)
        // ---------------------------------------------------------------------
        // Tap session card to open chat view
        await tester.tap(find.text('Loop Goal Designer'));
        await tester.pumpAndSettle();

        // Verify Chat Screen AppBar details
        expect(find.text('Loop Goal Designer'), findsOneWidget);
        expect(find.byKey(const Key('chat_back_button')), findsOneWidget);

        // Verify existing turn history rendered with distinct user & agent bubbles
        expect(
          find.text('Analyze repository structure and dependencies'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Found Flutter application with Riverpod and Dio architecture.',
          ),
          findsOneWidget,
        );

        // Verify tool invocation pills rendered
        expect(find.text('2 tools executed'), findsOneWidget);

        // Expand tool pill
        await tester.tap(find.byKey(const Key('tool_pill_toggle_turn-1')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const Key('tool_call_turn-1_read_file')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('tool_call_turn-1_compozy__tool_search')),
          findsOneWidget,
        );

        // ---------------------------------------------------------------------
        // STEP 4: Submit Prompt & Receive Agent Response (US-003.AC-2, US-003.AC-3)
        // ---------------------------------------------------------------------
        const newPrompt = 'Implement Task 08 integration flow test';

        // Enter prompt into the input field
        await tester.enterText(
          find.byKey(const Key('prompt_input_field')),
          newPrompt,
        );
        await tester.pump();

        // Tap send button
        await tester.tap(find.byKey(const Key('prompt_send_button')));
        await tester.pump();

        // Verify optimistic bubble appears immediately with user prompt
        expect(find.text(newPrompt), findsOneWidget);

        // Verify prompt input field was cleared
        final inputField = tester.widget<TextField>(
          find.byKey(const Key('prompt_input_field')),
        );
        expect(inputField.controller?.text, isEmpty);

        // Settle after async prompt dispatch and transcript refresh
        await tester.pumpAndSettle();

        // Verify prompt was dispatched to the mock daemon adapter
        expect(mockAdapter.receivedPrompts, contains(newPrompt));

        // Verify agent response is rendered in the chat transcript
        expect(
          find.textContaining('Response to "$newPrompt" generated successfully.'),
          findsOneWidget,
        );

        // ---------------------------------------------------------------------
        // STEP 5: Back navigation to Sessions list
        // ---------------------------------------------------------------------
        await tester.tap(find.byKey(const Key('chat_back_button')));
        await tester.pumpAndSettle();

        // Verify back on Sessions list screen
        expect(find.text('Loop Goal Designer'), findsOneWidget);
        expect(find.text('Bug Fixer Worker'), findsOneWidget);

        // ---------------------------------------------------------------------
        // STEP 6: Loops tab navigation (US-004 integration)
        // ---------------------------------------------------------------------
        await tester.tap(find.text('Loops'));
        await tester.pumpAndSettle();

        // Verify Loops catalog screen is displayed
        expect(find.text('Loops Catalog'), findsOneWidget);
        expect(find.text('council'), findsOneWidget);
        expect(find.text('overnight'), findsOneWidget);

        // Tap on loop card to inspect details bottom sheet
        await tester.tap(find.text('council'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('loop_details_bottom_sheet')), findsOneWidget);
        expect(
          find.text('Deliver consensus recommendation with trade-offs'),
          findsOneWidget,
        );

        // Close bottom sheet
        await tester.tap(find.byKey(const Key('close_loop_details_sheet_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('loop_details_bottom_sheet')), findsNothing);

        // Switch back to Sessions tab
        await tester.tap(find.text('Sessions'));
        await tester.pumpAndSettle();
        expect(find.text('Loop Goal Designer'), findsOneWidget);
      },
    );

    testWidgets(
      'testCompleteSessionInteractionOnDesktopLayout - verifies flow on wide screen (>=600dp) with NavigationRail',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockAdapter = _E2EMockHttpAdapter(
          sessions: mockSessions,
          history: mockHistory,
          loops: mockLoops,
        );

        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
        dio.httpClientAdapter = mockAdapter;
        final apiClient = CompozyApiClient(dio: dio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              compozyApiClientProvider.overrideWithValue(apiClient),
            ],
            child: const MyApp(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify NavigationRail is rendered on desktop/tablet layout
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(BottomNavigationBar), findsNothing);

        // Verify connectivity pill in AppBar
        expect(find.byKey(const Key('connection_pill_online')), findsOneWidget);

        // Verify sessions list cards
        expect(find.text('Loop Goal Designer'), findsOneWidget);

        // Open chat screen
        await tester.tap(find.text('Loop Goal Designer'));
        await tester.pumpAndSettle();

        expect(find.text('Loop Goal Designer'), findsOneWidget);
        expect(
          find.text('Analyze repository structure and dependencies'),
          findsOneWidget,
        );

        // Submit prompt
        await tester.enterText(
          find.byKey(const Key('prompt_input_field')),
          'Desktop view verification prompt',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('prompt_send_button')));
        await tester.pumpAndSettle();

        expect(
          find.text('Desktop view verification prompt'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Response to "Desktop view verification prompt" generated successfully.'),
          findsOneWidget,
        );

        // Navigate back
        await tester.tap(find.byKey(const Key('chat_back_button')));
        await tester.pumpAndSettle();

        expect(find.text('Loop Goal Designer'), findsOneWidget);
      },
    );

    testWidgets(
      'testDaemonOfflineAndRecoveryFlow - handles unreachable daemon and recovers on retry',
      (tester) async {
        final mockAdapter = _E2EMockHttpAdapter(
          sessions: mockSessions,
          history: mockHistory,
          loops: mockLoops,
          isOnline: false,
        );

        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
        dio.httpClientAdapter = mockAdapter;
        final apiClient = CompozyApiClient(dio: dio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              compozyApiClientProvider.overrideWithValue(apiClient),
            ],
            child: const MyApp(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify offline pill and offline banner
        expect(find.byKey(const Key('connection_pill_offline')), findsOneWidget);
        expect(find.text('offline'), findsOneWidget);
        final offlineText = tester.widget<Text>(find.text('offline'));
        expect(offlineText.style?.color, CompozyColors.danger);

        expect(find.byKey(const Key('connection_banner_offline')), findsOneWidget);
        expect(find.text('Disconnected'), findsOneWidget);

        // Bring daemon back online
        mockAdapter.isOnline = true;

        // Tap connection retry button
        await tester.tap(find.byKey(const Key('connection_retry_button')));
        await tester.pumpAndSettle();

        // Verify connection transitioned to online
        expect(find.byKey(const Key('connection_pill_online')), findsOneWidget);
        expect(find.text('online'), findsOneWidget);

        // Tap retry on session list error view to reload sessions
        expect(find.text('Failed to load sessions'), findsOneWidget);
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        // Sessions now appear cleanly
        expect(find.text('Loop Goal Designer'), findsOneWidget);
        expect(find.text('Bug Fixer Worker'), findsOneWidget);
      },
    );
  });
}
