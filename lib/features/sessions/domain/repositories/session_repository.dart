import '../models/session.dart';
import '../models/turn.dart';

/// Domain interface for managing CompozyOS sessions and transcripts.
abstract class SessionRepository {
  /// Fetches a list of sessions from CompozyOS daemon, optionally filtered by [state] and [limit].
  Future<List<Session>> getSessions({String? state, int? limit});

  /// Fetches a single session by its [sessionId].
  Future<Session> getSession(String sessionId);

  /// Fetches the conversation turn history for a given [sessionId], optionally constrained by [limit].
  Future<List<Turn>> getSessionHistory(String sessionId, {int? limit});

  /// Dispatches a prompt message to the session identified by [sessionId].
  /// Throws [ArgumentError] if [message] is empty or whitespace-only.
  /// Throws [SessionBusyException] if daemon responds with 409 session busy.
  Future<void> sendPrompt(String sessionId, String message);
}
