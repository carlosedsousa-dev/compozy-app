import '../loop_definition.dart';

/// Domain interface for retrieving CompozyOS Loop definitions and details.
abstract class LoopRepository {
  /// Fetches all registered loops in the current daemon workspace.
  Future<List<LoopDefinition>> getLoops();

  /// Fetches details (including contract and inputs) for a specific loop by [name].
  Future<LoopDefinition> getLoopDetails(String name);
}
