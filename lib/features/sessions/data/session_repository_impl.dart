import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/session.dart';
import '../domain/models/turn.dart';
import '../domain/repositories/session_repository.dart';
import 'sources/session_remote_data_source.dart';

/// Riverpod provider for [SessionRepository].
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final remoteDataSource = ref.watch(sessionRemoteDataSourceProvider);
  return SessionRepositoryImpl(remoteDataSource: remoteDataSource);
});

/// Implementation of [SessionRepository] coordinating with [SessionRemoteDataSource].
class SessionRepositoryImpl implements SessionRepository {
  final SessionRemoteDataSource remoteDataSource;

  SessionRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<Session>> getSessions({String? state, int? limit}) async {
    final dtos = await remoteDataSource.getSessions(state: state, limit: limit);
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  @override
  Future<Session> getSession(String sessionId) async {
    final dto = await remoteDataSource.getSession(sessionId);
    return dto.toDomain();
  }

  @override
  Future<List<Turn>> getSessionHistory(String sessionId, {int? limit}) async {
    final dtos =
        await remoteDataSource.getSessionHistory(sessionId, limit: limit);
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  @override
  Future<void> sendPrompt(String sessionId, String message) async {
    if (message.trim().isEmpty) {
      throw ArgumentError('Prompt message cannot be empty or whitespace only');
    }
    return remoteDataSource.sendPrompt(sessionId, message);
  }
}
