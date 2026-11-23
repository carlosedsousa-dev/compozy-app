import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/session.dart';
import '../domain/models/turn.dart';
import '../domain/repositories/session_repository.dart';
import 'sources/session_remote_data_source.dart';

export '../domain/models/session_stream_event.dart';
export '../domain/repositories/session_stream_repository.dart';
export 'session_stream_repository_impl.dart';

/// Riverpod provider for [SessionRepository].
final sessionRepositoryProvider = Provider<SessionRepository>((ref) {
  final remoteDataSource = ref.watch(sessionRemoteDataSourceProvider);
  return SessionRepositoryImpl(remoteDataSource: remoteDataSource);
});

/// Riverpod provider to fetch all sessions.
final sessionsProvider = FutureProvider<List<Session>>((ref) async {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.getSessions();
});

/// Riverpod provider to fetch turn history for a specific session.
final sessionHistoryProvider =
    FutureProvider.family<List<Turn>, String>((ref, sessionId) async {
  final repository = ref.watch(sessionRepositoryProvider);
  return repository.getSessionHistory(sessionId);
});

/// Riverpod provider for the currently selected session filter.
final sessionFilterProvider = StateProvider<String>((ref) => 'All');

/// Riverpod provider for filtered sessions.
final filteredSessionsProvider = Provider<AsyncValue<List<Session>>>((ref) {
  final sessionsAsync = ref.watch(sessionsProvider);
  final filter = ref.watch(sessionFilterProvider);

  return sessionsAsync.whenData((sessions) {
    if (filter == 'All') return sessions;
    return sessions
        .where((s) => s.state.toLowerCase() == filter.toLowerCase())
        .toList();
  });
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

  @override
  Future<void> respondToApproval(
    String sessionId, {
    required bool approved,
    String? approvalId,
  }) async {
    return remoteDataSource.respondToApproval(
      sessionId,
      approved: approved,
      approvalId: approvalId,
    );
  }
}
