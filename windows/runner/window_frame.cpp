#include "window_frame.h"

#include <flutter/standard_method_codec.h>
#include <shlobj.h>
#include <windowsx.h>

#include <cstdint>
#include <cstdio>
#include <string>
#include <variant>

namespace {

// The single frame whose Flutter view is subclassed (EtherLex has one window).
WindowFrame* g_frame = nullptr;

constexpr int kMinWidth = 760;
constexpr int kMinHeight = 540;

double ScaleFor(HWND hwnd) { return GetDpiForWindow(hwnd) / 96.0; }

// Thickness of the sizing border. Without the caption, the top one lies inside
// our client area, so we hit-test it ourselves.
int ResizeBorder(HWND hwnd) {
  const UINT dpi = GetDpiForWindow(hwnd);
  return GetSystemMetricsForDpi(SM_CYFRAME, dpi) +
         GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
}

double ToDouble(const flutter::EncodableValue& value) {
  if (auto d = std::get_if<double>(&value)) return *d;
  if (auto i = std::get_if<int32_t>(&value)) return *i;
  if (auto l = std::get_if<int64_t>(&value)) return static_cast<double>(*l);
  return 0;
}

}  // namespace

bool DiagMessagesEnabled() {
  static const bool enabled = [] {
    wchar_t value[8] = {};
    const DWORD length =
        GetEnvironmentVariableW(L"ETHERLEX_DIAG_MESSAGES", value, 8);
    return length > 0 && length < 8 && value[0] == L'1';
  }();
  return enabled;
}

void LogWindowMessage(const char* who, UINT message, WPARAM wparam,
                      LPARAM lparam, LRESULT result) {
  if (!DiagMessagesEnabled()) return;
  static ULONGLONG last_press = 0;
  const ULONGLONG now = GetTickCount64();
  // Mouse presses in any form: buttons, pointer messages, activation.
  if (message == WM_LBUTTONDOWN || message == WM_RBUTTONDOWN ||
      message == WM_NCLBUTTONDOWN || message == 0x0246 /* WM_POINTERDOWN */ ||
      message == WM_MOUSEACTIVATE || message == WM_PARENTNOTIFY) {
    last_press = now;
  }
  if (last_press == 0 || now - last_press > 500) return;
  // Not interesting and very frequent.
  if (message == WM_PAINT || message == WM_TIMER || message == WM_MOUSEMOVE ||
      message == WM_NCMOUSEMOVE || message == 0x0245 /* WM_POINTERUPDATE */ ||
      message == WM_ERASEBKGND) {
    return;
  }
  wchar_t path[MAX_PATH * 2] = {};
  const DWORD length =
      GetModuleFileNameW(nullptr, path, static_cast<DWORD>(_countof(path)));
  if (length == 0) return;
  wchar_t* slash = wcsrchr(path, L'\\');
  if (slash == nullptr) return;
  wcscpy_s(slash + 1, _countof(path) - static_cast<size_t>(slash + 1 - path),
           L"etherlex-messages.log");
  FILE* file = nullptr;
  if (_wfopen_s(&file, path, L"a") != 0 || file == nullptr) return;
  fprintf(file, "%llu %-7s msg=0x%04X w=0x%llX l=0x%llX -> 0x%llX\n",
          static_cast<unsigned long long>(now), who, message,
          static_cast<unsigned long long>(wparam),
          static_cast<unsigned long long>(lparam),
          static_cast<unsigned long long>(result));
  fclose(file);
}

WindowFrame::~WindowFrame() { Detach(); }

// static
bool WindowFrame::CustomFrameEnabled() {
  static const bool enabled = [] {
    wchar_t value[8] = {};
    const DWORD length =
        GetEnvironmentVariableW(L"ETHERLEX_NATIVE_FRAME", value, 8);
    return !(length > 0 && length < 8 && value[0] == L'1');
  }();
  return enabled;
}

void WindowFrame::Attach(HWND window, HWND content,
                         flutter::BinaryMessenger* messenger) {
  window_ = window;
  content_ = content;
  channel_ = std::make_unique<Channel>(
      messenger, "etherlex/window",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleCall(call, std::move(result));
      });

  if ((CustomFrameEnabled() || DiagMessagesEnabled()) && content_ != nullptr) {
    // The Flutter view covers the whole client area, so it receives
    // WM_NCHITTEST first. It must step aside (HTTRANSPARENT) on the top resize
    // edge and the maximise button so the frame window can answer.
    g_frame = this;
    content_proc_ = reinterpret_cast<WNDPROC>(SetWindowLongPtr(
        content_, GWLP_WNDPROC, reinterpret_cast<LONG_PTR>(ContentProc)));
  }
}

void WindowFrame::Detach() {
  if (content_ != nullptr && content_proc_ != nullptr) {
    SetWindowLongPtr(content_, GWLP_WNDPROC,
                     reinterpret_cast<LONG_PTR>(content_proc_));
  }
  if (g_frame == this) g_frame = nullptr;
  content_proc_ = nullptr;
  content_ = nullptr;
  channel_ = nullptr;
}

