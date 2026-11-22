import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'canvas_exception.dart';

class CanvasUser {
  const CanvasUser({required this.id, required this.name});
  final int id;
  final String name;
}

CanvasException mapDioError(DioException e) {
  final code = e.response?.statusCode;
  if (code != null) {
    if (code == 401) {
      return const CanvasException(
        CanvasErrorKind.unauthorized,
        'Canvas rejected this token. Check it was copied fully and has not expired.',
      );
    }
    if (code == 403) {
      final body = '${e.response?.data}'.toLowerCase();
      if (body.contains('rate limit')) {
        return const CanvasException(
          CanvasErrorKind.rateLimited,
          'Canvas is rate limiting requests. Try again in a minute.',
        );
      }
      return const CanvasException(CanvasErrorKind.unauthorized, 'Canvas denied access with this token.');
    }
    if (code == 429) {
      return const CanvasException(
        CanvasErrorKind.rateLimited,
        'Canvas is rate limiting requests. Try again in a minute.',
      );
    }
    if (code == 404) {
      return const CanvasException(
        CanvasErrorKind.invalidUrl,
        'No Canvas API found at that address. Check the URL.',
      );
    }
    if (code >= 500) {
      return CanvasException(CanvasErrorKind.server, 'Canvas had a problem (HTTP $code). Try again later.');
    }
    return CanvasException(CanvasErrorKind.unexpected, 'Unexpected response (HTTP $code).');
  }
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.connectionError:
    case DioExceptionType.badCertificate:
      return const CanvasException(
        CanvasErrorKind.network,
        'Could not reach Canvas. Check the address and your connection.',
      );
    default:
      return const CanvasException(CanvasErrorKind.unexpected, 'Something went wrong talking to Canvas.');
  }
}

/// Page number from the rel="last" Link entry, if it is a plain number.
int? parseLastPage(String? header) {
  if (header == null) return null;
  final m = RegExp(r'<([^>]+)>\s*;\s*rel="last"').firstMatch(header);
  if (m == null) return null;
  return int.tryParse(Uri.tryParse(m.group(1)!)?.queryParameters['page'] ?? '');
}

/// Extracts the rel="next" URL from a Canvas Link header, if any.
String? parseNextLink(String? header) {
  if (header == null) return null;
  final m = RegExp(r'<([^>]+)>\s*;\s*rel="next"').firstMatch(header);
  return m?.group(1);
}

/// True when [uri] is the same origin as [base]: https, same host, same port.
/// The Canvas token is only ever sent to such addresses.
bool isSameOrigin(Uri uri, String base) {
  final b = Uri.tryParse(base);
  if (b == null || uri.scheme != 'https' || b.scheme != 'https') return false;
  return uri.host.toLowerCase() == b.host.toLowerCase() && uri.port == b.port;
}

/// Where a redirect to [location] leads, or null if it is not a safe https
/// address. Relative locations are resolved against [from].
Uri? redirectTarget(Uri from, String? location) {
  if (location == null || location.isEmpty) return null;
  final target = from.resolve(location);
  return target.scheme == 'https' && target.host.isNotEmpty ? target : null;
}

class CanvasClient {
  CanvasClient({required String baseUrl, required String token, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = baseUrl
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 20)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['Accept'] = 'application/json';
  }

  final Dio _dio;

  String get host => Uri.parse(_dio.options.baseUrl).host;

  Future<CanvasUser> fetchSelf() async {
    final Response<dynamic> r;
    try {
      r = await _dio.get<dynamic>('/api/v1/users/self');
    } on DioException catch (e) {
      throw mapDioError(e);
    }
    final data = r.data;
    if (data is! Map || data['id'] is! num) {
      throw const CanvasException(
        CanvasErrorKind.invalidUrl,
        'That address did not answer like Canvas. Check the URL.',
      );
    }
    return CanvasUser(
      id: (data['id'] as num).toInt(),
      name: (data['name'] as String?) ?? 'Canvas user',
    );
  }

