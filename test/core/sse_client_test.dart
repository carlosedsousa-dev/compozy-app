import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:compozy_app/core/network/sse_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _StreamingHttpClientAdapter implements HttpClientAdapter {
  final Stream<Uint8List> stream;
  final int statusCode;
  final Map<String, List<String>> headers;
  RequestOptions? lastRequestOptions;

  _StreamingHttpClientAdapter({
    required this.stream,
    this.statusCode = 200,
    Map<String, List<String>>? headers,
  }) : headers = headers ??
            {
              Headers.contentTypeHeader: ['text/event-stream'],
            };

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequestOptions = options;
    return ResponseBody(
      stream,
      statusCode,
      headers: headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SseClient (UT-017)', () {
    test('testSseClientChunkParsing - parses SSE chunks, tool executions, and event boundaries', () async {
      // 1. Basic event chunk parsing
      final basicChunks = [
        'event: message\ndata: {"text": "Hello CompozyOS"}\n\n',
      ];
      final basicEvents = await SseClient.parseChunks(basicChunks);
      expect(basicEvents.length, equals(1));
      expect(basicEvents.first.event, equals('message'));
      expect(basicEvents.first.data, equals('{"text": "Hello CompozyOS"}'));
      expect(basicEvents.first.jsonMap?['text'], equals('Hello CompozyOS'));

      // 2. Fragmented chunk boundaries across network packets
      final fragmentedChunks = [
        'eve',
        'nt: text_delta\n',
        'da',
        'ta: {"delta": "Streaming ',
        'words..."}\n\n',
      ];
      final fragmentedEvents = await SseClient.parseChunks(fragmentedChunks);
      expect(fragmentedEvents.length, equals(1));
      expect(fragmentedEvents.first.event, equals('text_delta'));
      expect(fragmentedEvents.first.jsonMap?['delta'], equals('Streaming words...'));

      // 3. Tool execution event parsing (US-006.AC-4, UT-017)
      final toolChunks = [
        'event: tool_call\n'
            'id: evt_tool_001\n'
            'data: {"tool_name": "bash", "status": "in_progress", "tool_call_id": "call_123", "input": {"command": "git status"}}\n\n',
        'event: tool_execution\n'
            'id: evt_tool_002\n'
            'data: {"tool": "bash", "status": "completed", "tool_call_id": "call_123", "output": "clean"}\n\n',
      ];
      final toolEvents = await SseClient.parseChunks(toolChunks);
      expect(toolEvents.length, equals(2));
      expect(toolEvents[0].event, equals('tool_call'));
      expect(toolEvents[0].id, equals('evt_tool_001'));
      expect(toolEvents[0].jsonMap?['tool_name'], equals('bash'));
      expect(toolEvents[0].jsonMap?['status'], equals('in_progress'));

      expect(toolEvents[1].event, equals('tool_execution'));
      expect(toolEvents[1].id, equals('evt_tool_002'));
      expect(toolEvents[1].jsonMap?['status'], equals('completed'));

      // 4. Multiple events within a single chunk separated by empty line boundaries
      final multiEventChunk = [
        'event: delta_1\ndata: first\n\nevent: delta_2\ndata: second\n\nevent: delta_3\ndata: third\n\n',
      ];
      final multiEvents = await SseClient.parseChunks(multiEventChunk);
      expect(multiEvents.length, equals(3));
      expect(multiEvents[0].event, equals('delta_1'));
      expect(multiEvents[0].data, equals('first'));
      expect(multiEvents[1].event, equals('delta_2'));
      expect(multiEvents[1].data, equals('second'));
      expect(multiEvents[2].event, equals('delta_3'));
      expect(multiEvents[2].data, equals('third'));

      // 5. Comments, ping/keep-alives, and colon without value
      final commentChunks = [
        ': ping - keepalive heartbeat\n'
            ': another comment\n'
            'event: ready\n'
            'data: {"ready": true}\n\n',
      ];
      final commentEvents = await SseClient.parseChunks(commentChunks);
      expect(commentEvents.length, equals(1));
      expect(commentEvents.first.event, equals('ready'));
      expect(commentEvents.first.jsonMap?['ready'], isTrue);

      // 6. Multiline data lines joined with newlines
      final multilineChunks = [
        'event: multiline\n'
            'data: line 1\n'
            'data: line 2\n'
            'data: line 3\n\n',
      ];
      final multilineEvents = await SseClient.parseChunks(multilineChunks);
      expect(multilineEvents.length, equals(1));
      expect(multilineEvents.first.data, equals('line 1\nline 2\nline 3'));

      // 7. Windows \r\n line endings and event boundary
      final crlfChunks = [
        'event: crlf_test\r\ndata: ok\r\n\r\n',
      ];
      final crlfEvents = await SseClient.parseChunks(crlfChunks);
      expect(crlfEvents.length, equals(1));
      expect(crlfEvents.first.event, equals('crlf_test'));
      expect(crlfEvents.first.data, equals('ok'));

      // 8. Reconnection retry field parsing
      final retryChunks = [
        'retry: 3500\nevent: backoff\ndata: retry-configured\n\n',
      ];
      final retryEvents = await SseClient.parseChunks(retryChunks);
      expect(retryEvents.length, equals(1));
      expect(retryEvents.first.retry, equals(3500));
    });

    test('reconnects with backoff on transient network drops (US-006.AC-2)', () async {
      int connectionAttempts = 0;
      final requestedHeadersList = <Map<String, String>>[];

      // Stream provider simulating transient network drop on attempt 1, recovery on attempt 2
      final client = SseClient(
        baseUrl: 'http://localhost:2123',
        streamProvider: (url, headers) async {
          connectionAttempts++;
          requestedHeadersList.add(Map<String, String>.from(headers));

          if (connectionAttempts == 1) {
            // Emits 1 event then encounters transient network drop error
            final controller = StreamController<String>();
            scheduleMicrotask(() {
              controller.add('id: evt_initial_001\nevent: text_delta\ndata: {"chunk": "A"}\n\n');
              // Transient drop
              controller.addError(DioException(
                requestOptions: RequestOptions(path: url),
                error: 'Network connection reset by peer',
                type: DioExceptionType.connectionError,
              ));
            });
            return controller.stream;
          } else {
            // Reconnected successfully: emits second event
            final controller = StreamController<String>();
            scheduleMicrotask(() {
              controller.add('id: evt_initial_002\nevent: text_delta\ndata: {"chunk": "B"}\n\n');
              controller.close();
            });
            return controller.stream;
          }
        },
      );

      final receivedEvents = <SseEvent>[];
      final completer = Completer<void>();

      final subscription = client.subscribe(
        '/api/sessions/sess_123/stream',
        autoReconnect: true,
        initialRetryDelay: const Duration(milliseconds: 10),
        maxRetryDelay: const Duration(milliseconds: 50),
      ).listen((event) {
        receivedEvents.add(event);
        if (receivedEvents.length == 2) {
          completer.complete();
        }
      });

      await completer.future.timeout(const Duration(seconds: 3));
      await subscription.cancel();

      // Verifications:
      expect(connectionAttempts, equals(2));
      expect(receivedEvents.length, equals(2));
      expect(receivedEvents[0].id, equals('evt_initial_001'));
      expect(receivedEvents[0].jsonMap?['chunk'], equals('A'));
      expect(receivedEvents[1].id, equals('evt_initial_002'));
      expect(receivedEvents[1].jsonMap?['chunk'], equals('B'));

      // Check that Last-Event-ID was sent on the reconnected attempt
      expect(requestedHeadersList.length, equals(2));
      expect(requestedHeadersList[0].containsKey('Last-Event-ID'), isFalse);
      expect(requestedHeadersList[1]['Last-Event-ID'], equals('evt_initial_001'));
    });

    test('streams via Dio with ResponseBody streaming adapter', () async {
      final controller = StreamController<Uint8List>();
      final adapter = _StreamingHttpClientAdapter(stream: controller.stream, statusCode: 200);
      final dio = Dio(BaseOptions(baseUrl: 'http://localhost:2123'))..httpClientAdapter = adapter;

      final client = SseClient(dio: dio, appToken: 'test_token_123');

      final received = <SseEvent>[];
      final completer = Completer<void>();

      final subscription = client.subscribe(
        '/api/sessions/sess_abc/stream',
        autoReconnect: false,
      ).listen((event) {
        received.add(event);
        if (received.length == 2) {
          completer.complete();
        }
      });

      controller.add(utf8.encode('event: token\ndata: {"text": "hello"}\n\n'));
      controller.add(utf8.encode('event: token\ndata: {"text": "world"}\n\n'));

      await completer.future.timeout(const Duration(seconds: 3));
      await subscription.cancel();
      await controller.close();

      expect(received.length, equals(2));
      expect(received[0].jsonMap?['text'], equals('hello'));
      expect(received[1].jsonMap?['text'], equals('world'));
      expect(adapter.lastRequestOptions?.headers['Authorization'], equals('Bearer test_token_123'));
      expect(adapter.lastRequestOptions?.headers['Accept'], equals('text/event-stream'));
    });
  });
}
