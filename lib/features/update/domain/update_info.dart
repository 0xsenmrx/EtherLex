/// GitHub repository whose releases the update check reads.
const String kUpdateRepo = '0xsenmrx/EtherLex';

/// "1.2.3", "v1.2.3" or "1.2.3+4". Pre-release tags such as "1.2.3-beta" are
/// not versions we offer.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static AppVersion? tryParse(String text) {
    final m = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:\+\d+)?$').firstMatch(text.trim());
    if (m == null) return null;
    return AppVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// A release that can be installed: the installer, how to verify it, and
/// what changed.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.notes,
    required this.installerName,
    required this.installerUrl,
    required this.pageUrl,
    this.size,
    this.sha256,
    this.checksumUrl,
  });

  final AppVersion version;

  /// The release description (Markdown), as written on GitHub.
  final String notes;
  final String installerName;
  final Uri installerUrl;
  final Uri pageUrl;
  final int? size;

  /// Lower-case hex SHA-256 of the installer, when GitHub states it.
  final String? sha256;

  /// A small `<installer>.sha256` file attached to the release, when the
  /// hash is not in the release data itself.
  final Uri? checksumUrl;

  UpdateInfo withSha256(String hash) => UpdateInfo(
        version: version,
        notes: notes,
        installerName: installerName,
        installerUrl: installerUrl,
        pageUrl: pageUrl,
        size: size,
        sha256: hash,
      );
}

final _installerName = RegExp(r'^EtherLex-Setup-.+\.exe$');
final _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

/// Only files published on this repository's own releases are trusted.
Uri? _trustedDownload(Object? raw, String repo) {
  if (raw is! String) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || uri.scheme != 'https' || uri.host != 'github.com') return null;
  if (!uri.path.startsWith('/$repo/releases/download/')) return null;
  return uri;
}

/// Reads one GitHub release (the JSON of `/releases/latest`).
///
/// Returns null for drafts, pre-releases and tags that are not versions.
/// Throws [FormatException] for a normal release that cannot be installed
/// safely: no installer, a link from somewhere else, or no checksum.
UpdateInfo? parseRelease(Object? json, {String repo = kUpdateRepo}) {
  if (json is! Map) return null;
  if (json['draft'] == true || json['prerelease'] == true) return null;
  final tag = json['tag_name'];
  if (tag is! String) return null;
  final version = AppVersion.tryParse(tag);
  if (version == null) return null;

  final raw = json['assets'];
  final assets = raw is List ? raw.whereType<Map>().toList() : const <Map>[];
  Map? installer;
  for (final a in assets) {
    final name = a['name'];
    if (name is String && _installerName.hasMatch(name)) {
      installer = a;
      break;
    }
  }
  if (installer == null) throw FormatException('Release $tag has no installer attached.');
  final name = installer['name'] as String;
  final url = _trustedDownload(installer['browser_download_url'], repo);
  if (url == null) throw FormatException('Release $tag links an installer from outside $repo.');

  String? sha;
  final digest = installer['digest'];
  if (digest is String && digest.startsWith('sha256:')) {
    final hex = digest.substring(7);
    if (_hex64.hasMatch(hex)) sha = hex.toLowerCase();
  }
  Uri? checksumUrl;
  if (sha == null) {
    for (final a in assets) {
      if (a['name'] == '$name.sha256') checksumUrl = _trustedDownload(a['browser_download_url'], repo);
    }
    if (checksumUrl == null) throw FormatException('Release $tag has no checksum for its installer.');
  }

  final page = json['html_url'];
  final pageUri = page is String ? Uri.tryParse(page) : null;
  final size = installer['size'];
  return UpdateInfo(
    version: version,
    notes: json['body'] is String ? json['body'] as String : '',
    installerName: name,
    installerUrl: url,
    pageUrl: pageUri != null && pageUri.scheme == 'https' && pageUri.host == 'github.com'
        ? pageUri
        : Uri.parse('https://github.com/$repo/releases/tag/$tag'),
    size: size is int ? size : null,
    sha256: sha,
    checksumUrl: checksumUrl,
  );
}

/// Reads a `sha256sum`-style file (`<64 hex>  <name>`) and returns the hash
/// for [fileName], or for a bare hash line. Null when there is none.
String? parseChecksumFile(String text, String fileName) {
  for (final line in text.split(RegExp(r'\r?\n'))) {
    final m = RegExp(r'^([0-9a-fA-F]{64})(?:\s+\*?(.+?))?\s*$').firstMatch(line.trim());
    if (m == null) continue;
    final name = m[2];
    if (name == null || name == fileName) return m[1]!.toLowerCase();
  }
  return null;
}
