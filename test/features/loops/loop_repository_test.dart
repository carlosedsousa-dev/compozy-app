import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:compozy_app/core/network/compozy_api_client.dart';
import 'package:compozy_app/features/loops/data/loop_repository_impl.dart';
import 'package:compozy_app/features/loops/data/models/loop_dto.dart';
import 'package:compozy_app/features/loops/data/sources/loop_remote_data_source.dart';
import 'package:compozy_app/features/loops/domain/loop_definition.dart';
import 'package:compozy_app/features/loops/domain/loop_run_result.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockHttpClientAdapter implements HttpClientAdapter {
  final int statusCode;
  final String responseBody;
  RequestOptions? lastRequestOptions;

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
  group('LoopRepository and RemoteDataSource', () {
    // UT-012 (happy): getLoops — given valid loops JSON payload, parses and returns list of LoopDefinition models.
    test('testGetLoops', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: jsonEncode({
          'entries': [
            {
              'name': 'council',
              'description': 'Three independent seats analyze one question',
              'catalog': {
                'category': 'Engineering',
                'keywords': ['council', 'decision'],
              },
              'inputs': {
                'topic': {'type': 'string', 'required': true},
                'question': {'type': 'string', 'required': true},
              },
              'contract': {
                'goal': 'Synthesize a single verdict',
                'definition_of_done': 'Three seats returned positions',
                'terminal_states': ['done', 'failed'],
                'iteration_cap': 1,
              },
            },
            {
              'name': 'deliver-phases',
              'description': 'Implement all phases in order',
              'category': 'Automation',
              'inputs': {
                'slug': {'type': 'string', 'required': true},
              },
              'contract': {
                'goal': 'Implement phases in order',
                'definition_of_done': 'All phases completed',
              },
            },
          ],
        }),
      );

      final apiClient = CompozyApiClient(dio: dio);
      final remoteDataSource = LoopRemoteDataSourceImpl(apiClient: apiClient);
      final repository = LoopRepositoryImpl(remoteDataSource: remoteDataSource);

      final loops = await repository.getLoops();

      expect(loops, hasLength(2));

      final first = loops[0];
      expect(first.name, equals('council'));
      expect(first.description, equals('Three independent seats analyze one question'));
      expect(first.category, equals('Engineering'));
      expect(first.categoryDisplay, equals('Engineering'));
      expect(first.goal, equals('Synthesize a single verdict'));
      expect(first.definitionOfDone, equals('Three seats returned positions'));
      expect(first.inputs, containsPair('topic', {'type': 'string', 'required': true}));
      expect(first.contract['iteration_cap'], equals(1));

      final second = loops[1];
      expect(second.name, equals('deliver-phases'));
      expect(second.description, equals('Implement all phases in order'));
      expect(second.category, equals('Automation'));
      expect(second.categoryDisplay, equals('Automation'));
      expect(second.goal, equals('Implement phases in order'));
      expect(second.definitionOfDone, equals('All phases completed'));
      expect(second.inputs, containsPair('slug', {'type': 'string', 'required': true}));
    });

    // UT-013 (happy): getLoopDetails — given loop name, returns loop contract and inputs.
    test('testGetLoopDetails', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: jsonEncode({
          'entries': [
            {
              'name': 'implement-tasks',
              'description': 'Implement pending CompozyOS task files',
              'catalog': {
                'category': 'Engineering',
              },
              'inputs': {
                'slug': {'type': 'string', 'required': true},
                'auto_commit': {'type': 'boolean', 'default': false},
              },
              'contract': {
                'goal': 'Implement every authored task under .compozy/tasks',
                'definition_of_done': 'Every loaded task completed implementation and verification',
                'terminal_states': ['done', 'blocked', 'failed'],
              },
            },
          ],
        }),
      );

      final apiClient = CompozyApiClient(dio: dio);
      final remoteDataSource = LoopRemoteDataSourceImpl(apiClient: apiClient);
      final repository = LoopRepositoryImpl(remoteDataSource: remoteDataSource);

      final loopDetails = await repository.getLoopDetails('implement-tasks');

      expect(loopDetails.name, equals('implement-tasks'));
      expect(loopDetails.description, equals('Implement pending CompozyOS task files'));
      expect(loopDetails.category, equals('Engineering'));
      expect(loopDetails.contract, isNotEmpty);
      expect(loopDetails.contract['goal'], equals('Implement every authored task under .compozy/tasks'));
      expect(
        loopDetails.contract['definition_of_done'],
        equals('Every loaded task completed implementation and verification'),
      );
      expect(loopDetails.definitionOfDone, equals('Every loaded task completed implementation and verification'));
      expect(loopDetails.goal, equals('Implement every authored task under .compozy/tasks'));
      expect(loopDetails.inputs, isNotEmpty);
      expect(loopDetails.inputs['slug'], equals({'type': 'string', 'required': true}));
      expect(loopDetails.inputs['auto_commit'], equals({'type': 'boolean', 'default': false}));
    });

    // UT-014 (boundary): getLoops — given empty loops list from daemon, returns empty list without error.
    test('testEmptyLoops', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: jsonEncode({
          'entries': [],
        }),
      );

      final apiClient = CompozyApiClient(dio: dio);
      final remoteDataSource = LoopRemoteDataSourceImpl(apiClient: apiClient);
      final repository = LoopRepositoryImpl(remoteDataSource: remoteDataSource);

      final loops = await repository.getLoops();

      expect(loops, isEmpty);
    });

    test('getLoopDetails throws FormatException when loop is not found', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      dio.httpClientAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: jsonEncode({
          'entries': [
            {'name': 'other-loop', 'description': 'Something else'},
          ],
        }),
      );

      final apiClient = CompozyApiClient(dio: dio);
      final remoteDataSource = LoopRemoteDataSourceImpl(apiClient: apiClient);
      final repository = LoopRepositoryImpl(remoteDataSource: remoteDataSource);

      expect(
        () => repository.getLoopDetails('non-existent'),
        throwsA(isA<FormatException>()),
      );
    });

    test('Riverpod providers resolve correctly from container', () async {
      final container = ProviderContainer();
      final remoteSource = container.read(loopRemoteDataSourceProvider);
      final repo = container.read(loopRepositoryProvider);

      expect(remoteSource, isNotNull);
      expect(repo, isNotNull);
      expect(repo, isA<LoopRepositoryImpl>());

      container.dispose();
    });

    test('LoopDefinition domain model copyWith, equality and toString', () {
      const loop1 = LoopDefinition(
        name: 'loop-a',
        description: 'First loop',
        category: 'Test',
        contract: {'goal': 'Goal A'},
        inputs: {'param': 'val'},
      );

      final loop2 = loop1.copyWith(description: 'Updated description');
      expect(loop2.description, equals('Updated description'));
      expect(loop2.name, equals('loop-a'));
      expect(loop1 == loop1, isTrue);
      expect(loop1 == loop2, isFalse);
      expect(loop1.hashCode, isNotNull);
      expect(loop1.toString(), contains('loop-a'));
      expect(loop1.categoryDisplay, equals('Test'));

      const loopNoCategory = LoopDefinition(
        name: 'loop-b',
        description: 'No category loop',
      );
      expect(loopNoCategory.category, isNull);
      expect(loopNoCategory.categoryDisplay, equals('General'));
      expect(loopNoCategory.goal, isEmpty);
      expect(loopNoCategory.definitionOfDone, isEmpty);
    });

    test('LoopDto handles fromJson, toJson and safe defaults', () {
      final dto = LoopDto.fromJson({
        'name': 'custom-loop',
        'description': 'Custom description',
        'catalog': {'category': 'Custom Cat'},
        'contract': {'definitionOfDone': 'Done criterion'},
        'inputs': {'key': 'val'},
      });

      expect(dto.name, equals('custom-loop'));
      expect(dto.description, equals('Custom description'));
      expect(dto.category, equals('Custom Cat'));
      expect(dto.contract, containsPair('definitionOfDone', 'Done criterion'));
      expect(dto.inputs, containsPair('key', 'val'));

      final json = dto.toJson();
      expect(json['name'], equals('custom-loop'));
      expect(json['category'], equals('Custom Cat'));

      final domain = dto.toDomain();
      expect(domain.name, equals('custom-loop'));
      expect(domain.definitionOfDone, equals('Done criterion'));

      // Malformed / minimal DTO
      final minimalDto = LoopDto.fromJson({});
      expect(minimalDto.name, equals('Unnamed Loop'));
      expect(minimalDto.description, isEmpty);
      expect(minimalDto.category, isNull);
      expect(minimalDto.contract, isEmpty);
      expect(minimalDto.inputs, isEmpty);
    });

    test('runLoop dispatches POST /api/loops/run and returns LoopRunResult', () async {
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'));
      final mockAdapter = _MockHttpClientAdapter(
        statusCode: 200,
        responseBody: jsonEncode({
          'run': {
            'id': 'run-xyz-777',
            'status': 'queued',
            'loop_name': 'implement-tasks',
          },
        }),
      );
      dio.httpClientAdapter = mockAdapter;

      final apiClient = CompozyApiClient(dio: dio);
      final remoteDataSource = LoopRemoteDataSourceImpl(apiClient: apiClient);
      final repository = LoopRepositoryImpl(remoteDataSource: remoteDataSource);

      final result = await repository.runLoop(
        'implement-tasks',
        inputs: {'slug': 'compozy-app-v2', 'auto_commit': true},
      );

      expect(result.runId, equals('run-xyz-777'));
      expect(result.status, equals('queued'));
      expect(result.loopName, equals('implement-tasks'));
      expect(mockAdapter.lastRequestOptions?.path, equals('/api/loops/run'));
      expect(mockAdapter.lastRequestOptions?.method, equals('POST'));
    });

    test('LoopRunResult handles direct run_id, json serialization, and equality', () {
      final res1 = LoopRunResult.fromJson({
        'run_id': 'run-101',
        'status': 'running',
        'loop_name': 'council',
      });

      expect(res1.runId, equals('run-101'));
      expect(res1.status, equals('running'));
      expect(res1.loopName, equals('council'));

      final json = res1.toJson();
      expect(json['run_id'], equals('run-101'));
      expect(json['status'], equals('running'));

      final res2 = LoopRunResult(runId: 'run-101', status: 'running', loopName: 'council');
      expect(res1, equals(res2));
      expect(res1.hashCode, equals(res2.hashCode));
      expect(res1.toString(), contains('run-101'));
    });
  });
}
