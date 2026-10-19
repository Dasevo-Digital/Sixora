// Native messaging host of the Sixora browser extension ("Mit Windows
// Hello entsperren"). The browser starts it (through cmd.exe, hence a
// console program of its own) and talks to it over stdin and stdout. The
// bytes go unchanged to the running Sixora on 127.0.0.1, which reads and
// answers the messages (lib/src/platform/browser_link_server.dart) and asks
// the user first.
#include <winsock2.h>
#include <windows.h>

#include <cstdint>
#include <cstdlib>

namespace {

constexpr unsigned short kPorts[] = {41950, 41951, 41952};

SOCKET TryConnect(unsigned short port) {
  SOCKET s = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (s == INVALID_SOCKET) {
    return INVALID_SOCKET;
  }
  sockaddr_in addr = {};
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  if (connect(s, reinterpret_cast<const sockaddr*>(&addr), sizeof(addr)) ==
      0) {
    return s;
  }
  closesocket(s);
  return INVALID_SOCKET;
}

SOCKET ConnectToApp() {
  // SIXORA_LINK_PORT: only this port (the extension's end-to-end test).
  char test[16] = {};
  if (GetEnvironmentVariableA("SIXORA_LINK_PORT", test, sizeof(test)) > 0) {
    return TryConnect(static_cast<unsigned short>(atoi(test)));
  }
  for (const unsigned short port : kPorts) {
    const SOCKET s = TryConnect(port);
    if (s != INVALID_SOCKET) {
      return s;
    }
  }
  return INVALID_SOCKET;
}

bool WriteAll(HANDLE out, const char* data, DWORD size) {
  while (size > 0) {
    DWORD written = 0;
    if (!WriteFile(out, data, size, &written, nullptr) || written == 0) {
      return false;
    }
    data += written;
    size -= written;
  }
  return true;
}

// Browser to app. When the browser is done sending, only that direction is
// shut down: answers may still come, and the app then closes the
// connection, which ends the loop in main.
DWORD WINAPI StdinToApp(LPVOID param) {
  const SOCKET s = reinterpret_cast<SOCKET>(param);
  HANDLE in = GetStdHandle(STD_INPUT_HANDLE);
  char buffer[65536];
  DWORD n = 0;
  while (ReadFile(in, buffer, sizeof(buffer), &n, nullptr) && n > 0) {
    for (DWORD sent = 0; sent < n;) {
      const int r = send(s, buffer + sent, static_cast<int>(n - sent), 0);
      if (r <= 0) {
        return 0;
      }
      sent += static_cast<DWORD>(r);
    }
  }
  shutdown(s, SD_SEND);
  return 0;
}

}  // namespace

int main() {
  WSADATA wsa;
  if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) {
    return 1;
  }
  HANDLE out = GetStdHandle(STD_OUTPUT_HANDLE);
  const SOCKET s = ConnectToApp();
  if (s == INVALID_SOCKET) {
    // No Sixora running: say so instead of leaving the extension waiting.
    static const char kBody[] = "{\"error\":\"not_running\"}";
    const uint32_t length = sizeof(kBody) - 1;  // little-endian, as required
    WriteAll(out, reinterpret_cast<const char*>(&length), sizeof(length));
    WriteAll(out, kBody, length);
    WSACleanup();
    return 0;
  }
  HANDLE reader = CreateThread(nullptr, 0, StdinToApp,
                               reinterpret_cast<LPVOID>(s), 0, nullptr);
  char buffer[65536];
  int n = 0;
  while ((n = recv(s, buffer, sizeof(buffer), 0)) > 0) {
    if (!WriteAll(out, buffer, static_cast<DWORD>(n))) {
      break;
    }
  }
  closesocket(s);
  if (reader) {
    CloseHandle(reader);
  }
  WSACleanup();
  return 0;
}
