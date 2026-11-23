import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/compozy_api_client.dart';
import '../../domain/loop_run_result.dart';
import '../models/loop_dto.dart';

/// Riverpod provider for [LoopRemoteDataSource].
final loopRemoteDataSourceProvider = Provider<LoopRemoteDataSource>((ref) {
  final apiClient = ref.watch(compozyApiClientProvider);
  return LoopRemoteDataSourceImpl(apiClient: apiClient);
});

/// Remote data source contract for communicating with daemon loops endpoint.
abstract class LoopRemoteDataSource {
  Future<List<LoopDto>> getLoops();
  Future<LoopDto> getLoopDetails(String name);
  Future<LoopRunResult> runLoop(
    String name, {
    Map<String, dynamic> inputs = const {},
  });
}

/// Implementation of [LoopRemoteDataSource] using [CompozyApiClient].
class LoopRemoteDataSourceImpl implements LoopRemoteDataSource {
  final CompozyApiClient apiClient;

  LoopRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<List<LoopDto>> getLoops() async {
    final queryParams = <String, dynamic>{
      'all_workspaces': 'true',
    };

    final response = await apiClient.get(
      '/api/loops',
      queryParameters: queryParams,
    );

    final rawList = response['entries'] ??
        response['loops'] ??
        response['data'] ??
        response['items'];

    if (rawList is List) {
      return rawList
          .whereType<Map>()
          .map((item) => LoopDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    return const [];
  }

  @override
  Future<LoopDto> getLoopDetails(String name) async {
    try {
      final response = await apiClient.get('/api/loops/$name');
      final rawLoop = response['loop'] ?? response;
      if (rawLoop is Map && rawLoop.containsKey('name')) {
        return LoopDto.fromJson(Map<String, dynamic>.from(rawLoop));
      }
      final rawList = response['entries'] ??
          response['loops'] ??
          response['data'] ??
          response['items'];
      if (rawList is List) {
        for (final item in rawList) {
          if (item is Map && item['name'] == name) {
            return LoopDto.fromJson(Map<String, dynamic>.from(item));
          }
        }
      }
    } catch (_) {
      // Endpoint /api/loops/$name might return 404 on daemons where only /api/loops is supported
    }

    final loops = await getLoops();
    for (final loop in loops) {
      if (loop.name == name) {
        return loop;
      }
    }

    throw FormatException('Loop not found: $name');
  }

  @override
  Future<LoopRunResult> runLoop(
    String name, {
    Map<String, dynamic> inputs = const {},
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'loop_name': name,
      if (inputs.isNotEmpty) 'inputs': inputs,
    };

    final response = await apiClient.post(
      '/api/loops/run',
      data: payload,
    );

    return LoopRunResult.fromJson(response);
  }
}
