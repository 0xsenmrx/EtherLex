/// Launch-time switches for chasing performance problems, for example:
/// `flutter run -d windows --profile --dart-define=ETHERLEX_DIAG=nodots,cleanfont`
///
/// - `nodots`: plain canvas without the dot pattern.
/// - `cleanfont`: Inter even when the handwritten font is chosen.
///
/// The native Windows caption (instead of ours) is an environment variable,
/// because the runner reads it too: `$env:ETHERLEX_NATIVE_FRAME=1`.
const String _diag = String.fromEnvironment('ETHERLEX_DIAG');

// Parsed once: the dot grid asks on every paint.
final Set<String> _flags = {for (final s in _diag.split(',')) if (s.trim().isNotEmpty) s.trim()};

bool diag(String flag) => _flags.contains(flag);