// static
LRESULT CALLBACK WindowFrame::ContentProc(HWND hwnd, UINT message,
                                          WPARAM wparam, LPARAM lparam) {
  const LRESULT result = ContentProcImpl(hwnd, message, wparam, lparam);
  LogWindowMessage("content", message, wparam, lparam, result);
  return result;
}

// static
LRESULT WindowFrame::ContentProcImpl(HWND hwnd, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
  WindowFrame* frame = g_frame;
  if (frame == nullptr || frame->content_proc_ == nullptr) {
    return DefWindowProc(hwnd, message, wparam, lparam);
  }
  if (message == WM_NCHITTEST && frame->window_ != nullptr &&
      CustomFrameEnabled()) {
    POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
    ScreenToClient(frame->window_, &point);
    if (frame->HitTestClient(frame->window_, point) != HTCLIENT) {
      return HTTRANSPARENT;
    }
  }
  return CallWindowProc(frame->content_proc_, hwnd, message, wparam, lparam);
}

std::optional<LRESULT> WindowFrame::HandleMessage(HWND hwnd, UINT message,
                                                  WPARAM wparam,
                                                  LPARAM lparam) {
  switch (message) {
    case WM_GETMINMAXINFO: {
      auto info = reinterpret_cast<MINMAXINFO*>(lparam);
      const double scale = ScaleFor(hwnd);
      info->ptMinTrackSize.x = static_cast<LONG>(kMinWidth * scale);
      info->ptMinTrackSize.y = static_cast<LONG>(kMinHeight * scale);
      return 0;
    }

    case WM_SIZE:
      if (wparam == SIZE_MAXIMIZED) {
        NotifyMaximized(true);
      } else if (wparam == SIZE_RESTORED) {
        NotifyMaximized(false);
      }
      return std::nullopt;  // The window still resizes the Flutter view.
  }

  if (!CustomFrameEnabled()) return std::nullopt;

  switch (message) {
    case WM_NCCALCSIZE: {
      if (wparam == FALSE) return std::nullopt;
      // Let Windows compute the normal frame, then give the caption back to
      // the client area. Side and bottom borders stay (they are invisible on
      // Windows 10/11 and keep resizing and the shadow working).
      auto params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
      const LONG top = params->rgrc[0].top;
      const LRESULT result = DefWindowProc(hwnd, message, wparam, lparam);
      if (result != 0) return result;
      params->rgrc[0].top = top;
      // A maximised window hangs over the screen edge by the border; keep the
      // title bar on screen.
      if (IsZoomed(hwnd)) params->rgrc[0].top += ResizeBorder(hwnd);
      return 0;
    }

    case WM_NCHITTEST: {
      const LRESULT hit = DefWindowProc(hwnd, message, wparam, lparam);
      if (hit != HTCLIENT) return hit;
      POINT point{GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
      ScreenToClient(hwnd, &point);
      return HitTestClient(hwnd, point);
    }

    // The maximise button is non-client (that is what makes Windows show
    // Snap Layouts), so its hover and clicks arrive here. Flutter only draws
    // it; we report the state over the channel.
    case WM_NCMOUSEMOVE:
      if (wparam == HTMAXBUTTON) {
        if (max_button_state_ == 0) SetMaxButtonState(1);
        if (!tracking_leave_) {
          TRACKMOUSEEVENT track{sizeof(TRACKMOUSEEVENT),
                                TME_LEAVE | TME_NONCLIENT, hwnd, 0};
          tracking_leave_ = TrackMouseEvent(&track) != FALSE;
        }
        return 0;
      }
      SetMaxButtonState(0);
      return std::nullopt;

    case WM_NCMOUSELEAVE:
      tracking_leave_ = false;
      SetMaxButtonState(0);
      return std::nullopt;

    case WM_NCLBUTTONDOWN:
    case WM_NCLBUTTONDBLCLK:
      if (wparam == HTMAXBUTTON) {
        SetMaxButtonState(2);
        return 0;
      }
      return std::nullopt;

    case WM_NCLBUTTONUP:
      if (wparam == HTMAXBUTTON) {
        const bool pressed = max_button_state_ == 2;
        SetMaxButtonState(1);
        if (pressed) ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
        return 0;
      }
      return std::nullopt;
  }
  return std::nullopt;
}

LRESULT WindowFrame::HitTestClient(HWND hwnd, POINT point) const {
  if (!IsZoomed(hwnd)) {
    const int border = ResizeBorder(hwnd);
    if (point.y >= 0 && point.y < border) {
      RECT client;
      GetClientRect(hwnd, &client);
      const int corner = border * 2;
      if (point.x < corner) return HTTOPLEFT;
      if (point.x >= client.right - corner) return HTTOPRIGHT;
      return HTTOP;
    }
  }
  if (InMaxButton(hwnd, point)) return HTMAXBUTTON;
  return HTCLIENT;
}

bool WindowFrame::InMaxButton(HWND hwnd, POINT point) const {
  if (!has_max_button_) return false;
  RECT client;
  GetClientRect(hwnd, &client);
  const double scale = ScaleFor(hwnd);
  const LONG right = client.right - static_cast<LONG>(max_right_ * scale);
  const LONG left = right - static_cast<LONG>(max_width_ * scale);
  const LONG top = static_cast<LONG>(max_top_ * scale);
  const LONG bottom = top + static_cast<LONG>(max_height_ * scale);
  return point.x >= left && point.x < right && point.y >= top &&
         point.y < bottom;
}

void WindowFrame::HandleCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  HWND hwnd = window_;
  if (hwnd == nullptr) {
    result->Error("no_window", "The window is not ready.");
    return;
  }

  if (method == "state") {
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("customFrame"),
         flutter::EncodableValue(CustomFrameEnabled())},
        {flutter::EncodableValue("maximized"),
         flutter::EncodableValue(IsZoomed(hwnd) != FALSE)},
    }));
  } else if (method == "setMaxButton") {
    const auto* list = std::get_if<flutter::EncodableList>(call.arguments());
    if (list != nullptr && list->size() == 4) {
      max_right_ = ToDouble((*list)[0]);
      max_top_ = ToDouble((*list)[1]);
      max_width_ = ToDouble((*list)[2]);
      max_height_ = ToDouble((*list)[3]);
      has_max_button_ = true;
    } else {
      has_max_button_ = false;
    }
    result->Success();
  } else if (method == "startDrag") {
    result->Success();
    // Hand the press to Windows as if it were on a caption: native moving,
    // Aero Snap, and restoring a maximised window under the cursor.
    POINT cursor;
    GetCursorPos(&cursor);
    ReleaseCapture();
    SendMessage(hwnd, WM_NCLBUTTONDOWN, HTCAPTION,
                MAKELPARAM(cursor.x, cursor.y));
  } else if (method == "minimize") {
    ShowWindow(hwnd, SW_MINIMIZE);
    result->Success();
  } else if (method == "toggleMaximize") {
    ShowWindow(hwnd, IsZoomed(hwnd) ? SW_RESTORE : SW_MAXIMIZE);
    result->Success();
  } else if (method == "close") {
    PostMessage(hwnd, WM_CLOSE, 0, 0);
    result->Success();
  } else if (method == "downloadsFolder") {
    // Where Windows keeps Downloads (the user may have moved it to another
    // drive or OneDrive). Null when Windows cannot say.
    PWSTR path = nullptr;
    if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_Downloads, KF_FLAG_DEFAULT,
                                       nullptr, &path)) &&
        path != nullptr) {
      const int size = WideCharToMultiByte(CP_UTF8, 0, path, -1, nullptr, 0,
                                           nullptr, nullptr);
      std::string utf8;
      if (size > 1) {
        utf8.resize(static_cast<size_t>(size));
        WideCharToMultiByte(CP_UTF8, 0, path, -1, utf8.data(), size, nullptr,
                            nullptr);
        utf8.resize(static_cast<size_t>(size - 1));  // drop the terminator
      }
      CoTaskMemFree(path);
      if (utf8.empty()) {
        result->Success();
      } else {
        result->Success(flutter::EncodableValue(utf8));
      }
    } else {
      if (path != nullptr) CoTaskMemFree(path);
      result->Success();
    }
  } else if (method == "showSystemMenu") {
    // Right-click on the title bar: the native window menu at the cursor.
    POINT cursor;
    GetCursorPos(&cursor);
    HMENU menu = GetSystemMenu(hwnd, FALSE);
    if (menu != nullptr) {
      const bool zoomed = IsZoomed(hwnd) != FALSE;
      EnableMenuItem(menu, SC_RESTORE, zoomed ? MF_ENABLED : MF_GRAYED);
      EnableMenuItem(menu, SC_MOVE, zoomed ? MF_GRAYED : MF_ENABLED);
      EnableMenuItem(menu, SC_SIZE, zoomed ? MF_GRAYED : MF_ENABLED);
      EnableMenuItem(menu, SC_MAXIMIZE, zoomed ? MF_GRAYED : MF_ENABLED);
      const UINT command = static_cast<UINT>(TrackPopupMenu(
          menu, TPM_RETURNCMD | TPM_RIGHTBUTTON, cursor.x, cursor.y, 0, hwnd,
          nullptr));
      if (command != 0) PostMessage(hwnd, WM_SYSCOMMAND, command, 0);
    }
    result->Success();
  } else {
    result->NotImplemented();
  }
}

void WindowFrame::SetMaxButtonState(int state) {
  if (state == max_button_state_) return;
  max_button_state_ = state;
  if (channel_) {
    channel_->InvokeMethod("maxButton",
                           std::make_unique<flutter::EncodableValue>(state));
  }
}

void WindowFrame::NotifyMaximized(bool maximized) {
  if (reported_maximized_ == maximized) return;
  reported_maximized_ = maximized;
  if (channel_) {
    channel_->InvokeMethod(
        "maximized", std::make_unique<flutter::EncodableValue>(maximized));
  }
}
