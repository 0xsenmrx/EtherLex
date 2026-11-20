import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../app/app_info.dart';
import '../../../core/utils/open_path.dart';
import '../domain/update_info.dart';

class UpdateException implements Exception {
  const UpdateException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Talks to the GitHub Releases API of this repository, downloads the
/// installer and starts it. Nothing about the user or their Canvas account
/// is sent.
class UpdateService {
  UpdateService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 30),
              headers: {'User-Agent': '$kAppName/$kAppVersion'},
            ));

  final Dio _dio;

  /// The installer is a Windows program.
  static bool get supported => Platform.isWindows;

  /// The newest published release, or null when there is none.
  Future<UpdateInfo?> fetchLatest() async {
    try {
      final res = await _dio.get<Object>(
        'https://api.github.com/repos/$kUpdateRepo/releases/latest',
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      final info = parseRelease(res.data);
      if (info == null || info.sha256 != null) return info;
      final file = await _dio.getUri<String>(
        info.checksumUrl!,
        options: Options(responseType: ResponseType.plain, headers: {'Accept': 'application/octet-stream'}),
      );
      final hash = parseChecksumFile(file.data ?? '', info.installerName);
      if (hash == null) throw const UpdateException('The release checksum could not be read.');
      return info.withSha256(hash);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw UpdateException(_networkMessage(e));
    } on FormatException catch (e) {
      throw UpdateException(e.message);
    }
  }

  /// Downloads the installer next to the system temp files and checks its
  /// SHA-256 against the release before returning it.
  Future<File> download(UpdateInfo info, {void Function(double progress)? onProgress}) async {
    final expected = info.sha256;
    if (expected == null) throw const UpdateException('The release has no checksum, so it was not installed.');
    final sep = Platform.pathSeparator;
    final dir = Directory('${Directory.systemTemp.path}${sep}EtherLex-update');
    await dir.create(recursive: true);
    final target = File('${dir.path}$sep${sanitizeFileName(info.installerName)}');
    final part = File('${target.path}.part');
    try {
      await _dio.downloadUri(
        info.installerUrl,
        part.path,
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          headers: {'Accept': 'application/octet-stream'},
        ),
        onReceiveProgress: (got, total) {
          if (total > 0) onProgress?.call(got / total);
        },
      );
    } on DioException catch (e) {
      throw UpdateException(_networkMessage(e));
    }
    final actual = (await sha256.bind(part.openRead()).first).toString();
    if (actual != expected) {
      await part.delete();
      throw const UpdateException('The download did not match its checksum, so it was discarded.');
    }
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
    return target;
  }

  /// Starts [installer] and ends this process so it can replace the files.
  /// The setup keeps the install folder and the settings, and starts the new
  /// version when it is done.
  Future<Never> installAndExit(File installer) async {
    await Process.start(
      installer.path,
      const ['/SILENT', '/CLOSEAPPLICATIONS', '/NOCANCEL'],
      mode: ProcessStartMode.detached,
    );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    exit(0);
  }

  static String _networkMessage(DioException e) {
    final code = e.response?.statusCode;
    if (code == 403 || code == 429) return 'GitHub is limiting requests right now. Try again later.';
    if (code != null) return 'GitHub answered with an error ($code). Try again later.';
    return 'Could not reach GitHub. Check your connection and try again.';
  }
}
