# EtherLex: working notes

Premium, smooth, desktop-first Flutter companion for Canvas LMS. Windows first. Package `etherlex`, app name in `lib/app/app_info.dart`.

## Commands
- `flutter pub get` after any pubspec change
- `dart run build_runner build --delete-conflicting-outputs` after any Drift schema change (schema is v3)
- `flutter analyze` and `flutter test` must both be clean before a change is done
- `flutter run -d windows --profile` to judge smoothness (debug mode is not representative). F9 toggles the perf overlay.

## Architecture
- Feature-first: `lib/features/<feature>/{domain,data,presentation}`. Shared code in `lib/core`, widgets and tokens in `lib/design_system`.
- UI reads local Drift streams or cached data; repositories write them. Sample mode uses in-memory mock repositories (`Mock*Repository`), real mode uses `Canvas*Repository`. Every repository interface needs both.
- Riverpod 3 (Notifier, AsyncNotifier, StreamProvider). Routing: go_router ShellRoute. HTTP: Dio through `CanvasClient`. DB: one Drift file per Canvas host (`AppDatabase.forAccount`).
- Settings: one JSON file per account, `%APPDATA%/EtherLex/settings/<host>.json` (`FileSettingsStore.forScope`). Notifiers must `ref.watch(settingsStoreProvider)` and ignore loads from a stale store.
- Offline files: `%APPDATA%/EtherLex/files/<host>/` (LRU, 3 GB) and saved listings in `file_index/<host>/`. All file access goes through `FilesRepository.localPath`.
- Auth: personal access token in flutter_secure_storage.

## Design system
- New look ("Oleafly feel"): dotted canvas, flat surfaces with hairlines, violet accent, handwritten Ink Free (Windows font, falls back to Segoe Print then Inter) or clean Inter, light and dark.
- Tokens: `design_system/theme/ether_colors.dart` (EtherColors.light/dark), `ether_text.dart`, `ether_theme.dart`. Read them with `context.colors` and `context.text`; never hard-code colours.
- Components: `design_system/ether/` (ETap for hover/focus/press, EIconButton, EButton, ESearchTrigger, ESwatch, DotGrid, showEtherDialog/EDialog/confirmAction, menu styles). Icons only via `EIcons` (Lucide).
- List screens: `design_system/ether/list.dart` (EPageHeader, ESyncButton, ESegmented, EGroupHeader, ESectionLabel, ECheck, EStar, EEmptyState, EErrorState, ESkeletonList) and `detail_pane.dart` (details beside the list from 860 px of content width, a dialog below that). Selection = keyboard cursor = what the pane shows; Esc clears it.
- Appearance (theme + typeface) is app-wide: `%APPDATA%/EtherLex/appearance.json`, `appearanceProvider`.
- Window: our own title bar, no native caption. The runner (`windows/runner/window_frame.cpp`) removes the caption in `WM_NCCALCSIZE` and answers `WM_NCHITTEST` for the top resize edge and the maximise button (`HTMAXBUTTON`, which gives Snap Layouts); no layered window, no DWM frame extension. Dart talks to it over the `etherlex/window` channel (`WindowControl` in `app/window/window_chrome.dart`). No window_manager/nativeapi: their custom frame made every resize step slow on the raster thread. `ETHERLEX_NATIVE_FRAME=1` (environment variable) brings the native caption back for comparisons. Other diagnostic switches: `core/diag.dart`.
- Renderer: Skia, not Impeller (`set_impeller_switch(Disabled)` in `windows/runner/main.cpp`). With Impeller, live resizing lagged even with the native frame; Skia is smooth. Flutter will remove this opt-out at some point: after each Flutter upgrade, compare resizing with `flutter run -d windows --profile --enable-impeller`.

## Rules
- Do not add `BackdropFilter` to dialogs. Use `SmoothScrollController` for lists.
- Dart raw strings cannot contain `\'`: use triple-quoted raw strings for regexes with both quote kinds.
- Lints: use null-aware elements (`?value`) instead of `if (x != null) x`.
- Add a test for every piece of pure logic (parsing, grade maths, alerts, cache). Files in `test/` mirror the feature.
- Only the user's own data and the Canvas API are touched. Never log tokens.

## Status
Done: sign-in, assignments, activity, calendar week, global search (Ctrl+K / Ctrl+F), clickable links, deadline and grade notifications, submissions and teacher feedback download, grades with planner and class standing, file browser, preview, offline cache, per-account settings.
Unverified against real Canvas: `score_statistics`, grades, feedback files, multi-file submit.
Keep `features/palette/domain/shortcuts.dart` in step with every CallbackShortcuts.
Manual test plan: `docs/TESTING.md`.
