#ifndef RUNNER_WINDOW_PLACEMENT_H_
#define RUNNER_WINDOW_PLACEMENT_H_

#include <windows.h>

// Remembers the window's size, position and maximised state between runs in
// %APPDATA%\EtherLex\window.txt (one line: version, left, top, right, bottom
// in physical screen pixels, maximised 0/1). It belongs to this computer's
// screens, not to a Canvas account.
class WindowPlacement {
 public:
  // Call after the window is created and before it is shown. Moves it to the
  // saved rectangle, fitted into the work area of the nearest monitor (so a
  // window left on an unplugged screen comes back on a visible one). Returns
  // false when nothing usable was saved; the window then keeps its default.
  bool Restore(HWND window);

  // After Restore: whether the window was maximised when it was closed.
  bool maximized() const { return maximized_; }

  // Call on WM_WINDOWPOSCHANGED: keeps the last normal (not maximised, not
  // minimised) rectangle, which is what Windows restores to.
  void Track(HWND window);

  // Call on WM_CLOSE and WM_ENDSESSION. Failures are ignored: the next start
  // simply uses the default size.
  void Save(HWND window) const;

 private:
  RECT normal_{};
  bool has_normal_ = false;
  bool maximized_ = false;
};

// |rect| moved and, if needed, shrunk so it lies entirely inside |work|.
RECT FitInto(const RECT& rect, const RECT& work);

#endif  // RUNNER_WINDOW_PLACEMENT_H_
