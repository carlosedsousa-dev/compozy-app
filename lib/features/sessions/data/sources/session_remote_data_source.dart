import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/compozy_api_client.dart';
import '../models/session_dto.dart';
import '../models/turn_dto.dart';

/// Riverpod provider for [SessionRemoteDataSource].
final sessionRemoteDataSourceProvider = Provider<SessionRemoteDataSource>((ref) {
  final apiClient = ref.watch(compozyApiClientProvider);
  return SessionRemoteDataSourceImpl(apiClient: apiClient);
});

/// Remote data source contract for sessions and transcript communication.
abstract class SessionRemoteDataSource {
  Future<List<SessionDto>> getSessions({String? state, int? limit});
  Future<SessionDto> getSession(String sessionId);
  Future<List<TurnDto>> getSessionHistory(String sessionId, {int? limit});
  Future<void> sendPrompt(String sessionId, String message);
}

/// Implementation of [SessionRemoteDataSource] using [CompozyApiClient].
class SessionRemoteDataSourceImpl implements SessionRemoteDataSource {
  final CompozyApiClient apiClient;
  final Map<String, String> _workspaceBySessionId = {};

  SessionRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<SessionDto>> getSessions({String? state, int? limit}) async {
    final queryParams = <String, dynamic>{
      'all_workspaces': 'true',
    };
    if (state != null) {
      queryParams['state'] = state;
    }
    if (limit != null) {
      queryParams['limit'] = limit.toString();
    }

    final response = await apiClient.get(
      '/api/sessions',
      queryParameters: queryParams,
    );

    final rawList =
        response['sessions'] ?? response['data'] ?? response['items'];
    if (rawList is List) {
      final list = rawList
          .whereType<Map>()
          .map((item) => SessionDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      for (final dto in list) {
        if (dto.workspaceId != null && dto.workspaceId!.isNotEmpty) {
          _workspaceBySessionId[dto.id] = dto.workspaceId!;
        }
      }
      return list;
    }

    return const [];
  }

  @override
  Future<SessionDto> getSession(String sessionId) async {
    final response = await apiClient.get('/api/sessions/$sessionId');

    final rawSession = response['session'] ?? response;
    if (rawSession is Map) {
      final dto = SessionDto.fromJson(Map<String, dynamic>.from(rawSession));
      if (dto.workspaceId != null && dto.workspaceId!.isNotEmpty) {
        _workspaceBySessionId[dto.id] = dto.workspaceId!;
      }
      return dto;
    }

    throw FormatException('Unexpected response format for session $sessionId');
  }

  @override
  Future<List<TurnDto>> getSessionHistory(String sessionId, {int? limit}) async {
    Map<String, dynamic>? queryParams;
    if (limit != null) {
      queryParams = {'limit': limit.toString()};
    }

    String? wsId = _workspaceBySessionId[sessionId];
    if (wsId == null) {
      try {
        final session = await getSession(sessionId);
        wsId = session.workspaceId;
      } catch (_) {}
    }

    final path = (wsId != null && wsId.isNotEmpty)
        ? '/api/workspaces/$wsId/sessions/$sessionId/history'
        : '/api/sessions/$sessionId/history';

    Map<String, dynamic> response;
    try {
      response = await apiClient.get(
        path,
        queryParameters: queryParams,
      );
    } catch (_) {
      if (wsId != null) {
        response = await apiClient.get(
          '/api/sessions/$sessionId/history',
          queryParameters: queryParams,
        );
      } else {
        rethrow;
      }
    }

    final rawList = response['history'] ??
        response['turns'] ??
        response['data'] ??
        response['events'];

    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((item) => TurnDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return const [];
  }

  @override
  Future<void> sendPrompt(String sessionId, String message) async {
    if (message.trim().isEmpty) {
      throw ArgumentError('Prompt message cannot be empty or whitespace only');
    }

    String? wsId = _workspaceBySessionId[sessionId];
    if (wsId != null && wsId.isNotEmpty) {
      final idKey = 'prompt_${DateTime.now().microsecondsSinceEpoch}';
      final payload = {
        'prompt': message,
        'message': message,
        'idempotency_key': idKey,
        'message_id': 'msg_$idKey',
      };
      await apiClient.post(
        '/api/workspaces/$wsId/sessions/$sessionId/prompt',
        data: payload,
      );
    } else {
      await apiClient.post(
        '/api/sessions/$sessionId/prompt',
        data: {'prompt': message},
      );
    }
  }
}
