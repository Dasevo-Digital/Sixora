// Native messaging host of the Sixora browser extension ("Mit der
// Sixora-App entsperren"). The browser starts it and talks to it over stdin
// and stdout. The bytes go unchanged to the running Sixora on 127.0.0.1,
// which reads and answers the messages
// (lib/src/platform/browser_link_server.dart) and asks the user first.
#include <arpa/inet.h>
#include <netinet/in.h>
#include <poll.h>
#include <signal.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cstdint>
#include <cstdlib>

namespace {

constexpr uint16_t kPorts[] = {41950, 41951, 41952};

bool TryConnect(uint16_t port, int* out) {
  const int s = socket(AF_INET, SOCK_STREAM, 0);
  if (s < 0) return false;
  sockaddr_in addr = {};
  addr.sin_family = AF_INET;
  addr.sin_port = htons(port);
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  if (connect(s, reinterpret_cast<const sockaddr*>(&addr), sizeof(addr)) ==
      0) {
    *out = s;
    return true;
  }
  close(s);
  return false;
}

int ConnectToApp() {
  int s = -1;
  // SIXORA_LINK_PORT: only this port (the extension's end-to-end test).
  if (const char* test = getenv("SIXORA_LINK_PORT")) {
    return TryConnect(static_cast<uint16_t>(atoi(test)), &s) ? s : -1;
  }
  for (const uint16_t port : kPorts) {
    if (TryConnect(port, &s)) return s;
  }
  return -1;
}

bool WriteAll(int fd, const char* data, size_t size) {
  while (size > 0) {
    const ssize_t n = write(fd, data, size);
    if (n <= 0) return false;
    data += n;
    size -= static_cast<size_t>(n);
  }
  return true;
}

}  // namespace

int main() {
  signal(SIGPIPE, SIG_IGN);
  const int s = ConnectToApp();
  if (s < 0) {
    // No Sixora running: say so instead of leaving the extension waiting.
    static const char kBody[] = "{\"error\":\"not_running\"}";
    const uint32_t length = sizeof(kBody) - 1;  // little-endian (x64, arm64)
    WriteAll(1, reinterpret_cast<const char*>(&length), sizeof(length));
    WriteAll(1, kBody, length);
    return 0;
  }
  pollfd fds[2] = {{0, POLLIN, 0}, {s, POLLIN, 0}};
  char buffer[65536];
  while (poll(fds, 2, -1) > 0) {
    if (fds[0].revents != 0) {
      const ssize_t n = read(0, buffer, sizeof(buffer));
      if (n <= 0) {
        // The browser is done sending: answers may still come.
        shutdown(s, SHUT_WR);
        fds[0].fd = -1;
      } else if (!WriteAll(s, buffer, static_cast<size_t>(n))) {
        break;
      }
    }
    if (fds[1].revents != 0) {
      const ssize_t n = read(s, buffer, sizeof(buffer));
      if (n <= 0 || !WriteAll(1, buffer, static_cast<size_t>(n))) break;
    }
  }
  close(s);
  return 0;
}
