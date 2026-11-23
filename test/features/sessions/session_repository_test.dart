import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:compozy_app/core/network/api_exceptions.dart';
import 'package:compozy_app/core/network/compozy_api_client.dart';
import 'package:compozy_app/features/sessions/data/session_repository_impl.dart';
import 'package:compozy_app/features/sessions/data/sources/session_remote_data_source.dart';
import 'package:compozy_app/features/sessions/domain/models/session.dart';
import 'package:compozy_app/features/sessions/domain/models/turn.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  final int statusCode;
  final String responseBody;
  RequestOptions? lastRequestOptions;
  dynamic lastRequestBody;

  _MockHttpClientAdapter({
    this.statusCode = 200,
    this.responseBody = '{}',
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    lastRequestBody = options.data;

    dynamic decodeBody(String body) {
      try {
        return body.isNotEmpty ? jsonDecode(body) : null;
      } catch (_) {
        return body;
      }
    }

    if (statusCode >= 400) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: options,
          statusCode: statusCode,
          data: decodeBody(responseBody),
        ),
      );
    }

    return ResponseBody.fromString(
      responseBody,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('SessionRepository and RemoteDataSource', () {
    // UT-005 (happy): getSessions — given valid sessions JSON array from daemon, parses and returns list of Session models.
    test('testGetSessions', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: jsonEncode({
          'sessions': [
            {
              'id': 'sess_1',
              'name': 'Main Session',
              'agent_name': 'fixer',
              'state': 'active',
              'created_at': '2026-11-23T00:00:00.000Z',
              'updated_at': '2026-11-23T00:10:00.000Z',
            },
            {
              'id': 'sess_2',
              'name': 'Reviewer Session',
              'agent': 'reviewer',
              'state': 'idle',
              'createdAt': '2026-11-23T00:05:00.000Z',
              'updatedAt': '2026-11-23T00:15:00.000Z',
            },
          ],
        }),
      );

      final apiClient = CompozyApiClient(dio: dio);
      final remoteDataSource = SessionRemoteDataSourceImpl(apiClient: apiClient);
      final repository = SessionRepositoryImpl(remoteDataSource: remoteDataSource);

      final sessions = await repository.getSessions();

      expect(sessions, hasLength(2));

      final first = sessions[0];
      expect(first.id, equals('sess_1'));
      expect(first.name, equals('Main Session'));
      expect(first.agent, equals('fixer'));
      expect(first.state, equals('active'));
      expect(first.createdAt, equals(DateTime.parse('2026-11-23T00:00:00.000Z')));
      expect(first.updatedAt, equals(DateTime.parse('2026-11-23T00:10:00.000Z')));

      final second = sessions[1];
      expect(second.id, equals('sess_2'));
      expect(second.name, equals('Reviewer Session'));
      expect(second.agent, equals('reviewer'));
      expect(second.state, equals('idle'));
      expect(second.createdAt, equals(DateTime.parse('2026-11-23T00:05:00.000Z')));
      expect(second.updatedAt, equals(DateTime.parse('2026-11-23T00:15:00.000Z')));
    });

    // UT-006 (happy): getSession — given session ID, returns single Session entity with matching metadata.
    test('testGetSession', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: jsonEncode({
          'session': {
            'id': 'sess_alpha',
            'name': 'Alpha Worker',
            'agent_name': 'dispatcher',
            'state': 'waiting',
            'created_at': '2026-11-23T01:00:00.000Z',
            'updated_at': '2026-11-23T01:30:00.000Z',
          },
        }),
      );

      final apiClient = CompozyApiClient(dio: dio);
      final repository = SessionRepositoryImpl(
        remoteDataSource: SessionRemoteDataSourceImpl(apiClient: apiClient),
      );

      final session = await repository.getSession('sess_alpha');

      expect(session.id, equals('sess_alpha'));
      expect(session.name, equals('Alpha Worker'));
      expect(session.agent, equals('dispatcher'));
      expect(session.state, equals('waiting'));
      expect(session.createdAt, equals(DateTime.parse('2026-11-23T01:00:00.000Z')));
      expect(session.updatedAt, equals(DateTime.parse('2026-11-23T01:30:00.000Z')));
    });

    // UT-007 (boundary): getSessions — given array containing an item missing optional fields, parses valid fields and uses safe defaults.
    test('testMalformedSession', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: jsonEncode({
          'sessions': [
            {
              'id': 'sess_minimal',
              // name, agent, state, created_at, updated_at are intentionally omitted
            },
          ],
        }),
      );

      final apiClient = CompozyApiClient(dio: dio);
      final repository = SessionRepositoryImpl(
        remoteDataSource: SessionRemoteDataSourceImpl(apiClient: apiClient),
      );

      final sessions = await repository.getSessions();

      expect(sessions, hasLength(1));
      final s = sessions.first;
      expect(s.id, equals('sess_minimal'));
      expect(s.name, equals('Untitled Session'));
      expect(s.agent, equals('general'));
      expect(s.state, equals('idle'));
      expect(s.createdAt, equals(DateTime.fromMillisecondsSinceEpoch(0)));
      expect(s.updatedAt, equals(DateTime.fromMillisecondsSinceEpoch(0)));
    });

    // UT-008 (happy): getSessionHistory — given session ID, returns ordered list of Turn models.
    test('testGetSessionHistory', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: jsonEncode({
          'history': [
            {
              'turn_id': 'turn_1',
              'user_message': 'Please analyze the code',
              'agent_message': 'I found 2 files.',
              'status': 'completed',
              'tool_calls': ['compozy__tool_search', 'read_file'],
            },
            {
              'turn_id': 'turn_2',
              'user_message': 'Now run the tests',
              'agent_message': 'All tests passed.',
              'status': 'completed',
              'tool_calls': ['run_command'],
            },
          ],
        }),
      );

      final apiClient = CompozyApiClient(dio: dio);
      final repository = SessionRepositoryImpl(
        remoteDataSource: SessionRemoteDataSourceImpl(apiClient: apiClient),
      );

      final history = await repository.getSessionHistory('sess_1');

      expect(history, hasLength(2));

      expect(history[0].turnId, equals('turn_1'));
      expect(history[0].userMessage, equals('Please analyze the code'));
      expect(history[0].agentMessage, equals('I found 2 files.'));
      expect(history[0].status, equals('completed'));
      expect(history[0].toolCalls, equals(['compozy__tool_search', 'read_file']));

      expect(history[1].turnId, equals('turn_2'));
      expect(history[1].userMessage, equals('Now run the tests'));
      expect(history[1].agentMessage, equals('All tests passed.'));
      expect(history[1].status, equals('completed'));
      expect(history[1].toolCalls, equals(['run_command']));
    });

    // UT-009 (happy): sendPrompt — given session ID and message, sends POST /api/sessions/{id}/prompt with payload and completes cleanly.
    test('testSendPrompt', () async {
      final mockAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: jsonEncode({'status': 'queued', 'turn_id': 't_99'}),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = mockAdapter;

      final apiClient = CompozyApiClient(dio: dio);
      final repository = SessionRepositoryImpl(
        remoteDataSource: SessionRemoteDataSourceImpl(apiClient: apiClient),
      );

      await repository.sendPrompt('sess_123', 'Implement feature X');

      expect(mockAdapter.lastRequestOptions?.path, equals('/api/sessions/sess_123/prompt'));
      expect(mockAdapter.lastRequestOptions?.method, equals('POST'));
      expect(mockAdapter.lastRequestBody, equals({'prompt': 'Implement feature X'}));
    });

    // UT-010 (boundary): sendPrompt — given empty or whitespace string, rejects immediately without network dispatch.
    test('testBlankPrompt', () async {
      final mockAdapter = _MockHttpClientAdapter(statusCode: 200);
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = mockAdapter;

      final apiClient = CompozyApiClient(dio: dio);
      final repository = SessionRepositoryImpl(
        remoteDataSource: SessionRemoteDataSourceImpl(apiClient: apiClient),
      );

      // Empty string
      expect(
        () => repository.sendPrompt('sess_1', ''),
        throwsA(isA<ArgumentError>()),
      );

      // Whitespace only
      expect(
        () => repository.sendPrompt('sess_1', '   \t\n  '),
        throwsA(isA<ArgumentError>()),
      );

      // Verify no network call was dispatched
      expect(mockAdapter.lastRequestOptions, isNull);
    });

    // UT-011 (error): sendPrompt — given daemon error 409 (session busy), throws SessionBusyException.
    test('testPromptSessionBusy', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 409,
        responseBody: jsonEncode({
          'code': 'session_busy',
          'error': 'Session is currently running a turn',
        }),
      );

      final apiClient = CompozyApiClient(dio: dio);
      final repository = SessionRepositoryImpl(
        remoteDataSource: SessionRemoteDataSourceImpl(apiClient: apiClient),
      );

      expect(
        () => repository.sendPrompt('sess_1', 'New prompt while busy'),
        throwsA(isA<SessionBusyException>()),
      );
    });

    test('Riverpod providers resolve correctly from container', () {
      final container = ProviderContainer();
      final remoteSource = container.read(sessionRemoteDataSourceProvider);
      final repo = container.read(sessionRepositoryProvider);

      expect(remoteSource, isNotNull);
      expect(repo, isNotNull);
      expect(repo, isA<SessionRepositoryImpl>());

      container.dispose();
    });

    test('Session and Turn domain models copyWith, equality and toString', () {
      final now = DateTime.now();
      final session1 = Session(
        id: 's1',
        name: 'Session 1',
        agent: 'agent1',
        state: 'active',
        createdAt: now,
        updatedAt: now,
      );
      final session2 = session1.copyWith(name: 'Updated Name');
      expect(session2.name, equals('Updated Name'));
      expect(session2.id, equals('s1'));
      expect(session1 == session1, isTrue);
      expect(session1 == session2, isFalse);
      expect(session1.hashCode, isNotNull);
      expect(session1.toString(), contains('Session 1'));

      const turn1 = Turn(
        turnId: 't1',
        userMessage: 'user',
        agentMessage: 'agent',
        status: 'done',
        toolCalls: ['tool1'],
      );
      final turn2 = turn1.copyWith(status: 'in_progress');
      expect(turn2.status, equals('in_progress'));
      expect(turn2.turnId, equals('t1'));
      expect(turn1 == turn1, isTrue);
      expect(turn1 == turn2, isFalse);
      expect(turn1.hashCode, isNotNull);
      expect(turn1.toString(), contains('t1'));
    });
  });
}
