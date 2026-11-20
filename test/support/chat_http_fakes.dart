import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:etherlex/features/chat/domain/chat_backend.dart';

/// Test doubles for the AI services' HTTP calls.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody sse(String text, {int status = 200}) => ResponseBody(
      Stream.value(Uint8List.fromList(utf8.encode(text))),
      status,
      headers: {
        Headers.contentTypeHeader: ['text/event-stream'],
      },
    );

ResponseBody jsonBody(String text, int status) => ResponseBody.fromString(
      text,
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );

Future<ChatException> failure(Stream<Object?> s) async {
  try {
    await s.drain<void>();
  } on ChatException catch (e) {
    return e;
  }
  throw StateError('expected a ChatException');
}
