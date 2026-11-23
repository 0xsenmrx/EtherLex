# Changelog

## 0.3.0

Share-ready: an assistant that knows your courses (with your own AI key), a searchable Settings window, accent colours and backgrounds, downloads where you want them, and a long list of fixes from a pre-release review.

### New
- **Assistant** (Alt+6): ask an AI about your courses with your own API key: Anthropic, DeepSeek, or any OpenAI-compatible service (including a model running on your own computer). Answers stream in with full Markdown, highlighted code and copy buttons. Conversations are saved per account.
- Attach assignments, grades, announcements, course files and pictures, or files from your computer. Long files show how much of them is sent, and can be sent whole.
- The assistant can propose changes: a grade plan from a syllabus, starring or marking work done, hiding folders or courses, saving offline, downloading, opening a hand-in card, app settings. Each proposal is a card; nothing happens until you press Apply, and every change has Undo. It never hands in work by itself.
- It can ask to look at a course's files or assignments or a file's text; one Allow answers several requests at once.
- Canvas data goes to the AI service only when you attach it or allow a lookup, after you agree once per service and account. You can take that back in Settings.
- **New Settings**: a wide window with a sidebar of sections (Account, Appearance, Notifications, Courses, Assistant, Files & downloads, Updates, Keyboard shortcuts, Help & About) and a search box that finds any setting by its name, its description or related words ("dark", "key", "update"). Each section that has choices can be reset to its defaults, which never touches your token, keys or data. Ctrl+, opens the section you used last.
- Settings > Appearance shows each choice as a card you can see: Light, Dark or Match Windows; the font with a sample; and a new **Background**: dots, grid or plain. Five accent colours: violet, blue, green, rose and orange. Ctrl+K can switch them too (type "accent" or "grid"). Theme and font left the avatar menu.
- Ctrl+K finds much more: course files (from the listings saved on this computer, so nothing is fetched while you type; Enter opens Files on that file), your conversations with the assistant (by title or by anything written in them; Enter opens the conversation at that message), and any setting (it opens Settings with the search filled in). Type a course name to open its files.
- Choose where downloads go: Settings > Files & downloads has the folder (Change, Reset), "Ask where to save each time" and "A folder for each course". By default EtherLex now uses the Downloads folder Windows really uses, also when you moved it to another drive or to OneDrive.
- Offline files: removing them asks first and says how much, Settings > Files & downloads shows the space per course with a Clear for each, and you can keep up to 1, 3, 5 or 10 GB (lowering it removes the files opened longest ago). The size is counted in the background, so a big offline folder no longer stalls the window.
- Empty pages now offer a next step: Refresh, Show everything, Show all courses or Open Settings. An empty Assistant shows three example questions you can click to fill the message box (nothing is sent until you press Enter), and says how attaching and Apply work.
- Keyboard: Ctrl+N starts a new chat from anywhere, Ctrl+R and F5 refresh Files too, and tooltips show the shortcut (Alt+1 to Alt+6 on the sidebar, Refresh, the week arrows, New chat). The shortcut list is corrected (R marks done or not done).
- EtherLex remembers how you left each page, per account: All or Starred and the open "Done earlier" group in Assignments, the Activity filter, the open "No grades yet" group in Grades, and the course and folder you had open in Files. The Calendar still opens on this week.
- The sidebar has a row of tools at the bottom: Settings, keyboard shortcuts, help and feedback, the light/dark switch, and a button (or Ctrl+B) to collapse it to the icon rail, which is remembered. The avatar menu now only holds your account and Sign out.
- File links in announcements open the exact file in Files.
- Settings > Help & About: **Send feedback** opens a prefilled GitHub issue that you read and edit before sending, and **Copy diagnostics** copies version, Windows and look (never a token, key, name or course).
- Settings > Assistant: **Keep conversations** Always, 30 days, or Until I close EtherLex (nothing is written to disk; chats stay on screen until you close), per account, and **Delete all conversations** (asks first, with the count). Resetting the Assistant section does not touch your chats.
- EtherLex opens where you left it: same size and position, maximised if it was. If that screen is no longer connected it opens on the nearest one, fitted inside it.
- Keyboard: Tab from a course in the sidebar reaches its Disable button, and H in Files hides or shows the selected folder or course (those buttons only appear on hover).
- With Windows' "Animation effects" off (Settings > Accessibility > Visual effects), EtherLex has no transitions at all: pages and dialogs switch at once, nothing fades or springs, loading rows do not pulse.
- The README explains the "Windows protected your PC" warning on first install and how to check the installer's SHA-256.

### Fixed and safer
- Easier to read: quiet grey text, warnings and links now meet the WCAG AA contrast level (4.5:1) in light and dark and in every accent colour, and white text on buttons stays readable in dark mode (the red Delete and Sign out buttons were hard to read).
- Every Canvas account now has fully separate data: database, settings, AI service and key, conversations and offline files. Data from an older version is adopted by the first account; nothing is deleted on sign-out or update.
- When Canvas rejects your token, a banner offers to sign in again.
- Your Canvas token is only sent to your own Canvas address over https, also when a download is redirected. The AI server address must be https (plain http only for a model on this computer).
- Word and PowerPoint files are read with size limits, and programs, scripts and macro documents from Canvas are only shown in their folder, never run.
- Files from Canvas are now marked as downloaded from the internet, so Word, Excel and PowerPoint open them in Protected View. Web pages (.html, .svg...) ask before opening in your browser, and more kinds of Windows launchers are only shown in their folder.
- Your permission to send Canvas data to an OpenAI-compatible service now belongs to that server: pointing EtherLex at another server asks again, and if a key is saved it first asks whether the key may go there. The server address is checked as you type (https, or http only for a model on this computer).
- Starting EtherLex while it is already open now brings the open window forward instead of starting a second copy that could overwrite its data.
- Settings > Assistant > Save now says that it saved.
- The collapsed sidebar no longer overflows in a short window: its page buttons scroll when they do not fit.
- Odd text from Canvas (a link with an impossibly long file number, or a character code that does not exist, in an announcement, a discussion post or a message) no longer stops Activity from updating; an item EtherLex cannot read is left out instead of failing the whole feed. Word and PowerPoint files with such codes open too.
- A save no longer gets lost when another program (a virus scanner, the search indexer) has the settings or chats file open for a moment: EtherLex tries again for up to a second.
- Turning in a submission confirms the upload only with Canvas itself (https, same host and port), like every other request that carries your token.
- Moving through Files with J/K or the arrows redraws only the two rows involved, not the whole list (smoother in big folders).
- Copy diagnostics names the AI service only when a key is saved for it.
- Clicking an empty part of a page no longer makes Windows play its "ding" (it did since 0.2.0).
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
