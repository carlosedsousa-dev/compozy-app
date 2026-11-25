import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:compozy_app/core/network/compozy_api_client.dart';
import 'package:compozy_app/core/network/health_checker.dart';
import 'package:compozy_app/core/presentation/app_shell.dart';
import 'package:compozy_app/core/settings/settings.dart';
import 'package:compozy_app/core/settings/settings_repository.dart';
import 'package:compozy_app/features/sessions/data/session_stream_repository_impl.dart';
import 'package:compozy_app/features/sessions/domain/models/session_stream_event.dart';
import 'package:compozy_app/features/sessions/presentation/widgets/approval_card.dart';
import 'package:compozy_app/features/sessions/presentation/widgets/subagents_drawer.dart';
import 'package:compozy_app/features/sessions/presentation/widgets/tool_execution_pill.dart';
import 'package:compozy_app/features/settings/presentation/settings_screen.dart';
import 'package:compozy_app/main.dart';

/// In-memory implementation of [SettingsRepository] for deterministic E2E state control.
class _InMemorySettingsRepo implements SettingsRepository {
  Settings _settings;

  _InMemorySettingsRepo([Settings? initial])
      : _settings = initial ?? const Settings(themeMode: ThemeMode.dark);

  @override
  Settings? get cachedSettings => _settings;

  @override
  Future<Settings> loadSettings() async => _settings;

  @override
  Future<Settings> getSettings() async => _settings;

  @override
  Future<void> saveSettings(Settings settings) async {
    _settings = settings;
  }

  @override
  Future<void> updateSettings(Settings settings) async {
    _settings = settings;
  }
}

class _FakeHealthChecker extends HealthChecker {
  final bool healthy;

  _FakeHealthChecker({required this.healthy}) : super(baseUrl: 'http://localhost:2123');

  @override
  Future<bool> checkHealth() async => healthy;
}

/// Comprehensive mock HTTP adapter simulating all CompozyOS v2 REST daemon endpoints.
class _E2EMockHttpAdapterV2 implements HttpClientAdapter {
  final List<Map<String, dynamic>> sessions;
  final Map<String, List<Map<String, dynamic>>> history;
  final List<Map<String, dynamic>> loops;
  final List<String> receivedPrompts = [];
  final List<Map<String, dynamic>> receivedApprovals = [];
  final List<Map<String, dynamic>> receivedLoopRuns = [];

