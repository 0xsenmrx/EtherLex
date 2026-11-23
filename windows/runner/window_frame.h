#ifndef RUNNER_WINDOW_FRAME_H_
#define RUNNER_WINDOW_FRAME_H_

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <windows.h>

#include <memory>
#include <optional>

// EtherLex draws its own title bar. This class removes the native caption but
// keeps an ordinary resizable window, so Windows still gives it borders, the
// shadow, Aero Snap and the Snap Layouts flyout on the maximise button. It
// talks to Dart over the "etherlex/window" method channel
// (lib/app/window/window_chrome.dart).
//
// No layered window, no DWM frame extension, no extra redraws: the caption is
// removed in WM_NCCALCSIZE and the top resize edge and maximise button are
// handled in WM_NCHITTEST.
//
// Set the environment variable ETHERLEX_NATIVE_FRAME=1 to keep the native
// caption, for comparisons.
// ETHERLEX_DIAG_MESSAGES=1 (environment variable): writes the window
// messages that arrive within half a second of each mouse press to
// etherlex-messages.log next to the program. For chasing the Windows "ding"
// on clicks; off by default and never in normal use.
bool DiagMessagesEnabled();
void LogWindowMessage(const char* who, UINT message, WPARAM wparam, LPARAM lparam, LRESULT result);

class WindowFrame {
 public:
  WindowFrame() = default;
  ~WindowFrame();

  WindowFrame(const WindowFrame&) = delete;
  WindowFrame& operator=(const WindowFrame&) = delete;

  static bool CustomFrameEnabled();

  // Call once the Flutter view exists; |content| is the Flutter view's window.
  void Attach(HWND window, HWND content, flutter::BinaryMessenger* messenger);

  // Call before the Flutter engine is destroyed.
  void Detach();

  // Handles the top-level window messages the frame owns. Returns nothing for
  // messages that should continue to the default handling.
  std::optional<LRESULT> HandleMessage(HWND hwnd, UINT message, WPARAM wparam,
                                       LPARAM lparam);

 private:
  using Channel = flutter::MethodChannel<flutter::EncodableValue>;

  static LRESULT CALLBACK ContentProc(HWND hwnd, UINT message, WPARAM wparam,
                                      LPARAM lparam);
  static LRESULT ContentProcImpl(HWND hwnd, UINT message, WPARAM wparam,
                                 LPARAM lparam);

  // Hit test for a point in client coordinates: HTTOP/HTTOPLEFT/HTTOPRIGHT on
  // the top resize edge, HTMAXBUTTON on the maximise button, else HTCLIENT.
  LRESULT HitTestClient(HWND hwnd, POINT point) const;
  bool InMaxButton(HWND hwnd, POINT point) const;

  void HandleCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                      result);

  // 0 idle, 1 hovered, 2 pressed.
  void SetMaxButtonState(int state);
  void NotifyMaximized(bool maximized);

  HWND window_ = nullptr;
  HWND content_ = nullptr;
  WNDPROC content_proc_ = nullptr;
  std::unique_ptr<Channel> channel_;

  // Maximise button, in logical pixels, measured from the window's top-right
  // corner: distance from the right edge, top, width, height.
  bool has_max_button_ = false;
  double max_right_ = 0, max_top_ = 0, max_width_ = 0, max_height_ = 0;

  int max_button_state_ = 0;
  bool tracking_leave_ = false;
  std::optional<bool> reported_maximized_;
};

#endif  // RUNNER_WINDOW_FRAME_H_
