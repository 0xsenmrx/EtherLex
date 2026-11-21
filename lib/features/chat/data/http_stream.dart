import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../domain/chat_backend.dart';
import 'sse.dart';

/// The `error.message` of a JSON error body (both Anthropic and OpenAI send
/// `{"error": {"message": ...}}`), or null if there is none.
String? errorTextFromBody(String body) {
  try {
    final j = jsonDecode(body);
    final error = j is Map ? j['error'] : null;
    final message = error is Map ? error['message'] : (error is String ? error : null);
    return message is String && message.trim().isNotEmpty ? message.trim() : null;
  } catch (_) {
    return null;
  }
}

ChatException _mapDio(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionError:
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return kChatOffline;
    case DioExceptionType.unknown:
      if (e.error is SocketException || e.error is HttpException) return kChatOffline;
      return const ChatException(ChatErrorKind.unexpected, 'Something went wrong talking to the AI service.');
    default:
      return const ChatException(ChatErrorKind.unexpected, 'Something went wrong talking to the AI service.');
  }
}

Future<String?> _errorText(Object? data) async {
  if (data is! ResponseBody) return null;
  try {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in data.stream) {
      bytes.add(chunk);
      if (bytes.length > 16384) break;
    }
    return errorTextFromBody(utf8.decode(bytes.takeBytes(), allowMalformed: true));
  } catch (_) {
    return null;
  }
}

/// POSTs [body] as JSON and yields the server-sent events of the answer.
/// Failures arrive as a [ChatException]. Cancelling the subscription cancels
/// the request. [headers] may hold the API key: nothing here logs or repeats it.
Stream<SseEvent> postEvents(
  Dio dio,
  String url, {
  required Map<String, String> headers,
  required Object body,
}) async* {
  final cancel = CancelToken();
  try {
    final Response<ResponseBody> r;
    try {
      r = await dio.post<ResponseBody>(
        url,
        data: body,
        cancelToken: cancel,
        options: Options(
          responseType: ResponseType.stream,
          contentType: Headers.jsonContentType,
          headers: headers,
          receiveTimeout: const Duration(seconds: 90),
          validateStatus: (_) => true,
        ),
      );
    } on DioException catch (e) {
      throw _mapDio(e);
    }
    final status = r.statusCode ?? 0;
    if (status < 200 || status >= 300) throw chatErrorForStatus(status, await _errorText(r.data));
    final stream = r.data?.stream;
    if (stream == null) {
      throw const ChatException(ChatErrorKind.unexpected, 'The AI service sent an empty answer.');
    }
    yield* parseSse(stream);
  } on DioException catch (e) {
    throw _mapDio(e);
  } finally {
    if (!cancel.isCancelled) cancel.cancel();
  }
}
