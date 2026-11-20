# Changelog

## 0.2.1

### Fixed
- Opening a PDF and scrolling it quickly could freeze the window black until the app was restarted. The cause is a Flutter 3.50.0 bug (flutter/flutter#196618), so EtherLex now builds with Flutter 3.47.8.

## 0.2.0

A new look and a faster, steadier app.

### Look and feel
- New design: dotted canvas, flat surfaces, violet accent, Lucide icons.
- Light and dark themes (or match Windows), handwritten or clean font.
- Layouts adapt to the window: sidebar or icon rail, details beside the list or in a dialog, week grid or day list.
- Our own title bar with Snap Layouts, the window menu on right-click, and resizing from every edge.
- Command palette (Ctrl+K), search (Ctrl+F), shortcuts list (Ctrl+/), settings (Ctrl+,).
- New sign-in screen and app icon.

### Faster
- Window resizing: the title bar is drawn by the app's own window code instead of a plugin that slowed every resize step, and the app renders with Skia, which resizes smoothly where Impeller lagged.
- Moving the keyboard cursor rebuilds two rows instead of every visible row.
- Grade summaries are calculated when their plan or coursework changes, not on every hover.
- Document previews read and parse a file once instead of on every resize frame.
- "Offline" labels and the offline size no longer touch the disk on every rebuild.
- Syncing writes assignments to the database once instead of twice.
- Spinners, the details pane and dialog contents repaint on their own.

### Fixed
- The star animation replayed whenever a starred row scrolled into view.
- The refresh icon could stop spinning while a sync was still running.
- Two settings saved at the same moment could undo each other, and a crash while saving could reset all settings.
- Switching account during a sync could show the previous account's grades or sync status.
- Closing an assignment while its upload ran lost the "Submitted" message and the done mark.
- Opening and downloading the same file at once could corrupt the saved copy.
- Several cases where closing a dialog early caused an error in the background.

### Removed
- The window_manager and nativeapi packages.
