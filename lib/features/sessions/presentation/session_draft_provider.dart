import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory prompt draft persistence across screen navigation within the app session.
final sessionDraftPromptProvider =
    StateProvider.family<String, String>((ref, sessionId) => '');
