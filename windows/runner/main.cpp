#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include <algorithm>
#include <cwchar>
#include <functional>
#include <string>

#include "flutter_window.h"
#include "utils.h"

namespace {

// Lower-case full path of this program, so two copies of the same install
// recognise each other and a dev build next to the installed app does not.
std::wstring ProgramPath() {
  wchar_t buffer[MAX_PATH * 2];
  const DWORD length = ::GetModuleFileNameW(nullptr, buffer, static_cast<DWORD>(_countof(buffer)));
  std::wstring path(buffer, length);
  ::CharLowerBuffW(path.data(), static_cast<DWORD>(path.size()));
  return path;
}

struct WindowSearch {
  std::wstring path;
  HWND found = nullptr;
};

// EnumWindows callback: a runner window owned by a process started from the
// same program file.
BOOL CALLBACK FindOwnWindow(HWND hwnd, LPARAM lparam) {
  auto* search = reinterpret_cast<WindowSearch*>(lparam);
  wchar_t class_name[64];
  if (::GetClassNameW(hwnd, class_name, static_cast<int>(_countof(class_name))) == 0 ||
      wcscmp(class_name, L"FLUTTER_RUNNER_WIN32_WINDOW") != 0) {
    return TRUE;
  }
  DWORD pid = 0;
  ::GetWindowThreadProcessId(hwnd, &pid);
  HANDLE process = ::OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
  if (process == nullptr) {
    return TRUE;
  }
  wchar_t buffer[MAX_PATH * 2];
  DWORD size = static_cast<DWORD>(_countof(buffer));
  bool same = false;
  if (::QueryFullProcessImageNameW(process, 0, buffer, &size)) {
    std::wstring other(buffer, size);
    ::CharLowerBuffW(other.data(), static_cast<DWORD>(other.size()));
    same = other == search->path;
  }
  ::CloseHandle(process);
  if (!same) {
    return TRUE;
  }
  search->found = hwnd;
  return FALSE;
}

// Two EtherLex processes would write the same database and settings files.
// Returns false when a copy of the same program already runs: its window is
// brought forward and this one should quit. Otherwise [mutex] holds the mutex
// that marks this copy as the running one (null if Windows could not make
// one; then we run anyway). It lives in the user's session (no "Global"
// prefix), so other Windows users are not affected.
bool ClaimSingleInstance(HANDLE* mutex) {
  const std::wstring path = ProgramPath();
  wchar_t name[96];
  swprintf_s(name, L"EtherLex.SingleInstance.%llx",
             static_cast<unsigned long long>(std::hash<std::wstring>{}(path)));
  *mutex = ::CreateMutexW(nullptr, FALSE, name);
  if (*mutex == nullptr || ::GetLastError() != ERROR_ALREADY_EXISTS) {
    return true;
  }
  ::CloseHandle(*mutex);
  *mutex = nullptr;
  WindowSearch search{path};
  ::EnumWindows(FindOwnWindow, reinterpret_cast<LPARAM>(&search));
  if (search.found != nullptr) {
    if (::IsIconic(search.found)) {
      ::ShowWindow(search.found, SW_RESTORE);
    }
    ::SetForegroundWindow(search.found);
  }
  return false;
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE single_instance = nullptr;
  if (!ClaimSingleInstance(&single_instance)) {
    return EXIT_SUCCESS;
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  // Skia, not Impeller: on Windows, Impeller (the default since Flutter 3.47)
  // makes live window resizing visibly laggy, and Skia resizes smoothly.
  // Flutter plans to remove this opt-out in a future release; test resizing
  // with Impeller again after each Flutter upgrade.
  project.set_impeller_switch(flutter::ImpellerSwitch::Disabled);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // First start: centred in the primary monitor's work area, 1360x860 when it
  // fits. Later starts move it to the remembered place below.
  RECT work{};
  SystemParametersInfo(SPI_GETWORKAREA, 0, &work, 0);
  const double scale =
      FlutterDesktopGetDpiForMonitor(
          MonitorFromPoint(POINT{0, 0}, MONITOR_DEFAULTTOPRIMARY)) /
      96.0;
  const int work_width = static_cast<int>((work.right - work.left) / scale);
  const int work_height = static_cast<int>((work.bottom - work.top) / scale);
  const int width = std::max(760, std::min(1360, work_width - 48));
  const int height = std::max(540, std::min(860, work_height - 48));
  const int left = static_cast<int>(work.left / scale) +
                   std::max(0, (work_width - width) / 2);
  const int top = static_cast<int>(work.top / scale) +
                  std::max(0, (work_height - height) / 2);
  Win32Window::Point origin(static_cast<unsigned int>(std::max(0, left)),
                            static_cast<unsigned int>(std::max(0, top)));
  Win32Window::Size size(static_cast<unsigned int>(width),
                         static_cast<unsigned int>(height));
  if (!window.Create(L"EtherLex", origin, size)) {
    return EXIT_FAILURE;
  }
  // Reopen where it was left (fitted to a screen that still exists).
  if (window.placement().Restore(window.GetHandle())) {
    window.SetShowMaximized(window.placement().maximized());
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  if (single_instance != nullptr) {
    ::CloseHandle(single_instance);
  }
  return EXIT_SUCCESS;
}