  _E2EMockHttpAdapterV2({
    required this.sessions,
    required this.history,
    required this.loops,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;

    // 1. Healthcheck: GET /api/openapi.json
    if (path == '/api/openapi.json') {
      return ResponseBody.fromString(
        jsonEncode({
          'openapi': '3.1.0',
          'info': {
            'title': 'CompozyOS Local Daemon',
            'version': '2.0.0',
          },
          'paths': {},
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // 2. Sessions list: GET /api/sessions or /api/workspaces/:ws/sessions
    if (path == '/api/sessions' || RegExp(r'^/api/workspaces/[^/]+/sessions$').hasMatch(path)) {
      return ResponseBody.fromString(
        jsonEncode({'sessions': sessions}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // 3. Single session details: GET /api/sessions/:id
    final sessionRegex = RegExp(r'^/api/(?:workspaces/[^/]+/)?sessions/([^/]+)$');
    final sessionMatch = sessionRegex.firstMatch(path);
    if (sessionMatch != null && options.method.toUpperCase() == 'GET') {
      final id = sessionMatch.group(1);
      final found = sessions.firstWhere(
        (s) => s['id'] == id,
        orElse: () => {
          'id': id,
          'name': 'Session $id',
          'agent_name': 'fixer',
          'state': 'active',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      return ResponseBody.fromString(
        jsonEncode({'session': found}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // 4. Session history: GET /api/sessions/:id/history
    final historyRegex = RegExp(r'^/api/(?:workspaces/[^/]+/)?sessions/([^/]+)/history$');
    final historyMatch = historyRegex.firstMatch(path);
    if (historyMatch != null) {
      final id = historyMatch.group(1)!;
      final turns = history[id] ?? [];
      return ResponseBody.fromString(
        jsonEncode({'history': turns}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // 5. Prompt submit: POST /api/sessions/:id/prompt
    final promptRegex = RegExp(r'^/api/(?:workspaces/[^/]+/)?sessions/([^/]+)/prompt$');
    final promptMatch = promptRegex.firstMatch(path);
    if (promptMatch != null && options.method.toUpperCase() == 'POST') {
      final id = promptMatch.group(1)!;
      dynamic body = options.data;
      if (body is String) body = jsonDecode(body);
      final promptText = body is Map ? body['prompt']?.toString() ?? '' : '';
      receivedPrompts.add(promptText);

      final currentTurns = history.putIfAbsent(id, () => []);
      final nextTurnId = 'turn-${currentTurns.length + 1}';
      currentTurns.add({
        'turn_id': nextTurnId,
        'user_message': promptText,
        'agent_message': 'Response to "$promptText" processed.',
        'status': 'completed',
        'tool_calls': ['compozy__tool_search'],
      });

      return ResponseBody.fromString(
        jsonEncode({'status': 'queued', 'turn_id': nextTurnId}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // 6. Approval response: POST /api/sessions/:id/approve
    final approvalRegex = RegExp(r'^/api/(?:workspaces/[^/]+/)?sessions/([^/]+)/approve$');
    final approvalMatch = approvalRegex.firstMatch(path);
    if (approvalMatch != null && options.method.toUpperCase() == 'POST') {
      final id = approvalMatch.group(1)!;
      dynamic body = options.data;
      if (body is String) body = jsonDecode(body);
      final payload = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
      payload['session_id'] = id;
      receivedApprovals.add(payload);

      return ResponseBody.fromString(
        jsonEncode({'status': 'approved', 'session_id': id}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // 7. Loops catalog: GET /api/loops or /api/workspaces/:ws/loops
    if (path == '/api/loops' || RegExp(r'^/api/workspaces/[^/]+/loops$').hasMatch(path)) {
      return ResponseBody.fromString(
        jsonEncode({'loops': loops}),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // 8. Run loop: POST /api/loops/run or /api/workspaces/:ws/loops/run
    final runLoopRegex = RegExp(r'^/api/(?:workspaces/[^/]+/)?loops/run$');
    if (runLoopRegex.hasMatch(path) && options.method.toUpperCase() == 'POST') {
      dynamic body = options.data;
      if (body is String) body = jsonDecode(body);
      final payload = body is Map ? Map<String, dynamic>.from(body) : <String, dynamic>{};
      receivedLoopRuns.add(payload);

      return ResponseBody.fromString(
        jsonEncode({
          'run_id': 'run-loop-8831',
          'status': 'queued',
          'loop_name': payload['name'] ?? payload['loop_name'] ?? 'implement-tasks',
        }),
        200,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
      );
    }

    // 404 Fallback
    return ResponseBody.fromString(
      jsonEncode({'error': 'Not found: $path'}),
      404,
      headers: {Headers.contentTypeHeader: [Headers.jsonContentType]},
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('E2E-002: Full V2 Regression & Autonomous Integration Flow', () {
    late List<Map<String, dynamic>> mockSessions;
    late Map<String, List<Map<String, dynamic>>> mockHistory;
    late List<Map<String, dynamic>> mockLoops;
    late List<SubagentItem> mockSubagents;
    late StreamController<SessionStreamEvent> streamController;

    setUp(() {
      streamController = StreamController<SessionStreamEvent>.broadcast();

      mockSessions = [
        {
          'id': 'sess-v2-1',
          'name': 'Loop Goal Fixer',
          'agent_name': 'fixer',
          'state': 'active',
          'created_at': DateTime.now().subtract(const Duration(minutes: 30)).toIso8601String(),
          'updated_at': DateTime.now().subtract(const Duration(minutes: 2)).toIso8601String(),
        },
      ];

      mockHistory = {
        'sess-v2-1': [
          {
            'turn_id': 'turn-v2-init',
            'user_message': 'Initialize Task 08 integration flow verification',
            'agent_message': 'Ready to verify complete v2 suite.',
            'status': 'completed',
            'tool_calls': ['compozy__tool_search'],
          },
        ],
      };

      mockLoops = [
        {
          'name': 'implement-tasks',
          'category': 'Engineering',
          'description': 'Implement pending CompozyOS task files in dependency order.',
          'contract': {
            'goal': 'Implement authored tasks under .compozy/tasks',
            'definition_of_done': 'All ready tasks completed and verified',
          },
          'inputs': {
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
            'max_attempts': {
              'type': 'integer',
              'default': 3,
              'description': 'Maximum execution attempts per task node',
            },
          },
        },
      ];

      mockSubagents = [
        const SubagentItem(
          id: 'sub-researcher-1',
          role: 'researcher',
          name: 'Codebase Researcher',
          state: 'working',
          model: 'gemini-3.8-flash',
          runtimeTag: 'mcp:host',
          depth: 1,
          brief: 'Investigating repository dependencies and structure',
        ),
        const SubagentItem(
          id: 'sub-terminal-2',
          role: 'terminal',
          name: 'Terminal Worker',
          state: 'waiting',
          model: 'gemini-3.8-pro',
          runtimeTag: 'terminal:pty',
          depth: 1,
          brief: 'Executing headless AVD verification suite',
        ),
      ];
    });

    tearDown(() {
      streamController.close();
    });

    testWidgets(
      'testCompleteV2IntegrationFlow - end-to-end journey across Settings, Live SSE stream, Approvals, Subagent Drawer, Loops run, and Theme Mode (US-ALL.AC-1)',
      (tester) async {
        tester.view.physicalSize = const Size(400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockAdapter = _E2EMockHttpAdapterV2(
          sessions: mockSessions,
          history: mockHistory,
          loops: mockLoops,
        );

        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
        dio.httpClientAdapter = mockAdapter;
        final apiClient = CompozyApiClient(dio: dio);

        final settingsRepo = _InMemorySettingsRepo(
          const Settings(
            baseUrl: 'http://localhost:2123',
            apiToken: 'initial-v2-token',
            activeWorkspaceId: 'ws-initial',
            themeMode: ThemeMode.dark,
            hasConfirmedConnection: true,
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(settingsRepo),
              settingsProvider.overrideWith((ref) => SettingsNotifier(settingsRepo)),
              healthCheckerProvider.overrideWithValue(_FakeHealthChecker(healthy: true)),
              compozyApiClientProvider.overrideWithValue(apiClient),
              sessionStreamProvider('sess-v2-1').overrideWith((ref) => streamController.stream),
              subagentsProvider('sess-v2-1').overrideWithValue(mockSubagents),
            ],
            child: const MyApp(),
          ),
        );

        await tester.pumpAndSettle();

        // ---------------------------------------------------------------------
        // STEP 1: Initial App Shell & Connectivity verification
        // ---------------------------------------------------------------------
        expect(find.text('compozy-app'), findsOneWidget);
        expect(find.byKey(const Key('connection_pill_online')), findsOneWidget);
        expect(find.text('online'), findsOneWidget);

        // ---------------------------------------------------------------------
        // STEP 2: Settings Configuration & Persistence (US-005.AC-3, US-005.AC-4, US-010.AC-1)
        // ---------------------------------------------------------------------
        // Navigate to Settings via workspace menu
        await tester.tap(find.byKey(const Key('app_workspace_menu_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('workspace_menu_settings_button')));
        await tester.pumpAndSettle();

        expect(find.text('Daemon Settings'), findsOneWidget);
        expect(find.byKey(const Key('settings_base_url_field')), findsOneWidget);
        expect(find.byKey(const Key('settings_api_token_field')), findsOneWidget);
        expect(find.byKey(const Key('settings_workspace_field')), findsOneWidget);

        // Test connection button with active daemon URL
        await tester.ensureVisible(find.byKey(const Key('settings_test_connection_button')));
        await tester.tap(find.byKey(const Key('settings_test_connection_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('connection_test_success_banner')), findsOneWidget);
        expect(find.text('Daemon is reachable (HTTP 200 OK)'), findsOneWidget);

        // Switch to Light Theme via segmented toggle
        await tester.ensureVisible(find.byKey(const Key('theme_option_light')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('theme_option_light')));
        await tester.pumpAndSettle();

        // Verify brightness switched to Light
        final settingsContext = tester.element(find.byType(SettingsScreen));
        expect(Theme.of(settingsContext).brightness, Brightness.light);

        // Modify settings fields
        await tester.ensureVisible(find.byKey(const Key('settings_base_url_field')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('settings_base_url_field')),
          'http://10.0.2.2:2123',
        );
        await tester.enterText(
          find.byKey(const Key('settings_api_token_field')),
          'test-secret-v2-token',
        );
        await tester.enterText(
          find.byKey(const Key('settings_workspace_field')),
          'ws-compozy-v2',
        );
        await tester.pump();

        // Save settings
        final saveButtonFinder = find.byKey(const Key('settings_save_button'));
        await tester.ensureVisible(saveButtonFinder);
        await tester.pumpAndSettle();
        await tester.tap(saveButtonFinder);
        await tester.pumpAndSettle();

        // Verify persisted in repository
        expect(settingsRepo.cachedSettings?.baseUrl, 'http://10.0.2.2:2123');
        expect(settingsRepo.cachedSettings?.apiToken, 'test-secret-v2-token');
        expect(settingsRepo.cachedSettings?.activeWorkspaceId, 'ws-compozy-v2');
        expect(settingsRepo.cachedSettings?.themeMode, ThemeMode.light);

        // ---------------------------------------------------------------------
        // STEP 3: Sessions List & Details (US-001, US-002)
        // ---------------------------------------------------------------------
        // Pop Settings screen back to shell
        await tester.tap(find.byKey(const Key('settings_back_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Sessions'));
        await tester.pumpAndSettle();

        expect(find.text('Loop Goal Fixer'), findsOneWidget);
        expect(find.text('fixer'), findsOneWidget);
        expect(find.text('active'), findsOneWidget);

        // ---------------------------------------------------------------------
        // STEP 4: Open Session Chat Screen & Verify Transcript (US-003)
        // ---------------------------------------------------------------------
        await tester.tap(find.text('Loop Goal Fixer'));
        await tester.pumpAndSettle();

        expect(find.text('Loop Goal Fixer'), findsOneWidget);
        expect(find.text('Initialize Task 08 integration flow verification'), findsOneWidget);
        expect(find.text('Ready to verify complete v2 suite.'), findsOneWidget);

        // ---------------------------------------------------------------------
        // STEP 5: Live SSE Assistant Text Streaming (US-006.AC-1, US-006.AC-3)
        // ---------------------------------------------------------------------
        streamController.add(
          const SessionTextDeltaEvent(
            sessionId: 'sess-v2-1',
            turnId: 'turn-stream-v2',
            textDelta: 'Streaming live real-time assistant response token...',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          find.textContaining('Streaming live real-time assistant response token...'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('streaming_agent_bubble')), findsOneWidget);

        // ---------------------------------------------------------------------
        // STEP 6: Real-time Tool Execution Pill (US-006.AC-4, WT-005)
        // ---------------------------------------------------------------------
        streamController.add(
          const SessionToolExecutionEvent(
            sessionId: 'sess-v2-1',
            turnId: 'turn-stream-v2',
            toolCallId: 'call-search-01',
            toolName: 'compozy__tool_search',
            status: 'running',
            input: {'query': 'agent catalog'},
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('tool: compozy__tool_search'), findsOneWidget);
        expect(find.byType(ToolExecutionPill), findsWidgets);

        // Finalize streaming turn and settle tool execution
        streamController.add(
          const SessionToolExecutionEvent(
            sessionId: 'sess-v2-1',
            turnId: 'turn-stream-v2',
            toolCallId: 'call-search-01',
            toolName: 'compozy__tool_search',
            status: 'completed',
          ),
        );
        streamController.add(
          const SessionTurnEvent(
            sessionId: 'sess-v2-1',
            turnId: 'turn-stream-v2',
            status: 'completed',
            agentMessage: 'Streaming live real-time assistant response token...',
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));

        // ---------------------------------------------------------------------
        // STEP 7: Human-in-the-Loop Decision & Approval Card (US-008.AC-1, US-008.AC-2, WT-007)
        // ---------------------------------------------------------------------
        streamController.add(
          const SessionApprovalRequestEvent(
            sessionId: 'sess-v2-1',
            turnId: 'turn-stream-v2',
            approvalId: 'appr-task-08-exec',
            toolName: 'shell_exec',
            description: 'Permission approval requested to execute autonomous verification.',
            input: {'command': 'mise run check'},
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        // Verify "Needs you" banner rendered
        expect(find.text('Needs you'), findsOneWidget);
        expect(find.text('tool: shell_exec'), findsOneWidget);
        expect(
          find.text('Permission approval requested to execute autonomous verification.'),
          findsOneWidget,
        );
        expect(find.text('Approve'), findsOneWidget);
        expect(find.text('Reject'), findsOneWidget);
        expect(find.byType(ApprovalCard), findsOneWidget);

        // Tap "Approve" button
        await tester.tap(find.byKey(const Key('approval_card_approve_button')));
        await tester.pumpAndSettle();

        // Verify approval was dispatched through API client
        expect(mockAdapter.receivedApprovals.length, equals(1));
        expect(mockAdapter.receivedApprovals.first['session_id'], equals('sess-v2-1'));
        expect(mockAdapter.receivedApprovals.first['approved'], isTrue);

        // Verify success snackbar appears
        expect(find.text('Tool execution approved.'), findsOneWidget);

        // ---------------------------------------------------------------------
        // STEP 8: Subagents Hierarchy Drawer (US-009.AC-1, IT-009)
        // ---------------------------------------------------------------------
        await tester.tap(find.byKey(const Key('chat_subagents_button')));
        await tester.pumpAndSettle();

        expect(find.text('Subagents Hierarchy'), findsOneWidget);
        expect(find.text('Codebase Researcher'), findsOneWidget);
        expect(find.text('Terminal Worker'), findsOneWidget);
        expect(find.text('researcher'), findsOneWidget);
        expect(find.text('terminal'), findsOneWidget);
        expect(find.text('gemini-3.8-flash'), findsOneWidget);
        expect(find.text('gemini-3.8-pro'), findsOneWidget);
        expect(find.text('mcp:host'), findsOneWidget);
        expect(find.text('terminal:pty'), findsOneWidget);
        expect(find.byType(SubagentsDrawer), findsOneWidget);

        // Close subagents drawer
        await tester.tap(find.byKey(const Key('subagents_drawer_close')));
        await tester.pumpAndSettle();

        // ---------------------------------------------------------------------
        // STEP 9: Return to Shell and Navigate to Loops Catalog (US-007.AC-1)
        // ---------------------------------------------------------------------
        await tester.tap(find.byKey(const Key('chat_back_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Loops'));
        await tester.pumpAndSettle();

        expect(find.text('Loops Catalog'), findsOneWidget);
        expect(find.text('implement-tasks'), findsOneWidget);
        expect(find.byKey(const Key('run_loop_button_implement-tasks')), findsOneWidget);

        // ---------------------------------------------------------------------
        // STEP 10: Run Loop Modal Sheet & Parameter Submission (US-007.AC-2, IT-007)
        // ---------------------------------------------------------------------
        await tester.tap(find.byKey(const Key('run_loop_button_implement-tasks')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('run_loop_bottom_sheet')), findsOneWidget);
        expect(find.text('Run implement-tasks'), findsOneWidget);
        expect(find.text('PARAMETERS'), findsOneWidget);
        expect(find.byKey(const Key('run_loop_input_slug')), findsOneWidget);

        // Fill required 'slug' parameter
        await tester.enterText(
          find.byKey(const Key('run_loop_input_slug')),
          'compozy-app-v2',
        );
        await tester.pump();

        // Submit loop run
        await tester.tap(find.byKey(const Key('run_loop_submit_button')));
        await tester.pumpAndSettle();

        // Verify request received by mock daemon
        expect(mockAdapter.receivedLoopRuns.length, equals(1));
        expect(mockAdapter.receivedLoopRuns.first['name'], equals('implement-tasks'));
        expect(
          (mockAdapter.receivedLoopRuns.first['inputs'] as Map)['slug'],
          equals('compozy-app-v2'),
        );

        // Verify result screen rendered
        expect(find.byKey(const Key('run_loop_success_banner')), findsOneWidget);
        expect(find.text('run-loop-8831'), findsOneWidget);
        expect(find.text('queued'), findsOneWidget);

        // Dismiss sheet
        await tester.tap(find.byKey(const Key('run_loop_done_button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('run_loop_bottom_sheet')), findsNothing);

        // ---------------------------------------------------------------------
        // STEP 11: Top App Bar Theme Mode Toggle (US-010.AC-1, WT-008)
        // ---------------------------------------------------------------------
        // Toggle theme back to Dark mode from shell app bar
        await tester.tap(find.byKey(const Key('app_shell_theme_toggle')));
        await tester.pumpAndSettle();

        final shellContext = tester.element(find.byType(AppNavigationShell));
        expect(Theme.of(shellContext).brightness, Brightness.dark);
        expect(settingsRepo.cachedSettings?.themeMode, ThemeMode.dark);

        // Toggle again back to Light mode
        await tester.tap(find.byKey(const Key('app_shell_theme_toggle')));
        await tester.pumpAndSettle();

        final updatedShellContext = tester.element(find.byType(AppNavigationShell));
        expect(Theme.of(updatedShellContext).brightness, Brightness.light);
        expect(settingsRepo.cachedSettings?.themeMode, ThemeMode.light);
      },
    );

    testWidgets(
      'testDesktopLayoutV2IntegrationFlow - verifies NavigationRail, wide screen adaptability, and loops execution on desktop viewport',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final mockAdapter = _E2EMockHttpAdapterV2(
          sessions: mockSessions,
          history: mockHistory,
          loops: mockLoops,
        );

        final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
        dio.httpClientAdapter = mockAdapter;
        final apiClient = CompozyApiClient(dio: dio);

        final settingsRepo = _InMemorySettingsRepo(
          const Settings(themeMode: ThemeMode.dark, hasConfirmedConnection: true),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              settingsRepositoryProvider.overrideWithValue(settingsRepo),
              settingsProvider.overrideWith((ref) => SettingsNotifier(settingsRepo)),
              healthCheckerProvider.overrideWithValue(_FakeHealthChecker(healthy: true)),
              compozyApiClientProvider.overrideWithValue(apiClient),
              sessionStreamProvider('sess-v2-1').overrideWith((ref) => streamController.stream),
              subagentsProvider('sess-v2-1').overrideWithValue(mockSubagents),
            ],
            child: const MyApp(),
          ),
        );

        await tester.pumpAndSettle();

        // Verify NavigationRail on wide desktop viewport
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(find.byType(BottomNavigationBar), findsNothing);

        // Verify Sessions listed
        expect(find.text('Loop Goal Fixer'), findsOneWidget);

        // Navigate to Loops tab via NavigationRail
        await tester.tap(find.byIcon(Icons.all_inclusive));
        await tester.pumpAndSettle();

        expect(find.text('Loops Catalog'), findsOneWidget);
        expect(find.text('implement-tasks'), findsOneWidget);

        // Navigate to Settings via workspace menu
        await tester.tap(find.byKey(const Key('app_workspace_menu_button')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('workspace_menu_settings_button')));
        await tester.pumpAndSettle();

        expect(find.text('Daemon Settings'), findsOneWidget);
        expect(find.byKey(const Key('settings_base_url_field')), findsOneWidget);

        // Pop Settings screen back to shell
        await tester.tap(find.byKey(const Key('settings_back_button')));
        await tester.pumpAndSettle();

        // Test theme switch in wide screen
        await tester.tap(find.byKey(const Key('app_shell_theme_toggle')));
        await tester.pumpAndSettle();

        final context = tester.element(find.byType(AppNavigationShell));
        expect(Theme.of(context).brightness, Brightness.light);
      },
    );
  });
}
