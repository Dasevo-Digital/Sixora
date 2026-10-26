#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;

  // "sixora/clipboard": copies codes outside clipboard history and cloud.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      clipboard_channel_;

  // "sixora/screen": a picture of the screen, to read QR codes from it.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      screen_channel_;

  // "sixora/window": keeps the window out of screenshots, recordings and
  // screen sharing unless the user allows them.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      window_channel_;

  // "sixora/session": tells Dart when the session is locked or the computer
  // goes to sleep, so Sixora locks too.
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      session_channel_;

  void NotifyAway();
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
