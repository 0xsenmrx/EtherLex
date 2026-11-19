import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Brightness;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_dir.dart';

enum ThemeChoice { system, light, dark }

enum TypefaceChoice { handwritten, clean }

/// App-wide look, shared by every account.
class Appearance {
  const Appearance({
    this.theme = ThemeChoice.system,
    this.typeface = TypefaceChoice.handwritten,
  });

  final ThemeChoice theme;
  final TypefaceChoice typeface;

  bool get handwritten => typeface == TypefaceChoice.handwritten;

  Appearance copyWith({ThemeChoice? theme, TypefaceChoice? typeface}) =>
      Appearance(theme: theme ?? this.theme, typeface: typeface ?? this.typeface);

  Map<String, Object> toJson() => {'theme': theme.name, 'typeface': typeface.name};

  static Appearance fromJson(Object? json) {
    if (json is! Map) return const Appearance();
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) {
      for (final v in values) {
        if (v.name == raw) return v;
      }
      return fallback;
    }

    return Appearance(
      theme: pick(ThemeChoice.values, json['theme'], ThemeChoice.system),
      typeface: pick(TypefaceChoice.values, json['typeface'], TypefaceChoice.handwritten),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Appearance && other.theme == theme && other.typeface == typeface;

  @override
  int get hashCode => Object.hash(theme, typeface);
}

/// `%APPDATA%/EtherLex/appearance.json`.
class AppearanceStore {
  AppearanceStore({File? file})
      : _file = file ?? File('${appDataPath()}${Platform.pathSeparator}appearance.json');

  final File _file;

  Future<Appearance> read() async {
    try {
      if (!await _file.exists()) return const Appearance();
      return Appearance.fromJson(jsonDecode(await _file.readAsString()));
    } catch (_) {
      return const Appearance();
    }
  }

  Future<void>? _pending;

  /// Writes run one after another (quick theme toggles must not interleave).
  Future<void> write(Appearance a) {
    final next = (_pending ?? Future<void>.value())
        .catchError((Object _) {})
        .then((_) => writeFileAtomically(_file, jsonEncode(a.toJson())));
    _pending = next;
    return next;
  }
}

final appearanceStoreProvider = Provider<AppearanceStore>((ref) => AppearanceStore());

/// Overridden in main() with the saved value, so the first frame is right.
final initialAppearanceProvider = Provider<Appearance>((ref) => const Appearance());

class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() => ref.read(initialAppearanceProvider);

  void setTheme(ThemeChoice t) => _set(state.copyWith(theme: t));

  void setTypeface(TypefaceChoice f) => _set(state.copyWith(typeface: f));

  /// Switch to the opposite of what is on screen now.
  void toggleBrightness(Brightness current) =>
      setTheme(current == Brightness.dark ? ThemeChoice.light : ThemeChoice.dark);

  void _set(Appearance next) {
    if (next == state) return;
    state = next;
    ref.read(appearanceStoreProvider).write(next).catchError((Object _) {});
  }
}

final appearanceProvider =
    NotifierProvider<AppearanceNotifier, Appearance>(AppearanceNotifier.new);
