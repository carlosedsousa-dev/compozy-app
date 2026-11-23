import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/loop_definition.dart';
import '../domain/repositories/loop_repository.dart';
import 'sources/loop_remote_data_source.dart';

/// Riverpod provider for [LoopRepository].
final loopRepositoryProvider = Provider<LoopRepository>((ref) {
  final remoteDataSource = ref.watch(loopRemoteDataSourceProvider);
  return LoopRepositoryImpl(remoteDataSource: remoteDataSource);
});

/// Riverpod provider to fetch all loops.
final loopsProvider = FutureProvider<List<LoopDefinition>>((ref) async {
  final repository = ref.watch(loopRepositoryProvider);
  return repository.getLoops();
});

/// Implementation of [LoopRepository] coordinating with [LoopRemoteDataSource].
class LoopRepositoryImpl implements LoopRepository {
  final LoopRemoteDataSource remoteDataSource;

  LoopRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<LoopDefinition>> getLoops() async {
    final dtos = await remoteDataSource.getLoops();
    return dtos.map((dto) => dto.toDomain()).toList();
  }

  @override
  Future<LoopDefinition> getLoopDetails(String name) async {
    final dto = await remoteDataSource.getLoopDetails(name);
    return dto.toDomain();
  }
}
