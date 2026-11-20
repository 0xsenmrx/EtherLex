import 'update_info.dart';

/// Update settings, shared by every account.
class UpdatePrefs {
  const UpdatePrefs({this.autoCheck = true, this.skippedVersion, this.lastCheck});

  /// Look for a new release when the app starts.
  final bool autoCheck;

  /// A version the user chose not to be told about again.
  final String? skippedVersion;
  final DateTime? lastCheck;

  UpdatePrefs copyWith({bool? autoCheck, String? skippedVersion, DateTime? lastCheck}) => UpdatePrefs(
        autoCheck: autoCheck ?? this.autoCheck,
        skippedVersion: skippedVersion ?? this.skippedVersion,
        lastCheck: lastCheck ?? this.lastCheck,
      );

  Map<String, Object> toJson() => {
        'autoCheck': autoCheck,
        'skippedVersion': ?skippedVersion,
        'lastCheck': ?lastCheck?.toUtc().toIso8601String(),
      };

  static UpdatePrefs fromJson(Object? json) {
    if (json is! Map) return const UpdatePrefs();
    final skipped = json['skippedVersion'];
    final last = json['lastCheck'];
    return UpdatePrefs(
      autoCheck: json['autoCheck'] != false,
      skippedVersion: skipped is String && skipped.isNotEmpty ? skipped : null,
      lastCheck: last is String ? DateTime.tryParse(last) : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UpdatePrefs &&
      other.autoCheck == autoCheck &&
      other.skippedVersion == skippedVersion &&
      other.lastCheck == lastCheck;

  @override
  int get hashCode => Object.hash(autoCheck, skippedVersion, lastCheck);
}

/// Whether the app should look for a release now: switched on, and not
/// already looked within [every].
bool shouldAutoCheck(UpdatePrefs prefs, DateTime now, {Duration every = const Duration(hours: 12)}) {
  if (!prefs.autoCheck) return false;
  final last = prefs.lastCheck;
  return last == null || now.difference(last) >= every || last.isAfter(now);
}

/// Whether [info] should be offered: newer than [current] and, unless the
/// user asked for it, not a version they skipped.
bool shouldOffer(UpdateInfo info, AppVersion current, UpdatePrefs prefs, {bool ignoreSkip = false}) {
  if (!(info.version > current)) return false;
  return ignoreSkip || prefs.skippedVersion != '${info.version}';
}
