# EtherLex

A calm, fast, keyboard-first desktop companion for Canvas LMS. Windows first, built with Flutter.

Sign in with a Canvas personal access token, or try it with sample data.

## What it does
- **Assignments**: one list from every course, grouped by when it is due, with a details pane (description, attachments, your grade, teacher feedback) and drag-and-drop submitting. Star what matters; finished work folds away.
- **Activity**: announcements, grades and discussions in one feed, with pictures and clickable links.
- **Calendar**: the week at a glance with a "now" line; a day-by-day list in narrow windows.
- **Grades**: every course with now and final grades, and a planner: your own category weights, where the course can still end, and your likely letter from class statistics.
- **Files**: course files with a built-in viewer (PDF, images, text, Markdown, Word and PowerPoint text) and offline copies.
- **Command palette** (Ctrl+K): search everything and run any action from the keyboard. Ctrl+/ lists every shortcut.
- Light and dark themes, a handwritten or clean font, deadline and grade notifications, separate settings per Canvas account.

## Install
Download `EtherLex-Setup-<version>.exe` from the [latest release](../../releases/latest) and run it. Windows 10 or 11.

**"Windows protected your PC".** The installer is not code-signed yet, so Windows SmartScreen warns about any new unsigned program. To continue: click **More info**, then **Run anyway**. You only need this for the first install; updates installed from inside EtherLex are downloaded by the app itself and normally do not show it.

To check that the file is the one we built, compare its SHA-256 with the `.sha256` file next to it on the release page:
```powershell
Get-FileHash .\EtherLex-Setup-<version>.exe -Algorithm SHA256
```

## Develop
- Flutter 3.47.8 (pinned, see CLAUDE.md)
- Run: `flutter run -d windows --profile` (F9 shows frame times)
- Check: `flutter analyze` and `flutter test`
- Installer: `powershell -ExecutionPolicy Bypass -File installer\build.ps1` builds the release app and the installer in one go (needs Inno Setup 7). Don't run ISCC alone: it packs whatever release build is lying around, however old. Pushing a `v*` tag builds it and attaches it to a GitHub release.
- Manual test plan: [docs/TESTING.md](docs/TESTING.md)
- What changed: [CHANGELOG.md](CHANGELOG.md)
- Developer notes: [CLAUDE.md](CLAUDE.md)

## Privacy
Your token is kept in the Windows credential store and only ever sent to your own Canvas. Settings, the offline cache and grade plans stay in `%APPDATA%\EtherLex`.

The optional AI assistant uses your own API key (kept in the Windows credential store). Your messages go to the AI service you choose. Data from Canvas (assignments, grades, announcements, files) is sent to it only when you attach it to a question, after you allow it once for that service, and you can take that permission back in Settings. Nothing is sent to anyone else.

## License
MIT, see [LICENSE](LICENSE). Inter font: SIL Open Font License (`assets/fonts/Inter-LICENSE.txt`).
