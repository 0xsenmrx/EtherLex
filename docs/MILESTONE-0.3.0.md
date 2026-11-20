# Milestone 0.3.0: "Share-ready"

**Goal:** a person at another university can install EtherLex, connect it (or try the sample data), and within five minutes use the three things that make it stand out: file links that jump to the file, a look they actually like, and an AI that knows their courses. When that works on a computer that is not yours, EtherLex goes to the international chats.

**Sizes:** S = one sitting, M = a few sittings, L = the long pole.

## Status
- M1 done and merged (#19).
- Next: M3 (AI chat), then M2, then M4.

## What the code already has (so we don't rebuild it)

| Idea | Already there | Actually missing |
| --- | --- | --- |
| 1. File links | `FilesRepository.fileInfo(courseId, fileId)`, `showFilePreview`, `LinkText` | `htmlToText` drops `/files/<id>` links on purpose (`core/utils/html_text.dart`). `/files` route takes no parameters. |
| 2. Themes | Light / dark / system and handwritten / clean font (`core/appearance`, Settings > Appearance) | Colours are two fixed sets (`EtherColors.light/dark`) with one violet accent. Your friend can't choose a different look. |
| 3. AI chat | `flutter_secure_storage` (for the key), Dio, `markdown_view`, `file_selector`, `desktop_drop`, `pdfrx` | No chat code at all. No text extraction from PDFs (only Word/PowerPoint/text in `doc_text.dart`). |
| Sign-in help | Token steps and "Explore with sample data" on the sign-in screen | Nothing for strangers' problems (see M4). |

---

## M1. Files linked in announcements are clickable [S to M]: DONE (#6, PR #19)
**Now:** a file linked in an announcement shows as plain text.
**Do:**
- Stop discarding Canvas file links in `htmlToText`. Keep them as structured links (file id, course id, shown name), not as text, so `LinkText` can render them as links. Cover `/courses/1/files/2?wrap=1`, `/files/2/download` and `data-api-endpoint` forms.
- A click opens the Files tab on that course and folder, selects the file and scrolls it to the middle. Enter opens the preview. (Done with a small provider, not URL parameters.)
- If the file is locked or deleted (`fileInfo` returns null): toast "That file isn't available" with an "Open in Canvas" action.
- Assignment descriptions are unchanged: they already list their files as attachment rows.
- Add a sample-data announcement with two file links, so it can be demoed without Canvas.

**Done when:** an announcement's file link shows in the accent colour with a pointer cursor and lands on the exact file; works from the details pane and from the dialog; a locked file does not crash; tests cover link parsing and the query parameters.

## M2. Themes that actually change the look [M]
**Now:** light/dark exist, but every theme is violet. A different feeling needs different palettes.
**First:** ask your friend what he dislikes (colours? the dotted canvas? density? the handwritten font?). Ten minutes, and it tells you which option below matters.
**Do:**
- Build `EtherColors` from a palette (accent plus neutral tint) instead of two constants. Each palette has a light and a dark variant.
- Ship 5 to 6 presets: Violet (current, stays the default), Ocean, Forest, Rose, Graphite (nearly monochrome), Warm.
- Settings > Appearance: a swatch grid with live preview. Add "Theme: ..." actions to the command palette. `appearance.json` gets a `palette` field; an unknown value falls back to Violet.
- Pick at most two extras based on your friend's answer: dotted canvas on/off, compact/comfortable density, corner roundness.

**Done when:** switching a preset changes the whole app instantly with no restart; it is remembered; the 4.5:1 text contrast check (a unit test) passes for every preset in light and dark; nothing hard-codes a colour (rule from CLAUDE.md).

## M3. In-app AI chat [L], in four steps
**Decisions I'm assuming (change them if you disagree):**
- Bring your own API key. Every friend pastes their own, so you don't pay for anyone and you need no server. A hosted version is out of scope.
- One provider interface, with Anthropic first and an "OpenAI-compatible endpoint" second (this also covers local models). Model name is a setting.
- The key lives in secure storage. It is never logged and never stored in settings JSON.

### M3a. Chat foundation [M]
Chat page (Alt+6 and a Ctrl+K action), streaming answers, markdown rendering, stop and regenerate, a model picker. Conversations saved locally (Drift schema v4: migration plus `build_runner`). Clear errors for a wrong key, rate limit, no internet and a too-long input.
**Done when:** you can have a streamed, saved conversation that survives a restart, and a wrong key gives a readable message.

### M3b. Knows your Canvas [M]
An "Ask AI" button in assignment and announcement details that opens a chat with that item attached. An `@` picker to attach assignments, announcements and grades by name. The system prompt includes today's date and the course.
**Done when:** "what's due this week and what should I start first?" gives a correct answer from your real assignments.

### M3c. Files [M to L]
- Attach from the Files tab, reusing `FilesRepository.localPath`. Attach from the computer with `file_selector` and drag-and-drop.
- Text extraction: text/Markdown/Word/PowerPoint already work via `doc_text.dart`. PDFs need new extraction with `pdfrx`. Scanned PDFs have no text: warn, or send page images.
- Attached items appear as removable chips, with a size/token meter so a 300-page PDF doesn't silently blow the limit.
**Done when:** you can attach a lecture PDF plus an assignment and get answers that use both; an unreadable file says so instead of failing quietly.

### M3d. Privacy and guardrails [S]
- First use: one plain screen saying what leaves the computer (your messages plus exactly the attached items) and to which provider.
- Update the privacy line in the README and CLAUDE.md. Today they say only Canvas and GitHub releases are contacted; the AI feature changes that.
- The AI never gets a submit action. It can draft; you upload. Keep the human in the loop.
- Sign-out and "Remove API key" both wipe the key.

## M4. Ready for strangers [M]
- **Test on other Canvas sites.** `CLAUDE.md` lists score statistics, grades, feedback files and multi-file submit as unverified against real Canvas. Get two or three friends from different schools to run `docs/TESTING.md`. Anything that fails must fail gracefully, not crash.
- **Sign-in edge cases.** The token steps are already there. Add: a school that blocks creating tokens (say so clearly and point to the sample data), and URL forms like `school.instructure.com` versus a custom domain.
- **Unsigned installer.** Windows SmartScreen will show "Windows protected your PC". Either write the two-click workaround in the README and release notes, or pay for code signing. Your call.
- **Feedback path.** Settings > "Send feedback" (a GitHub issue link) and "Copy diagnostics" (version, Windows version, no tokens). Without this, bugs from 20 strangers won't reach you.
- **Front door.** README with 2 to 3 screenshots (or one GIF), a download link and a one-line "Windows only for now". Check the repo and releases are public (the in-app update check needs public releases).
- **Release.** Bump `pubspec.yaml` to `0.3.0+5` (and `AppVersion` default in `installer/etherlex.iss`), add a `## 0.3.0` section to `CHANGELOG.md` (the release workflow fails without it), tag `v0.3.0`. Test the update path from an installed 0.2.2.
- **TESTING.md:** add sections for file links, themes and AI chat.

## Order
1. **M1**: quick win, builds momentum.
2. **M3a to M3d**: the long pole and the riskiest, so it starts early.
3. **M2**: isolated; it can lose its extras without hurting the milestone.
4. **M4**: last, because it tests everything above.

**Cut line if time runs short:** M2 extras beyond four presets, and page-image input for scanned PDFs in M3c. Everything else is required.

## Release test (the milestone is done when all pass)
1. Fresh Windows user account, install from the GitHub release, sign in with a real token: no crash, data appears.
2. Open an announcement with a file link, click it, land on the file, preview opens.
3. Switch through every theme preset in light and dark: nothing unreadable.
4. Paste an API key, attach a PDF from Files and a file from the computer, ask a question about both: sensible streamed answer.
5. Install 0.2.2, then let it update to 0.3.0: settings and offline files survive.
6. Someone who isn't you completes steps 1 to 4 without your help.

## Not in this milestone
macOS/Linux builds, a hosted AI with accounts or billing, auto-submitting homework, a free-form custom theme editor, mobile.

## Risks
- PDF text extraction quality and long files can eat most of the AI work; budget for it.
- API cost lands on each friend's key; the token meter in M3c matters for that reason.
- Real Canvas sites differ; M4 testing may turn up fixes that are not in this list.
- Flutter stays pinned to 3.47.8 (see CLAUDE.md); don't upgrade mid-milestone.
