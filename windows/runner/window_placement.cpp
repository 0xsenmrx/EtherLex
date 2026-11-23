#include "window_placement.h"

#include <algorithm>
#include <cstdio>
#include <string>

namespace {

constexpr int kVersion = 1;

// Smaller saved sizes are treated as damaged and ignored.
constexpr LONG kMinWidth = 320;
constexpr LONG kMinHeight = 240;

// The same folder the Dart side uses (lib/core/storage/app_dir.dart).
std::wstring DataFolder() {
  wchar_t buffer[MAX_PATH * 2];
  const DWORD length = ::GetEnvironmentVariableW(L"APPDATA", buffer, static_cast<DWORD>(_countof(buffer)));
  if (length == 0 || length >= _countof(buffer)) {
    return std::wstring();
  }
  return std::wstring(buffer, length) + L"\\EtherLex";
}

}  // namespace

RECT FitInto(const RECT& rect, const RECT& work) {
  const LONG width = std::min(rect.right - rect.left, work.right - work.left);
  const LONG height = std::min(rect.bottom - rect.top, work.bottom - work.top);
  const LONG left = std::clamp(rect.left, work.left, work.right - width);
  const LONG top = std::clamp(rect.top, work.top, work.bottom - height);
  return RECT{left, top, left + width, top + height};
}

bool WindowPlacement::Restore(HWND window) {
  const std::wstring folder = DataFolder();
  if (folder.empty()) {
    return false;
  }
  FILE* file = nullptr;
  if (_wfopen_s(&file, (folder + L"\\window.txt").c_str(), L"r") != 0 || file == nullptr) {
    return false;
  }
  int version = 0;
  int maximized = 0;
  RECT rect{};
  const int read = fscanf_s(file, "%d %ld %ld %ld %ld %d", &version, &rect.left, &rect.top, &rect.right,
                            &rect.bottom, &maximized);
  fclose(file);
  if (read != 6 || version != kVersion || rect.right - rect.left < kMinWidth ||
      rect.bottom - rect.top < kMinHeight) {
    return false;
  }

  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (!::GetMonitorInfoW(::MonitorFromRect(&rect, MONITOR_DEFAULTTONEAREST), &info)) {
    return false;
  }
  rect = FitInto(rect, info.rcWork);
  // Twice: moving onto a monitor with another scale makes WM_DPICHANGED
  // resize the window for that scale; the second call puts back the size
  // that was saved on that same monitor.
  for (int i = 0; i < 2; ++i) {
    ::SetWindowPos(window, nullptr, rect.left, rect.top, rect.right - rect.left, rect.bottom - rect.top,
                   SWP_NOZORDER | SWP_NOACTIVATE);
  }
  normal_ = rect;
  has_normal_ = true;
  maximized_ = maximized != 0;
  return true;
}

void WindowPlacement::Track(HWND window) {
  if (::IsIconic(window) || ::IsZoomed(window)) {
    return;
  }
  RECT rect{};
  if (::GetWindowRect(window, &rect)) {
    normal_ = rect;
    has_normal_ = true;
  }
}

void WindowPlacement::Save(HWND window) const {
  const std::wstring folder = DataFolder();
  if (!has_normal_ || folder.empty()) {
    return;
  }
  bool maximized = ::IsZoomed(window) != FALSE;
  if (::IsIconic(window)) {
    WINDOWPLACEMENT placement{};
    placement.length = sizeof(placement);
    maximized = ::GetWindowPlacement(window, &placement) && (placement.flags & WPF_RESTORETOMAXIMIZED) != 0;
  }
  ::CreateDirectoryW(folder.c_str(), nullptr);
  const std::wstring target = folder + L"\\window.txt";
  const std::wstring temp = target + L".tmp";
  FILE* file = nullptr;
  if (_wfopen_s(&file, temp.c_str(), L"w") != 0 || file == nullptr) {
    return;
  }
  fprintf(file, "%d %ld %ld %ld %ld %d\n", kVersion, normal_.left, normal_.top, normal_.right, normal_.bottom,
          maximized ? 1 : 0);
  if (fclose(file) == 0) {
    ::MoveFileExW(temp.c_str(), target.c_str(), MOVEFILE_REPLACE_EXISTING);
  }
}
