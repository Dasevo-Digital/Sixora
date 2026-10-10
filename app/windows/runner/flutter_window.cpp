#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>
#include <string>
#include <vector>

#include "flutter/generated_plugin_registrant.h"

namespace {

// The whole virtual screen (all monitors) as 32-bit BGRA pixels, top row
// first: {width, height, pixels}. A QR code shown in another app can then be
// read without a screenshot file.
std::optional<flutter::EncodableValue> CaptureScreen() {
  const int x = GetSystemMetrics(SM_XVIRTUALSCREEN);
  const int y = GetSystemMetrics(SM_YVIRTUALSCREEN);
  const int width = GetSystemMetrics(SM_CXVIRTUALSCREEN);
  const int height = GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if (width <= 0 || height <= 0) return std::nullopt;
  HDC screen = GetDC(nullptr);
  HDC memory = CreateCompatibleDC(screen);
  BITMAPINFO info = {};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = width;
  info.bmiHeader.biHeight = -height;  // top-down
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  void* bits = nullptr;
  HBITMAP bitmap =
      CreateDIBSection(screen, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
  std::optional<flutter::EncodableValue> result;
  if (bitmap && bits) {
    HGDIOBJ old = SelectObject(memory, bitmap);
    if (BitBlt(memory, 0, 0, width, height, screen, x, y,
               SRCCOPY | CAPTUREBLT)) {
      const auto* data = static_cast<const uint8_t*>(bits);
      std::vector<uint8_t> pixels(data, data + size_t(width) * height * 4);
      result = flutter::EncodableValue(flutter::EncodableMap{
          {flutter::EncodableValue("width"), flutter::EncodableValue(width)},
          {flutter::EncodableValue("height"), flutter::EncodableValue(height)},
          {flutter::EncodableValue("pixels"), flutter::EncodableValue(pixels)},
      });
    }
    SelectObject(memory, old);
  }
  if (bitmap) DeleteObject(bitmap);
  DeleteDC(memory);
  ReleaseDC(nullptr, screen);
  return result;
}

// Puts |text| on the clipboard and asks Windows to keep it out of the
// clipboard history (Win+V), the cloud clipboard and clipboard monitors.
bool CopySensitive(HWND window, const std::string& utf8) {
  const int length = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
  if (length <= 0 || !OpenClipboard(window)) {
    return false;
  }
  EmptyClipboard();
  bool ok = false;
  HGLOBAL text = GlobalAlloc(GMEM_MOVEABLE, length * sizeof(wchar_t));
  if (text) {
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1,
                        static_cast<wchar_t*>(GlobalLock(text)), length);
    GlobalUnlock(text);
    ok = SetClipboardData(CF_UNICODETEXT, text) != nullptr;
    if (!ok) {
      GlobalFree(text);
    }
  }
  const auto put_dword = [](const wchar_t* format, DWORD value) {
    const UINT id = RegisterClipboardFormatW(format);
    HGLOBAL data = GlobalAlloc(GMEM_MOVEABLE, sizeof(DWORD));
    if (!id || !data) {
      if (data) GlobalFree(data);
      return;
    }
    *static_cast<DWORD*>(GlobalLock(data)) = value;
    GlobalUnlock(data);
    if (!SetClipboardData(id, data)) {
      GlobalFree(data);
    }
  };
  put_dword(L"ExcludeClipboardContentFromMonitorProcessing", 0);
  put_dword(L"CanIncludeInClipboardHistory", 0);
  put_dword(L"CanUploadToCloudClipboard", 0);
  CloseClipboard();
  return ok;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

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
  clipboard_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "sixora/clipboard",
          &flutter::StandardMethodCodec::GetInstance());
  clipboard_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                 result) {
        if (call.method_name() != "copySensitive") {
          result->NotImplemented();
          return;
        }
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) {
          result->Error("bad_args");
          return;
        }
        const auto found = args->find(flutter::EncodableValue("text"));
        const auto* text = found == args->end()
                               ? nullptr
                               : std::get_if<std::string>(&found->second);
        if (!text || !CopySensitive(GetHandle(), *text)) {
          result->Error("clipboard", "Zwischenablage nicht verfügbar");
          return;
        }
        result->Success();
      });
  screen_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "sixora/screen",
          &flutter::StandardMethodCodec::GetInstance());
  screen_channel_->SetMethodCallHandler(
      [](const flutter::MethodCall<flutter::EncodableValue>& call,
         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
             result) {
        if (call.method_name() != "capture") {
          result->NotImplemented();
          return;
        }
        auto shot = CaptureScreen();
        if (!shot) {
          result->Error("capture", "Bildschirm nicht verfügbar");
          return;
        }
        result->Success(*shot);
      });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

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
  clipboard_channel_ = nullptr;
  screen_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
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
