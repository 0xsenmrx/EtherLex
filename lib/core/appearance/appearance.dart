import 'dart:io';
import 'dart:ui' show Brightness;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/app_dir.dart';
import '../storage/json_file.dart';

enum ThemeChoice { system, light, dark }

enum TypefaceChoice { handwritten, clean }

/// The accent colour family. Surfaces, text and status colours stay the same.
enum PaletteChoice {
  violet('Violet'),
  blue('Blue'),
  green('Green'),
  rose('Rose'),
  orange('Orange');

  const PaletteChoice(this.label);
  final String label;
}

/// What sits behind everything on the canvas.
enum BackgroundPattern {
  dots('Dots'),
  grid('Grid'),
  none('Plain');

  const BackgroundPattern(this.label);
  final String label;
}

/// App-wide look, shared by every account.
class Appearance {
  const Appearance({
    this.theme = ThemeChoice.system,
    this.typeface = TypefaceChoice.handwritten,
    this.palette = PaletteChoice.violet,
    this.background = BackgroundPattern.dots,
    this.sidebarCollapsed = false,
  });

  final ThemeChoice theme;
  final TypefaceChoice typeface;
  final PaletteChoice palette;
  final BackgroundPattern background;

  /// The icon rail even in a wide window (Ctrl+B).
  final bool sidebarCollapsed;

  bool get handwritten => typeface == TypefaceChoice.handwritten;

  Appearance copyWith({
    ThemeChoice? theme,
    TypefaceChoice? typeface,
    PaletteChoice? palette,
    BackgroundPattern? background,
    bool? sidebarCollapsed,
  }) =>
      Appearance(
        theme: theme ?? this.theme,
        typeface: typeface ?? this.typeface,
        palette: palette ?? this.palette,
        background: background ?? this.background,
        sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
      );

  Map<String, Object> toJson() => {
        'theme': theme.name,
        'typeface': typeface.name,
        'palette': palette.name,
        'background': background.name,
        'sidebarCollapsed': sidebarCollapsed,
      };

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
      palette: pick(PaletteChoice.values, json['palette'], PaletteChoice.violet),
      background: pick(BackgroundPattern.values, json['background'], BackgroundPattern.dots),
      sidebarCollapsed: json['sidebarCollapsed'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Appearance &&
      other.theme == theme &&
      other.typeface == typeface &&
      other.palette == palette &&
      other.background == background &&
      other.sidebarCollapsed == sidebarCollapsed;

  @override
  int get hashCode => Object.hash(theme, typeface, palette, background, sidebarCollapsed);
}

/// `%APPDATA%/EtherLex/appearance.json`.
class AppearanceStore {
  AppearanceStore({File? file})
      : _json = JsonFile(file ?? File('${appDataPath()}${Platform.pathSeparator}appearance.json'));

  final JsonFile _json;

  /// A missing or damaged file gives the defaults.
  Future<Appearance> read() async {
    try {
      return Appearance.fromJson(await _json.read());
    } catch (_) {
      return const Appearance();
    }
  }

  /// Writes run one after another (quick theme toggles must not interleave).
  Future<void> write(Appearance a) => _json.write(a.toJson());
}

final appearanceStoreProvider = Provider<AppearanceStore>((ref) => AppearanceStore());

/// Overridden in main() with the saved value, so the first frame is right.
final initialAppearanceProvider = Provider<Appearance>((ref) => const Appearance());

class AppearanceNotifier extends Notifier<Appearance> {
  @override
  Appearance build() => ref.read(initialAppearanceProvider);

  void setTheme(ThemeChoice t) => _set(state.copyWith(theme: t));

  void setTypeface(TypefaceChoice f) => _set(state.copyWith(typeface: f));

  void setPalette(PaletteChoice p) => _set(state.copyWith(palette: p));

  void setBackground(BackgroundPattern b) => _set(state.copyWith(background: b));

  void toggleSidebar() => _set(state.copyWith(sidebarCollapsed: !state.sidebarCollapsed));

  /// Settings > Appearance > Reset: Match Windows, handwritten, violet, dots.
  /// The sidebar stays as it is (it is a layout choice, not a look).
  void reset() => _set(Appearance(sidebarCollapsed: state.sidebarCollapsed));

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
