# Changelog

## Unreleased

### New
- **Assistant** (Alt+6): ask an AI about your courses with your own API key: Anthropic, DeepSeek, or any OpenAI-compatible service (including a model running on your own computer). Answers stream in with full Markdown, highlighted code and copy buttons. Conversations are saved per account.
- Attach assignments, grades, announcements, course files and pictures, or files from your computer. Long files show how much of them is sent, and can be sent whole.
- The assistant can propose changes: a grade plan from a syllabus, starring or marking work done, hiding folders or courses, saving offline, downloading, opening a hand-in card, app settings. Each proposal is a card; nothing happens until you press Apply, and every change has Undo. It never hands in work by itself.
- It can ask to look at a course's files or assignments or a file's text; one Allow answers several requests at once.
- Canvas data goes to the AI service only when you attach it or allow a lookup, after you agree once per service and account. You can take that back in Settings.
- File links in announcements open the exact file in Files.
- Five accent colours in Settings > Appearance: violet, blue, green, rose and orange.
- Settings > About: **Send feedback** opens a prefilled GitHub issue that you read and edit before sending, and **Copy diagnostics** copies version, Windows and look (never a token, key, name or course).
- The README explains the "Windows protected your PC" warning on first install and how to check the installer's SHA-256.

### Fixed and safer
- Every Canvas account now has fully separate data: database, settings, AI service and key, conversations and offline files. Data from an older version is adopted by the first account; nothing is deleted on sign-out or update.
- When Canvas rejects your token, a banner offers to sign in again.
- Your Canvas token is only sent to your own Canvas address over https, also when a download is redirected. The AI server address must be https (plain http only for a model on this computer).
- Word and PowerPoint files are read with size limits, and programs, scripts and macro documents from Canvas are only shown in their folder, never run.
- Files from Canvas are now marked as downloaded from the internet, so Word, Excel and PowerPoint open them in Protected View. Web pages (.html, .svg...) ask before opening in your browser, and more kinds of Windows launchers are only shown in their folder.
- Your permission to send Canvas data to an OpenAI-compatible service now belongs to that server: pointing EtherLex at another server asks again, and if a key is saved it first asks whether the key may go there. The server address is checked as you type (https, or http only for a model on this computer).
- Starting EtherLex while it is already open now brings the open window forward instead of starting a second copy that could overwrite its data.
- Settings > AI assistant > Save now says that it saved.
- Copy diagnostics names the AI service only when a key is saved for it.
- Pictures in a chat say why they could not load; the message box text is aligned with the send button.

## 0.2.2

### New
- EtherLex now tells you when a new version is out. A message appears shortly after start, "What's new" shows what changed, and "Update and restart" downloads, checks and installs it without uninstalling anything. Your settings and offline files stay.
- Settings has a new Updates section: check now, or switch the automatic check off.

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
