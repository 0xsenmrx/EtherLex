#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  // Apply the custom frame (WM_NCCALCSIZE) before measuring the client area.
  SetWindowPos(GetHandle(), nullptr, 0, 0, 0, 0,
               SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                   SWP_NOACTIVATE);

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());
  frame_.Attach(GetHandle(), flutter_controller_->view()->GetNativeWindow(),
                flutter_controller_->engine()->messenger());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  frame_.Detach();
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  const LRESULT result = HandleMessage(hwnd, message, wparam, lparam);
  LogWindowMessage("window", message, wparam, lparam, result);
  return result;
}

LRESULT
FlutterWindow::HandleMessage(HWND hwnd, UINT const message,
                             WPARAM const wparam,
                             LPARAM const lparam) noexcept {
  // Alt+<key> shortcuts must not make Windows play its menu beep.
  // Alt+Space still opens the system menu.
  if (message == WM_MENUCHAR) {
    return MAKELRESULT(0, MNC_CLOSE);
  }
  if (message == WM_SYSCHAR && wparam != VK_SPACE) {
    return 0;
  }

  // Remember where the window is; save it when EtherLex closes or Windows
  // signs out. The messages then continue as usual.
  switch (message) {
    case WM_WINDOWPOSCHANGED:
      placement_.Track(hwnd);
      break;
    case WM_CLOSE:
      placement_.Save(hwnd);
      break;
    case WM_ENDSESSION:
      if (wparam) {
        placement_.Save(hwnd);
      }
      break;
  }

  // The custom title bar (caption removal, hit testing, Snap Layouts).
  if (std::optional<LRESULT> handled =
          frame_.HandleMessage(hwnd, message, wparam, lparam)) {
    return *handled;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
