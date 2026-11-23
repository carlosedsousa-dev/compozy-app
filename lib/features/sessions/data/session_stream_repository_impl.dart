import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/sse_client.dart';
import '../domain/models/session_stream_event.dart';
import '../domain/repositories/session_stream_repository.dart';
import 'sources/session_remote_data_source.dart';

/// Riverpod provider for [SessionStreamRepository].
final sessionStreamRepositoryProvider = Provider<SessionStreamRepository>((ref) {
  final sseClient = ref.watch(sseClientProvider);
  final remoteDataSource = ref.watch(sessionRemoteDataSourceProvider);
  return SessionStreamRepositoryImpl(
    sseClient: sseClient,
    remoteDataSource: remoteDataSource,
  );
});

/// Riverpod stream provider for live session streaming by [sessionId].
final sessionStreamProvider =
    StreamProvider.autoDispose.family<SessionStreamEvent, String>((ref, sessionId) {
  final repository = ref.watch(sessionStreamRepositoryProvider);
  return repository.getSessionStream(sessionId);
});

/// Implementation of [SessionStreamRepository] backed by [SseClient].
class SessionStreamRepositoryImpl implements SessionStreamRepository {
  final SseClient sseClient;
  final SessionRemoteDataSource? remoteDataSource;
  final String? Function(String sessionId)? workspaceResolver;

  SessionStreamRepositoryImpl({
    required this.sseClient,
    this.remoteDataSource,
    this.workspaceResolver,
  });

  @override
  Stream<SessionStreamEvent> watchSessionStream(String sessionId) {
    String? wsId = workspaceResolver?.call(sessionId);

    final path = (wsId != null && wsId.isNotEmpty)
        ? '/api/workspaces/$wsId/sessions/$sessionId/stream'
        : '/api/sessions/$sessionId/stream';

    return sseClient.subscribe(path).map((sseEvent) {
      return SessionStreamEvent.fromSseEvent(
        sseEvent,
        defaultSessionId: sessionId,
      );
    });
  }

  @override
  Stream<SessionStreamEvent> getSessionStream(String sessionId) =>
      watchSessionStream(sessionId);

  @override
  Stream<SessionStreamEvent> watchGlobalEvents() {
    return sseClient.subscribe('/events').map((sseEvent) {
      return SessionStreamEvent.fromSseEvent(sseEvent);
    });
  }
}
