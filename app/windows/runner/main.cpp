#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include <string>

#include "app_links/app_links_plugin_c_api.h"
#include "flutter_window.h"
#include "utils.h"

namespace {

// Makes this exe the handler of |scheme| for the current user, unless
// another program (e.g. another authenticator) already handles it.
void RegisterScheme(const wchar_t* scheme, const std::wstring& exe) {
  const std::wstring key = std::wstring(L"Software\\Classes\\") + scheme;
  const std::wstring command = L"\"" + exe + L"\" \"%1\"";
  const std::wstring command_key = key + L"\\shell\\open\\command";

  wchar_t current[MAX_PATH * 2] = {};
  DWORD size = sizeof(current);
  if (RegGetValueW(HKEY_CURRENT_USER, command_key.c_str(), nullptr,
                   RRF_RT_REG_SZ, nullptr, current, &size) == ERROR_SUCCESS &&
      command != current &&
      std::wstring(current).find(L"Sixora") == std::wstring::npos) {
    return;
  }
  const std::wstring description = std::wstring(L"URL:") + scheme;
  RegSetKeyValueW(HKEY_CURRENT_USER, key.c_str(), nullptr, REG_SZ,
                  description.c_str(),
                  static_cast<DWORD>((description.size() + 1) * sizeof(wchar_t)));
  RegSetKeyValueW(HKEY_CURRENT_USER, key.c_str(), L"URL Protocol", REG_SZ,
                  L"", sizeof(wchar_t));
  RegSetKeyValueW(HKEY_CURRENT_USER, command_key.c_str(), nullptr, REG_SZ,
                  command.c_str(),
                  static_cast<DWORD>((command.size() + 1) * sizeof(wchar_t)));
}

void RegisterSchemes() {
  wchar_t path[MAX_PATH] = {};
  if (GetModuleFileNameW(nullptr, path, MAX_PATH) == 0) return;
  for (const wchar_t* scheme : {L"otpauth", L"otpauth-migration", L"sixora"}) {
    RegisterScheme(scheme, path);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // A link (otpauth://, sixora://) goes to the running Sixora, if any.
  if (SendAppLinkToInstance()) {
    return EXIT_SUCCESS;
  }
  RegisterSchemes();

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(480, 800);
  if (!window.Create(L"Sixora", origin, size)) {
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
