#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter_windows.h>
#include <windows.h>

#include <algorithm>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
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
  // Open centred in the primary monitor's work area, 1360x860 when it fits.
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
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
