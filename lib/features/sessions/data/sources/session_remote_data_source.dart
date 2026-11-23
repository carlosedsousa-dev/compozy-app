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
      return rawList
          .whereType<Map>()
          .map((item) => SessionDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return const [];
  }

  @override
  Future<SessionDto> getSession(String sessionId) async {
    final response = await apiClient.get('/api/sessions/$sessionId');

    final rawSession = response['session'] ?? response;
    if (rawSession is Map) {
      return SessionDto.fromJson(Map<String, dynamic>.from(rawSession));
    }

    throw FormatException('Unexpected response format for session $sessionId');
  }

  @override
  Future<List<TurnDto>> getSessionHistory(String sessionId, {int? limit}) async {
    Map<String, dynamic>? queryParams;
    if (limit != null) {
      queryParams = {'limit': limit.toString()};
    }

    final response = await apiClient.get(
      '/api/sessions/$sessionId/history',
      queryParameters: queryParams,
    );

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

    await apiClient.post(
      '/api/sessions/$sessionId/prompt',
      data: {'prompt': message},
    );
  }
}
