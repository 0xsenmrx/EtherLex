# EtherLex: full manual testing workflow

Do the parts in order. Each step says what to do, then **Expect** what you should see. Tick the box or write down what differed. If something fails, note the step number and what you saw (a screenshot helps).

Data you need: a real Canvas account with a personal access token, at least one course with files, some assignments (one submitted, one graded with teacher feedback, one with a due date within 3 days if possible), and if possible a second Canvas account or site.

Shortcuts used: **Ctrl+K** command palette, **Ctrl+F** search only, **Alt+1..6** Assignments, Activity, Calendar, Grades, Files, Assistant, **Ctrl+,** settings, **Ctrl+/** all shortcuts, **Esc / Backspace / Alt+Left** back in Files, **F9** performance overlay.

---

## 0. Automatic checks (2 min) [DONE]

- [x] `flutter analyze` → **Expect** "No issues found".
- [x] `flutter test` → **Expect** "All tests passed".
- [x] `flutter run -d windows --profile` → **Expect** the window opens with no red errors in the console.

## 1. Sign-in and sample mode [DONE]

1. Start with a clean state: sign out if signed in (avatar menu top right, or Settings → Sign out; it asks first).
- [x] **Expect** the "Connect to Canvas" screen.
2. Enter a wrong URL (e.g. `abc`), press connect.
- [x] **Expect** a clear error, not a crash.
3. Enter the right Canvas URL and a wrong token.
- [x] **Expect** an "unauthorized/invalid token" style error.
4. Enter the right URL and token.
- [x] **Expect** you land in the app and your name shows; assignments start loading.
5. Close the app fully and reopen.
- [x] **Expect** you are still signed in (token remembered) with data visible immediately.
6. Sign out, choose the sample data option.
- [x] **Expect** the app works with fake courses and no network calls.
7. Sign out again and sign back in with the real token.
- [x] **Expect** your real data returns.

## 2. Assignments [DONE]

1. Press **Alt+1**.
- [x] **Expect** your assignments grouped/sorted sensibly, with course colour and due time.
2. Click the refresh control.
- [x] **Expect** a short spinner, then the list updates without jumping to the top.
3. Click an assignment.
- [x] **Expect** the details pane on the right (a dialog in a narrow window) with the description; links are clickable and open in your browser. J/K move and the pane follows; Esc closes it.
4. Star an assignment, close and reopen the app.
- [x] **Expect** the star is still there.
5. In the sidebar select one course, then another, then clear.
- [x] **Expect** the list filters to that course and back.
6. Disable a course (sidebar "Disabled" folder).
- [x] **Expect** it disappears from lists and counts; selecting it in the Disabled folder still shows it. Enable it again.
7. On a **submitted** assignment open the dialog.
- [x] **Expect** a "my submission" section with your file name(s) and a download action.
8. Download your submitted file.
- [x] **Expect** a toast "Saved to Downloads" with Open/Show; the file is in Downloads and opens.
9. On a **graded** assignment with teacher feedback.
- [x] **Expect** the grade, teacher comments, and any attached feedback files listed.
10. Download a feedback file.
- [x] **Expect** it saves to Downloads and opens correctly.
11. Submit test (use a throw-away assignment or ask first): drag a file onto the dialog, then try the file picker.
- [x] **Expect** the file is listed before sending, and a clear success or error afterwards. (Multi-file submit is untested: try two files and note the result.)
12. Open an assignment with attachments from the teacher.
- [x] **Expect** the attachments list; clicking one previews or downloads it.
13. Make the dialog content large (long description or lots of feedback).
- [x] Known: the card grows to full height. Only note anything that is unusable (cannot scroll or close). Esc must close it.

## 3. Activity [DONE]

1. Press **Alt+2**.
- [x] **Expect** announcements and grade updates with course names and times.
2. Click an announcement.
- [x] **Expect** it opens fully; links are clickable and images load.
3. Scroll fast with the mouse wheel and with the trackpad if you have one.
- [x] **Expect** smooth scrolling, no stutter. Press **F9** and confirm frames stay in the green.
- [x] Known gap: no keyboard navigation yet.
4. In sample mode open "Lecture 1 slides and Problem Set 1". Click "Lecture 1 - Introduction.pdf", then repeat with "Problem Set 1.pdf".
- [x] **Expect** both file names are in the link colour with a pointer cursor. A click closes the dialog (narrow window) and opens Files on that course and folder, with the file selected and scrolled to the middle; Enter opens the preview. "Problem Set 1.pdf" has no course in its link and still works.
5. With a real account, open an announcement that links a file, and one whose file is locked or deleted.
- [x] **Expect** the first lands on the file. The second shows "That file isn't available." with "Open in Canvas", and nothing crashes.

## 4. Calendar [DONE]

1. Press **Alt+3**.
- [x] **Expect** a week view with this week; today is marked.
2. Go to the next and previous week, and back to today.
- [x] **Expect** assignments appear on the day they are due, at the right time.
3. Click an item.
- [x] **Expect** the assignment dialog opens.
4. Compare two items you know against Canvas's own calendar.
- [x] **Expect** the same day and time (check the time zone is yours).

## 5. Grades and planner [DONE]

1. Press **Alt+4**.
- [x] **Expect** one card per course with percent, letter (if Canvas gives one), and final grade where available. Compare each with Canvas.
2. Open a course's planner.
- [x] **Expect** categories (assignment groups) with weights, and your current grade.
3. Compare "current grade" with Canvas's own total for that course.
- [x] **Expect** the same (or very close). Write down any course that differs and its weights setup.
4. Set weights manually (e.g. Quizzes 20, Homework 30, Exam 50).
- [x] **Expect** the weights total shows 100% and the current grade changes accordingly. With all weights 0 the total must show 0%, not another number.
5. Add a **custom category**, rename it, move an assignment into it, then delete it.
- [x] **Expect** the assignment returns to its old group after deleting.
6. Set a **total count** for a category (e.g. 6 quizzes when only 2 exist).
- [x] **Expect** the missing 4 are treated as not yet done: the worst/half/steady/best scenarios change and the weight is shared across all 6.
7. Read the four scenarios (worst, half, steady, best).
- [x] **Expect** worst ≤ half ≤ best; "same as before" sits in between and shows a letter.
8. Enter letter quotas (e.g. A+ 10%, A 15%…).
- [x] **Expect** a "likely letter" and standing estimate appear using class statistics. Note: statistics need Canvas to expose them for the assignment; if absent the estimate should say so, not guess silently.
9. Close and reopen the app.
- [x] **Expect** your weights, custom groups, totals and quotas are still there.
10. Course card on the Grades list.
- [x] **Expect** it shows "yours X% · likely L" once a plan exists.

## 6. Search [DONE]

1. Press **Ctrl+K** (then try **Ctrl+F**).
- [x] **Expect** the palette opens near the top with the cursor in it. Ctrl+K lists pages and actions before you type; Ctrl+F shows search only.
2. Type a word from an assignment, an announcement, a grade entry and a file name (one search each).
- [x] **Expect** results for each kind, labelled by type.
3. Arrow keys + Enter on a result.
- [x] **Expect** the item opens.
4. Press **Esc** inside the opened item.
- [x] **Expect** you return to search and the cursor is again in the box.
5. Search for nonsense text.
- [x] **Expect** a clean "no results" state.

## 7. Files and preview [DONE]

1. Press **Alt+5**.
- [x] **Expect** a list of courses; hovering one begins loading its files.
2. Open a course, then a folder, then a subfolder.
- [x] **Expect** the breadcrumb updates; **Esc**, **Backspace** and **Alt+Left** each go up one level.
3. Click breadcrumb parts.
- [x] **Expect** it jumps to that level.
4. Hide a folder (eye icon on hover), then use "Hidden folders" to show and restore it.
- [x] **Expect** Undo toast works; hidden state survives restart.
5. Hide a course from Files.
- [x] **Expect** it moves into "Hidden courses" and returns when restored.
6. Click a PDF, an image, a text file, and a type that cannot be previewed (e.g. .zip).
- [x] **Expect** previewable files open in the viewer; others download with a toast.
7. In the PDF viewer scroll, zoom and page through.
- [x] **Expect** smooth movement, no blank pages.
8. Use the download icon on a row.
- [x] **Expect** "Saved to Downloads". Download the same file twice.
- [x] **Expect** the second copy gets a unique name, nothing overwritten.

## 8. Offline cache [DONE]

1. Open a PDF preview, close it, open it again.
- [x] **Expect** the second open is instant (no download wait).
2. Go back to the folder list.
- [x] **Expect** that file's row now says "· Offline".
3. Click **Save offline** on a folder with several files.
- [x] **Expect** a toast "Saving X of Y for offline…" with a **Stop** button; rows turn "Offline" as they finish.
4. Click **Stop** midway.
- [x] **Expect** "Stopped. Saved N files…" (up to 3 in-flight files still finish). Click Save offline again: it continues with the rest.
5. Click Save offline twice quickly.
- [x] **Expect** a message that it is already saving, no second batch.
6. Click Save offline when everything is saved.
- [x] **Expect** "Everything here is already saved offline."
7. Open `%APPDATA%\EtherLex\files\<your-canvas-host>\`.
- [x] **Expect** files named `<id>_<version>_<name>` and no leftover `.part` files after everything finished.
8. **Go offline** (disconnect Wi-Fi or disable the network adapter). Restart the app.
- [x] **Expect** assignments and other lists still show cached data.
9. Open Files → a course you visited before.
- [x] **Expect** the listing appears with an "Offline copy" label; saved files open fine; unsaved ones fail with a clear message (not a crash).
10. Open a course you never visited while offline.
- [x] **Expect** a clear error with a Retry button.
11. Reconnect and press refresh.
- [x] **Expect** the "Offline copy" label disappears and data is live.
12. In the course list, find the **Offline files** row at the bottom and click it.
- [x] **Expect** "Offline files cleared", the row disappears, and "· Offline" tags are gone. The `files` folder is empty.
13. Update check: replace a file on Canvas (new upload with the same name), then refresh and open it.
- [x] **Expect** the new content opens, and only one copy of that file remains in the cache folder.

## 9. Notifications [DONE]

1. Toggle notifications (avatar menu, Settings, or Ctrl+K, then "notifications").
- [x] **Expect** it toggles on/off and the state survives restart.
2. With it on and an assignment due within the next day or three, restart the app.
- [x] **Expect** a Windows notification for the deadline.
3. Restart again.
- [x] **Expect** the same alert does **not** fire a second time.
4. When a new grade is posted (or after a grade appeared in the last 3 days).
- [x] **Expect** a grade notification, grouped if there are many (never a flood; at most 3 at a time).
5. Switch the bell off and restart.
- [x] **Expect** no notifications.

## 10. Per-account settings

1. In account A set: disable one course, hide one folder, add a grade plan, switch the bell off.
2. Sign out, sign in to account B (a different user, ideally on the **same** Canvas site) or sample mode.
- [x] **Expect** none of A's settings appear (course list, hidden folders, grade plans, bell state all fresh).
3. Make a different change in B, sign out, sign back into A.
- [x] **Expect** A's settings are back and B's changes are not in A.
4. Open `%APPDATA%\EtherLex\settings\`.
- [x] **Expect** one `<host>_u<user id>.json` per account (a different file for each person, even on the same site). (`settings.json.migrated` sits one folder up, in `%APPDATA%\EtherLex\`, and only exists if you ever had the very old single `settings.json`.)
5. With A and B on the same site: sign in as A, wait for the sync, sign out, sign in as B right away (before it finishes).
- [x] **Expect** no course, assignment, grade, file or chat of A is ever visible while signed in as B, not even for a moment. Signing out and in again never deletes anything.
6. Save an AI key as A. Sign out, sign in as B, open Settings and the Assistant.
- [x] **Expect** B has no key ("Add an API key to start"); A's key and provider are back when you sign in as A again.

## 11. Robustness [DONE]

1. Turn the network off while on the Assignments page and press refresh.
- [x] **Expect** a calm error or "offline" note; cached data stays visible.
2. Put the wrong token in (revoke it in Canvas) and refresh.
- [x] **Expect** the refresh button says "Token rejected" (hover shows the reason) and a red bar under the title bar offers **Sign in again**, which takes you to the connect screen. The cached data stays visible until then. A refresh that works clears the bar.
3. Resize the window from very small to maximised.
- [x] **Expect** no overflow stripes (yellow/black); layout adapts.
4. Leave the app running 30 minutes in the background, then use it.
- [x] **Expect** it still responds, memory stays reasonable (Task Manager, less than about 500 MB).
5. Click everything quickly (open/close dialogs, switch tabs with Alt+1..6 rapidly).
- [x] **Expect** no crash, no stuck spinner.

## 12. Performance feel (profile build) [DONE]

1. Press **F9** and scroll Assignments, Activity and Files with long lists.
- [x] **Expect** steady frames, no long red spikes.
2. Open and close a dialog 10 times.
- [x] **Expect** it opens without a visible hitch.
3. Switch tabs rapidly.
- [x] **Expect** instant switching, no flash of empty content when data is cached.

## 13. Release build and installer [DONE]

1. `flutter build windows --release`
- [x] **Expect** it builds with no errors.
2. Run `build\windows\x64\runner\Release\etherlex.exe` directly.
- [x] **Expect** the app starts; sign-in persists; notifications work.
3. Install Inno Setup 6 and run `ISCC.exe /DAppVersion=0.1.0 installer\etherlex.iss`.
- [x] **Expect** `installer\Output\EtherLex-Setup-0.1.0.exe`.
4. Run the installer on a clean user (or another PC without Flutter).
- [x] **Expect** it installs without admin rights, creates a Start menu entry, and the app starts.
5. Uninstall from Windows Settings → Apps.
- [x] **Expect** the program is removed. (Your data in `%APPDATA%\EtherLex` stays by design; delete it by hand to fully reset.)
6. Push a tag like `v0.1.0` to GitHub.
- [x] **Expect** the Release workflow attaches the installer to a release; the CI workflow is green on every push.
7. Download the installer from the GitHub release on a PC that has never run EtherLex, and open it.
- [ ] **Expect** "Windows protected your PC"; More info, then Run anyway installs it (as the README says). `Get-FileHash` matches the `.sha256` file on the release page.

8. With the installed EtherLex open (minimise it), start it again from the Start menu.
- [ ] **Expect** no second window: the open one comes back to the front. A `flutter run` build can still run next to the installed app.

## 14. Look and feel (redesign) [DONE]

1. Settings > Appearance → Theme cards: Light, Dark, Match Windows; and the sun/moon button in the title bar.
- [x] **Expect** every screen, dialog, menu and toast reads well in both themes; the choice survives restart.
2. Settings → Font: Handwritten and Clean.
- [x] **Expect** the whole UI switches; document previews always use the clean font.
3. Narrow the window below about 1080 px, then below 860 px.
- [x] **Expect** the sidebar becomes a floating icon rail; details panes become dialogs; the Calendar becomes a day list.
4. Title bar: drag empty space, double-click it, right-click it, use minimise/maximise/close; hover maximise on Windows 11; resize from the top edge and the top corners; drag a maximised window down from the title bar.
- [x] **Expect** normal window behaviour, the window menu on right-click, and the Snap Layouts flyout on hover (the maximise button highlights while hovered and pressed).
- [x] **Expect** resizing stays smooth: with F9 on, the top (raster) graph stays mostly green while you drag a corner.
5. Ctrl+K: type "dark", a course name, and part of an assignment title.
- [x] **Expect** matching commands first, then assignments and announcements; Enter runs or opens; Esc closes.
6. Ctrl+/ and Ctrl+,
- [x] **Expect** the shortcuts window (filterable) and Settings.
7. Keyboard only: Tab through the title bar and dialogs.
- [x] **Expect** a violet focus ring on whatever has focus (never after a mouse click).

## 14b. Settings window

1. Ctrl+, then click through every section in the sidebar.
- [x] **Expect** a wide window with the sections on the left and rounded rows on the right (title, one line under it, control on the right). Every setting from before is somewhere. The search box has the cursor.
2. Type "dark", then "key", then "update", then "refresh", then a course name, then "zzz".
- [x] **Expect** results grouped by section with the words marked; the controls work right in the results. "refresh" finds the shortcut; "zzz" says nothing matches. Enter jumps to the first result's section. Clicking a group title opens that section.
3. Appearance > Reset to defaults (after changing theme, accent and font); also Courses, Notifications, Assistant, Updates.
- [x] **Expect** a question saying what will be reset, then a toast. The Assistant reset keeps your key, server address and permission. Sections without choices (Account, Files, Shortcuts, About) have no Reset.
4. Close and press Ctrl+, again; in the Assistant with no key, press "Open settings".
- [x] **Expect** it opens on the section you used last; "Open settings" opens Assistant directly.
5. Make the window narrow (about 800 px).
- [x] **Expect** the sidebar shrinks to icons with tooltips; everything still works.
6. Settings > Appearance: click each Theme card, both Font cards, each Background card (Dots, Grid, Plain), in light and dark. Then Ctrl+K, type "grid" and "accent blue". Open the avatar menu. Open Settings > Assistant in a narrow window.
- [x] **Expect** the chosen card has an accent border; the font cards show a sample in their own font; the background changes at once everywhere (sign-in screen too) and survives a restart. Ctrl+K offers "Background: Grid" and "Accent colour: Blue". The avatar menu has no theme or font items any more. The AI service switcher never overflows (it shrinks to fit).

## 14c. Sidebar tools and collapse

1. Wide window: look at the bottom of the sidebar; hover each tool, then click Settings, Shortcuts, Help and the sun/moon.
- [x] **Expect** a hairline and a row of icons: Settings, Keyboard shortcuts, Help and feedback on the left; theme and collapse on the right. Tooltips name them with their shortcut. Help opens Settings on Help & About. The title bar no longer has the sun/moon.
2. Press Ctrl+B (or the collapse button), then restart EtherLex, then Ctrl+B again.
- [x] **Expect** the icon rail in the wide window, with a small second pill at the bottom (Settings, theme, expand); it survives a restart; Ctrl+B brings the sidebar back. In a narrow window the rail's pill has no expand button.
3. Open the avatar menu.
- [x] **Expect** your name and Canvas, Account settings (opens Settings on Account) and Sign out only.

## 14d. Pages remember how you left them

1. Assignments: Starred, unfold "Done earlier". Activity: Grades filter. Grades: unfold "No grades yet". Files: open a course and a folder inside it. Go to another page and back to each. In Files, change folder twice more with a page switch in between.
- [x] **Expect** each page is exactly as you left it.
2. Restart EtherLex and visit the same pages.
- [x] **Expect** the same again; Files opens straight in that folder (a folder that no longer exists shows the course root instead). Calendar opens on this week.
3. Sign in with the other account (or sample data).
- [x] **Expect** that account has its own choices (the defaults the first time).

## 14e. Ctrl+K finds everything

1. Open a course in Files once (so its listing is saved). Ctrl+K, type part of a file name from it, then Enter.
- [x] **Expect** a Files section with the file (course on the right); Enter opens Files on its folder with the file selected. Files in hidden folders or hidden courses are not listed.
2. Ctrl+K: type a word from one of your assistant conversations (also one that appears only in a later message or in an answer), then Enter.
- [x] **Expect** a Conversations section (title hits first; others say "In messages"); Enter opens the Assistant on that conversation, scrolled to the message with those words, which is ringed for a moment (also in a long chat, far from the end).
3. Ctrl+K: type "key", then "notifications", then Enter on a result.
- [x] **Expect** a Settings section; Enter opens Settings with the search already typed and the row marked.
4. Ctrl+K: type a course name.
- [x] **Expect** "<course> files" (Open in Files) besides the filter command; Enter opens Files on that course.
5. Ctrl+F with the same words.
- [x] **Expect** files and conversations too, but no settings or commands.

## 14f. Keyboard

1. From Assignments press Ctrl+N; type something, then Ctrl+N again.
- [ ] **Expect** the Assistant opens on a new, empty chat each time.
2. Files: in the course list and inside a course, press Ctrl+R and F5.
- [x] **Expect** the refresh button spins and the list reloads.
3. Hover a sidebar item, the refresh button, the calendar arrows and Today, and New chat.
- [x] **Expect** tooltips with the shortcut: "Alt+1", "Refresh  Ctrl+R", "Previous week  ←", "This week  T", "New chat  Ctrl+N". In the icon rail: "Assignments  Alt+1".
4. Ctrl+/ and read the list.
- [x] **Expect** every line does what it says (R: mark done or not done; Ctrl+N; F5 on its own line).

## 15. AI assistant (needs your own API key)

1. Sample mode: open **Assistant** (Alt+6) and send "hello".
- [x] **Expect** your message on the right, "Thinking..." and then a canned answer that appears piece by piece. Copy puts the answer on the clipboard; "Answer again" replaces it.
2. Real account with no key: open **Assistant**.
- [x] **Expect** "Add an API key to start" with an Open settings button that opens Settings.
3. Settings, AI assistant: pick Anthropic, paste a key, Save. Open **Assistant** and ask a question.
- [x] **Expect** a streamed answer with Markdown (lists, bold, code blocks) shown properly. Settings says the key is saved and never shows it again. Remove key brings the empty state back.
4. Press Shift+Enter in the box, then Enter.
- [x] **Expect** a new line, then the message is sent. While an answer is coming, the send button becomes Stop and keeps what arrived.
5. Enter a wrong key and ask something.
- [x] **Expect** a red banner "The API key was not accepted" with a Settings button. Turn Wi-Fi off and ask: "offline" banner with Retry; Retry works once Wi-Fi is back.
6. New chat, ask something else, then History.
- [x] **Expect** both chats listed newest first; clicking one opens it; the bin deletes it. Restart the app: chats are still there.
7. Settings, OpenAI-compatible: type a model name and the base URL of your service, Save.
- [x] **Expect** answers stream from that service. Your key is not in `%APPDATA%/EtherLex` (it is in the Windows credential store).
8. Settings, DeepSeek: paste a DeepSeek key, Save, ask something. (For the thinking model type `deepseek-reasoner` as the model.)
- [x] **Expect** answers stream from DeepSeek. Switching back to Anthropic keeps each provider's key and model.
9. Ask: "Show me every Markdown feature: bold, italic, ~~strike~~, inline code, a nested list, a task list, a table, a quote, a horizontal rule, a link and a Python and a diff code block."
- [x] **Expect** strikethrough and combined styles render, task lists show check boxes, the table has a header and alignment, the rule is a thin line, links are clickable and open in the browser, code blocks have a language label and coloured syntax (diff lines green/red), long code scrolls sideways.
10. Ask for an image in Markdown, e.g. "reply with exactly this line: `![demo](https://httpbin.org/image/png)`".
- [x] **Expect** a placeholder saying "Loads from <host>"; the image loads only after you click it.
11. Click Copy under an answer and on a code block.
- [x] **Expect** the icon turns into a green check with a small scale/fade animation, and back after about a second and a half. The pasted text is right.
12. Attach: in the Assistant click the paperclip, pick **Open assignments**, then ask "What should I do first?".
- [x] **Expect** a "Send Canvas data to <service>?" dialog the first time; after Allow, a chip "Open assignments (n)" above the box, "Loading from Canvas..." while it fetches. The answer uses your real due dates, and the sent message shows "Attached: Open assignments (n)". Courses you disabled are not in the list.
13. Pick **Grades overview** before ever opening the Grades page, then **Grades of one course**.
- [x] **Expect** both load (a short "Loading from Canvas..."), every course is listed, and a course without a grade says "no grade yet". Remove a chip with its x: it is not sent.
14. (You cannot ask the AI without internet anyway; this only checks that a failed fetch for an attachment is handled.) Turn Wi-Fi off, pick **Grades of one course** for a course you have not opened.
- [x] **Expect** an error banner about the connection with Retry. Retry repeats the fetch (never re-asks your last question); dismiss with the x.
15. Settings, AI assistant: click "Take permission back", then attach something again.
- [x] **Expect** the permission dialog appears again. Sign in as another account: it also asks again.
16. Attach a file: paperclip, then under **A file or picture from a course** pick a course with a syllabus (PDF or Word), choose it, ask "Summarise this syllabus and list the grading weights".
- [x] **Expect** the course's folders like on the Files page (click a folder to go in, Back to go out), and typing in the search box finds files by name anywhere in the course. Files that cannot be read (for example .xlsx or .mp4) or are too big (pictures over 5 MB, documents over 25 MB) are greyed out with the reason, and clicking them does nothing, so nothing is downloaded. A chosen file gives a chip with its name and an answer that uses its real content; same for a PowerPoint and a Markdown/text file. A very long file (over about 80,000 characters, roughly 40 pages of text) is cut and its chip says "(first part)". Next to it is "Send whole file" (hover shows the size): click it and the chip says "(whole file)", and the answer can use the end of the file too. Even then, files over about 400,000 characters are cut. Typing starts in the search box immediately when the list opens. A file with no text at all (a scan) gives "Could not find any text in ..." with no Retry button.
17. Attach a picture with Anthropic or an OpenAI service that reads images: paperclip, **A file or picture from this computer**, choose a PNG or JPEG (for example a screenshot of a graph), ask "What does this show?".
- [ ] **Expect** the chip with the picture's name and an answer that describes the picture. A picture over 5 MB is refused with a message. Ask a second question in the same chat: the picture is still known while the app stays open (after a restart only the chip label remains).
18. Settings, AI assistant: choose DeepSeek, go back and attach a picture.
- [x] **Expect** "DeepSeek cannot read pictures yet..." and no chip. Attach a picture first, then switch to DeepSeek in Settings and press send: the same message appears and nothing is sent. Text files still work with DeepSeek.
19. Attach a syllabus of one course (course file or from your computer) and ask: "Set up my grade plan for this course from the syllabus."
- [x] **Expect** a short explanation and, under it, a card "Proposed grade plan" with the course, each category with its weight (and "n items" if the syllabus gives counts), a tag per category (Canvas category, Your category, New category, or "Not in the plan: set to 0%" for a Canvas category the syllabus does not mention) and, if the syllabus has one, the letter curve. If the weights do not add up to 100 a yellow note says so. Nothing in the Grades page has changed yet.
20. Press **Apply to <course>**.
- [x] **Expect** the card changes to "Applied to <course>" with Undo and Open planner. Open planner: the weights, item counts and curve are there, and your own categories were created for what Canvas does not have. Pressing Undo (or Open planner and checking) shows the plan exactly as it was before.
21. Ask for the same plan again and apply it twice.
- [x] **Expect** no duplicate categories are created. If the course cannot be told from the answer, the card shows "Choose course" and Apply stays off until you pick one.
22. Ask something that is not about the grade plan, e.g. "show me the JSON of a Python dict in a code block".
- [x] **Expect** a normal code block, no card.
23. Attach **Open assignments**, then ask: "Star the two assignments due soonest."
- [x] **Expect** a "Proposed changes" card listing exactly those assignments (title and course) with "Star", and "Apply 2 changes". Nothing is starred yet. Press Apply: they are starred in the Assignments list; the card says "Applied 2 changes" with Undo; Undo un-stars them.
24. Ask: "Mark <an assignment you really finished> as done."
- [x] **Expect** the card shows "Mark done" in a warm colour with "Marking done only changes EtherLex. Nothing is submitted to Canvas." Apply asks "Mark 1 assignment as done?" once more; after confirming it is done in the list, nothing was sent to Canvas, and Undo brings it back.
25. Ask the assistant to star something that was not attached (e.g. "star my chemistry homework" with only physics attached).
- [x] **Expect** it says it needs that assignment attached instead of guessing, or its card marks unknown ones "not found, skipped". Asking it to submit something: it says it cannot.
26. Attach the syllabus **and** **Grades of one course** for the same course, then ask for the plan again, and for assignments to be moved to match the syllabus's categories (e.g. fold "Lab Report" into "Lab").
- [x] **Expect** the plan card has a "Moves between categories" list with titles; Apply moves them (check in the planner); unknown ones are marked skipped; Undo restores the plan.
27. Ask: "Switch to the dark theme and the clean font, and turn notifications off."
- [x] **Expect** a "Proposed changes" card with Theme, Font and Notifications lines (a line that is already so says "already so"). Nothing changes until Apply; after Apply the app looks different; Undo puts the theme, font and notifications back.
28. Ask: "Hide <one of your courses>", then "show it again". Also try a vague name that fits two courses (e.g. "hide physics" when you have two).
- [x] **Expect** Apply asks "Hide 1 course?" first; the course leaves the lists; Undo or "show it again" brings it back. A vague name is shown as "no single course matches" with a "Choose course" button: pick one and the line becomes a change; nothing is ever guessed. A typo ("Discrete Mathmatics") still finds its course. When some lines would be skipped, the card says "N will be skipped" and Apply still does the rest (try "dark theme, and hide X" when the theme is already dark).
- [x] Without attaching anything, ask "hide my math courses" (after you have allowed sending Canvas data once): the assistant proposes one line per math course, using your exact course names.
- [x] Ask "hide a course" without saying which: the card has a line "Which course?" with a "Choose course" button; picking one turns it into a change.
- [x] Ask "show me my courses": a card lists the real courses, each marked Shown or Hidden. Tap two Shown marks (they turn into "Will hide"), press Apply (it asks before hiding), then Undo. Try "which courses are hidden?" too: only the hidden ones are listed.
29. Ask: "Take me to my grades."
- [x] **Expect** a card with "Open Grades"; Apply goes to the Grades page.
30. Attach a syllabus that has no grade curve and ask for a grade plan, then ask "also guess how the class is usually distributed".
- [x] **Expect** the plan card shows the curve in a warm colour as "(a guess, not from your documents)" with the line "Guesses are estimates, not facts", and the assistant's text says it is a guess. Weights and categories are still only what the syllabus says.
31. Ask: "Hide the <a folder name> folder in <course>", then "show it again".
- [x] **Expect** a card with "Hide folder" and the course and folder; Apply hides it in the Files tab; Undo hiding (or asking to show it) brings it back. A folder name that fits two folders is skipped ("no single folder matches"), never guessed.
32. Ask: "Save <a folder> of <course> for offline use", and "save the whole <course> offline".
- [x] **Expect** a card showing how many files and how much; Apply asks "Get N files (size)?" first, then the progress message (with Stop) appears and the files open without Canvas. Asking again shows "already saved".
33. Ask: "Download the syllabus of <course>".
- [x] **Expect** a card with Download and the file name and size; Apply asks once, then the file lands in Downloads. A name that fits several files is skipped.
34. Attach your open assignments and ask: "Help me hand in <an assignment that takes uploads>".
- [x] **Expect** a "Hand in an assignment" card with the title, the accepted file types and "Choose files". Nothing can be sent until you choose files yourself; a wrong file type is refused with the allowed ones. "Submit N files" opens a dialog naming the assignment, course and every file (and warning when late). Cancel sends nothing; "Submit to Canvas" uploads, marks it done and shows the toast. A locked assignment or one without uploads shows why instead.
35. Ask the assistant to "submit it for me" with a file path in the message.
- [x] **Expect** it never claims it submitted; any card still needs your file choice and the dialog.
36. Without attaching anything, ask: "Hide the TA folder in <course>" (a folder that exists once).
- [x] **Expect** a card "Needs to look at your files" for that course, with Not now / Allow. Allow sends a short message with the file list attached (a chip shows it), and the assistant answers with the Hide folder card for the exact folder. Not now sends nothing.
37. Ask the same for a folder name that exists twice, then for one that does not exist.
- [x] **Expect** it asks which one, or says there is no such folder; it never hides a guess.
38. Ask: "Hide the whole <course> folder in Files, not something inside", then "show it again".
- [x] **Expect** a card "Hide in Files" with the course; Apply hides it in the Files tab only (the course stays everywhere else); Undo hiding or "show it again" brings it back.
39. Ask to download a file whose name exists in two folders of a course.
- [x] **Expect** the card says "2 files match" with a Choose button listing both (with their folders and sizes); picking one makes the line a normal download of that file. Same for a folder name that fits two folders, and for a course that does not match (it offers the likely courses).
40. In a long chat scroll up a little.
- [x] **Expect** a round arrow-down button appears at the bottom right of the messages; pressing it jumps to the newest message and it disappears. While an answer is being written, scrolled up stays where you are (it does not pull you down); sending a message always goes to the end.
41. Ask in one message: "Star <an assignment>, hide the TA folder in <course A>, and download the syllabus of <course B>" (with the open assignments attached).
- [x] **Expect** one answer with several cards at once (actions, plus either file cards or one "Needs to look at your files" card listing both courses), not one step per message. Saying "one at a time" makes it go step by step.
42. Scroll up, then press the arrow-down button.
- [x] **Expect** the button fades and slides in when you scroll up, glides the chat down to the end when pressed, and fades out.
43. Without attaching anything, ask: "Download the <course A> syllabus, star <an assignment> of <course B>, and make the grade plan for <course C> from its syllabus".
- [x] **Expect** one "Needs to look at some of your data" card listing: File list (course A), Assignments (course B) and Read file (course C, syllabus). One Allow loads and sends all of it (a file that fits two names asks which first). The next answer has the download card, the star card and the grade plan card together. Nothing is asked to be attached or pasted by hand.
44a. Download a Word file from Files and open it from the toast; then put a `.html` file in a course (or use one that exists) and press Open in its preview.
- [x] **Expect** Word opens the document in Protected View ("Enable Editing" bar). The .html asks "Open this web page?" first; Cancel does nothing. A `.exe` or `.appref-ms` is only shown in its folder. In Explorer, the downloaded file's Properties shows "This file came from another computer".
44b. Settings > AI assistant > OpenAI-compatible: type `http://example.com/v1` in Server address, then `https://api.example.com/v1`, with a key saved; Save. Then attach something in the Assistant.
- [x] **Expect** the http address shows a red line under the field and Save does nothing. The https one asks "Send your API key to api.example.com?" (Cancel puts the old address back). After Use, attaching asks "Send Canvas data to OpenAI-compatible (api.example.com)?" again, even if you allowed the old server. Anthropic and DeepSeek permissions are unchanged.
44c. In light and in dark, and with two accent colours: look at row details (due times, counts, "Updated 11:19"), Settings descriptions, a primary button, the Sign out confirm button and today's date in Calendar.
- [x] **Expect** the quiet grey text is easy to read but still clearly quieter than normal text; button text is crisp white on a solid colour in dark mode too. The app still looks like EtherLex.
44. Settings > About > Diagnostics > Copy, then paste into Notepad.
- [x] **Expect** a toast "Diagnostics copied" and a few lines: version, Windows, Dart, mode, look, AI service chosen, notifications, update check. No token, key, name, Canvas address or course names.
45. Settings > About > Feedback > Send feedback.
- [x] **Expect** your browser opens a new issue on 0xsenmrx/EtherLex with a short template and the same diagnostics inside a collapsed block. Nothing is sent until you press Submit.
46. Settings > Appearance > Colour: click each of the five dots (violet, blue, green, rose, orange), in light and in dark.
- [x] **Expect** the accent changes at once everywhere (buttons, links, selection, switches, focus rings) and the chosen dot has a ring; backgrounds and text stay the same. Close and reopen EtherLex: the colour is kept. Hovering a dot shows its name. White text on buttons stays readable in every colour.
