import '../models/session_stream_event.dart';

/// Domain repository contract for real-time Server-Sent Events (SSE) streaming for CompozyOS sessions.
abstract class SessionStreamRepository {
  /// Watches the real-time event stream for [sessionId], returning a typed [Stream] of [SessionStreamEvent].
  Stream<SessionStreamEvent> watchSessionStream(String sessionId);

  /// Convenience alias for [watchSessionStream] conforming to get* naming convention.
  Stream<SessionStreamEvent> getSessionStream(String sessionId);

  /// Watches daemon global events across sessions.
  Stream<SessionStreamEvent> watchGlobalEvents();
}