  /// GET a list endpoint. When Canvas says how many pages there are, the
  /// rest are fetched in parallel; otherwise Link rel="next" is followed.
  Future<List<Map<String, dynamic>>> getPaged(
    String path, {
    Map<String, dynamic>? query,
    int maxPages = 50,
  }) async {
    final out = <Map<String, dynamic>>[];

    Future<Response<dynamic>> get(String url, Map<String, dynamic>? q) async {
      try {
        return await _dio.get<dynamic>(url, queryParameters: q);
      } on DioException catch (e) {
        throw mapDioError(e);
      }
    }

    void collect(Response<dynamic> r) {
      final data = r.data;
      if (data is! List) {
        throw const CanvasException(CanvasErrorKind.unexpected, 'Canvas returned an unexpected response.');
      }
      for (final item in data) {
        if (item is Map<String, dynamic>) out.add(item);
      }
    }

    final first = await get(path, {'per_page': 100, ...?query});
    collect(first);
    var link = first.headers.value('link');
    var next = parseNextLink(link);
    var pages = 1;

    final lastPage = parseLastPage(link);
    final nextUri = next == null ? null : Uri.tryParse(next);
    if (nextUri != null &&
        isSameOrigin(nextUri, _dio.options.baseUrl) &&
        lastPage != null &&
        lastPage > 2 &&
        lastPage <= maxPages &&
        nextUri.queryParameters['page'] == '2') {
      String urlFor(int page) => nextUri
          .replace(queryParameters: {...nextUri.queryParametersAll, 'page': ['$page']})
          .toString();
      for (var start = 2; start <= lastPage; start += 6) {
        final batch = [for (var p = start; p < start + 6 && p <= lastPage; p++) p];
        final results = await Future.wait([for (final p in batch) get(urlFor(p), null)]);
        results.forEach(collect);
      }
      return out;
    }

    while (next != null && pages++ < maxPages) {
      final u = Uri.tryParse(next);
      if (u == null || !isSameOrigin(u, _dio.options.baseUrl)) break;
      final r = await get(next, null);
      collect(r);
      link = r.headers.value('link');
      next = parseNextLink(link);
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> fetchCoursesJson() =>
      getPaged('/api/v1/courses', query: {'enrollment_state': 'active'});

  /// The student's enrollments, which carry each course's current/final grade.
  Future<List<Map<String, dynamic>>> fetchEnrollmentsJson() => getPaged(
        '/api/v1/users/self/enrollments',
        query: {
          'type[]': ['StudentEnrollment'],
          'state[]': ['active'],
        },
      );

  Future<List<Map<String, dynamic>>> fetchAssignmentGroupsJson(int courseId) =>
      getPaged('/api/v1/courses/$courseId/assignment_groups');

  /// [withStats] adds each assignment's class score statistics (when shown).
  Future<List<Map<String, dynamic>>> fetchAssignmentsJson(int courseId, {bool withStats = false}) => getPaged(
        '/api/v1/courses/$courseId/assignments',
        query: {
          'include[]': ['submission', if (withStats) 'score_statistics'],
          'order_by': 'due_at',
        },
      );

  Future<List<Map<String, dynamic>>> fetchActivityJson() => getPaged(
        '/api/v1/users/self/activity_stream',
        query: {'only_active_courses': true, 'per_page': 100},
        maxPages: 3,
      );

  /// Every graded submission of the user (the activity stream drops older ones).
  Future<List<Map<String, dynamic>>> fetchGradedJson() => getPaged(
        '/api/v1/users/self/graded_submissions',
        query: {
          'include[]': ['assignment'],
          'only_current_enrollments': true,
        },
        maxPages: 3,
      );

  /// Announcements of the last ~6 months for the given courses.
  Future<List<Map<String, dynamic>>> fetchAnnouncementsJson(List<int> courseIds) {
    final now = DateTime.now().toUtc();
    return getPaged(
      '/api/v1/announcements',
      query: {
        'context_codes[]': [for (final id in courseIds) 'course_$id'],
        'start_date': now.subtract(const Duration(days: 180)).toIso8601String(),
        'end_date': now.add(const Duration(days: 1)).toIso8601String(),
        'active_only': true,
      },
      maxPages: 3,
    );
  }

  String get baseUrl => _dio.options.baseUrl;

  Future<List<Map<String, dynamic>>> fetchFoldersJson(int courseId) =>
      getPaged('/api/v1/courses/$courseId/folders');

  Future<List<Map<String, dynamic>>> fetchFilesJson(int courseId) =>
      getPaged('/api/v1/courses/$courseId/files');

  /// Downloads [url] to [savePath]. File links carry their own verifier, so the
  /// first attempt sends no token (it may redirect to other hosts). Only if
  /// Canvas itself refuses do we retry with the token, and only on its own host.
  Future<void> downloadFile(String url, String savePath) async {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') {
      throw const CanvasException(CanvasErrorKind.unexpected, 'This file has no safe download link.');
    }
    final plain = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
    try {
      await plain.download(url, savePath);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if ((code == 401 || code == 403) && isSameOrigin(uri, _dio.options.baseUrl)) {
        try {
          await _downloadWithToken(uri, savePath);
        } on DioException catch (e2) {
          throw mapDioError(e2);
        }
      } else {
        throw mapDioError(e);
      }
    } finally {
      // A one-off client: release its connections instead of leaving them idle.
      plain.close();
    }
  }

  /// The retry with the token. Redirects are followed by hand so the token
  /// never leaves Canvas: a hop to another origin is fetched without it.
  Future<void> _downloadWithToken(Uri start, String savePath) async {
    var current = start;
    for (var hop = 0; hop < 5; hop++) {
      final own = isSameOrigin(current, _dio.options.baseUrl);
      final dio = own ? _dio : Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
      try {
        final r = await dio.downloadUri(
          current,
          savePath,
          options: Options(followRedirects: false, validateStatus: (s) => s != null && s < 400),
        );
        final code = r.statusCode ?? 200;
        if (code < 300) return;
        final next = redirectTarget(current, r.headers.value('location'));
        if (next == null) {
          throw const CanvasException(CanvasErrorKind.unexpected, 'This file has no safe download link.');
        }
        current = next;
      } finally {
        if (!own) dio.close();
      }
    }
    throw const CanvasException(CanvasErrorKind.unexpected, 'Too many redirects while downloading.');
  }

  Future<Map<String, dynamic>> fetchFileJson(int fileId) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/api/v1/files/$fileId');
      return r.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  // ---- submissions -------------------------------------------------------

  Future<Map<String, dynamic>> fetchAssignmentJson(int courseId, int assignmentId) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/api/v1/courses/$courseId/assignments/$assignmentId',
      );
      return r.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// The student's own submission with the teacher's comments (and their files).
  Future<Map<String, dynamic>> fetchMySubmissionJson(int courseId, int assignmentId) async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/api/v1/courses/$courseId/assignments/$assignmentId/submissions/self',
        queryParameters: {
          'include[]': ['submission_comments'],
        },
      );
      return r.data ?? <String, dynamic>{};
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  /// Canvas's 3-step upload. Returns the new file id.
  Future<int> uploadSubmissionFile(
    int courseId,
    int assignmentId,
    String path, {
    void Function(int sent, int total)? onProgress,
  }) async {
    final file = File(path);
    final name = path.split(RegExp(r'[\\/]')).last;
    final size = await file.length();
    try {
      // 1. Ask Canvas where to send the bytes.
      final start = await _dio.post<Map<String, dynamic>>(
        '/api/v1/courses/$courseId/assignments/$assignmentId/submissions/self/files',
        data: 'name=${Uri.encodeQueryComponent(name)}&size=$size',
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final uploadUrl = start.data?['upload_url'];
      final params = start.data?['upload_params'];
      if (uploadUrl is! String || params is! Map || Uri.tryParse(uploadUrl)?.scheme != 'https') {
        throw const CanvasException(
          CanvasErrorKind.unexpected,
          'Canvas did not accept this upload.',
        );
      }

      // 2. Send the file to that address. No token: it is a different server.
      final form = FormData();
      params.forEach((k, v) => form.fields.add(MapEntry('$k', '$v')));
      form.files.add(MapEntry('file', await MultipartFile.fromFile(path, filename: name)));
      final uploader = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(minutes: 5),
          followRedirects: false,
          validateStatus: (s) => s != null && s < 400,
        ),
      );
      final Response<dynamic> up;
      try {
        up = await uploader.post<dynamic>(uploadUrl, data: form, onSendProgress: onProgress);
      } finally {
        uploader.close();
      }

      var id = _fileIdFrom(up.data);
      if (id == null) {
        // 3. Some servers answer with a redirect that must be confirmed.
        final location = up.headers.value('location');
        final target = location == null ? null : Uri.parse(uploadUrl).resolve(location);
        if (target == null || target.host != Uri.parse(_dio.options.baseUrl).host) {
          throw const CanvasException(CanvasErrorKind.unexpected, 'Upload could not be confirmed.');
        }
        Response<dynamic> confirm;
        try {
          confirm = await _dio.getUri<dynamic>(target);
        } on DioException {
          confirm = await _dio.postUri<dynamic>(
            target,
            options: Options(headers: {'Content-Length': '0'}),
          );
        }
        id = _fileIdFrom(confirm.data);
      }
      if (id == null) {
        throw const CanvasException(CanvasErrorKind.unexpected, 'Upload could not be confirmed.');
      }
      return id;
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }

  Future<void> submitUpload(int courseId, int assignmentId, List<int> fileIds) async {
    try {
      await _dio.post<dynamic>(
        '/api/v1/courses/$courseId/assignments/$assignmentId/submissions',
        data: buildSubmissionBody(fileIds),
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
    } on DioException catch (e) {
      throw mapDioError(e);
    }
  }
}

int? _fileIdFrom(dynamic data) {
  var d = data;
  if (d is String && d.isNotEmpty) {
    try {
      d = jsonDecode(d);
    } catch (_) {
      return null;
    }
  }
  if (d is Map && d['id'] is num) return (d['id'] as num).toInt();
  return null;
}

/// Form body for "turn these uploaded files in".
String buildSubmissionBody(List<int> fileIds) {
  final parts = <String>[
    '${Uri.encodeQueryComponent('submission[submission_type]')}=online_upload',
    for (final id in fileIds) '${Uri.encodeQueryComponent('submission[file_ids][]')}=$id',
  ];
  return parts.join('&');
}
