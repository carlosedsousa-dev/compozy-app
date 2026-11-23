import '../loop_definition.dart';
import '../loop_run_result.dart';

export '../loop_definition.dart';
export '../loop_run_result.dart';

/// Domain interface for retrieving CompozyOS Loop definitions and details.
abstract class LoopRepository {
  /// Fetches all registered loops in the current daemon workspace.
  Future<List<LoopDefinition>> getLoops();

  /// Fetches details (including contract and inputs) for a specific loop by [name].
  Future<LoopDefinition> getLoopDetails(String name);

  /// Dispatches POST /api/loops/run to start a new execution of [name] with optional [inputs].
  Future<LoopRunResult> runLoop(
    String name, {
    Map<String, dynamic> inputs = const {},
  });
}
