import Cocoa
import Darwin
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// A browser starts this binary as the native messaging host of the
  /// Sixora extension; then it only passes bytes on (BrowserRelay) and never
  /// shows anything.
  static func main() {
    if let status = BrowserRelay.runIfHost(CommandLine.arguments) {
      exit(status)
    }
    _ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
  }

  // Sixora decides itself (DesktopShell): with "In der Menüleiste
  // weiterlaufen" the window only hides, otherwise the app quits.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  // Sixora may keep running in the menu bar with its window hidden: a click
  // on the Dock icon brings the window back.
  override func applicationShouldHandleReopen(
    _ sender: NSApplication, hasVisibleWindows flag: Bool
  ) -> Bool {
    if !flag {
      for window in sender.windows where window is MainFlutterWindow {
        window.makeKeyAndOrderFront(self)
      }
    }
    return true
  }
}

/// Native messaging host of the browser extension ("Mit Touch ID
/// entsperren"). Chromium passes the extension's origin, Firefox the
/// manifest path and the extension's ID. The bytes go unchanged to the
/// running Sixora on 127.0.0.1, which reads and answers the messages
/// (lib/src/platform/browser_link_server.dart) and asks the user first.
enum BrowserRelay {
  static let ports: [UInt16] = [41950, 41951, 41952]
  static let firefoxId = "{8f8c1986-faf4-48a3-a267-a6c28c12f5ec}"

  static func runIfHost(_ args: [String]) -> Int32? {
    guard args.count >= 2,
      args[1].hasPrefix("chrome-extension://") || (args.count >= 3 && args[2] == firefoxId)
    else { return nil }
    return run()
  }

  private static func run() -> Int32 {
    signal(SIGPIPE, SIG_IGN)
    guard let sock = connectToApp() else {
      // No Sixora running: say so instead of leaving the extension waiting.
      let body = Array("{\"error\":\"not_running\"}".utf8)
      var length = UInt32(body.count).littleEndian
      let header = withUnsafeBytes(of: &length) { Array($0) }
      _ = writeAll(STDOUT_FILENO, header + body)
      return 0
    }
    defer { close(sock) }
    var fds = [
      pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0),
      pollfd(fd: sock, events: Int16(POLLIN), revents: 0),
    ]
    var buffer = [UInt8](repeating: 0, count: 65536)
    while poll(&fds, 2, -1) > 0 {
      if fds[0].revents != 0 {
        let n = read(STDIN_FILENO, &buffer, buffer.count)
        if n <= 0 {
          // The browser is done sending: answers may still come.
          shutdown(sock, SHUT_WR)
          fds[0].fd = -1
        } else if !writeAll(sock, Array(buffer[0..<n])) {
          return 0
        }
      }
      if fds[1].revents != 0 {
        let n = read(sock, &buffer, buffer.count)
        if n <= 0 || !writeAll(STDOUT_FILENO, Array(buffer[0..<n])) { return 0 }
      }
    }
    return 0
  }

  /// SIXORA_LINK_PORT: only this port (the extension's end-to-end test).
  private static var candidates: [UInt16] {
    if let value = ProcessInfo.processInfo.environment["SIXORA_LINK_PORT"],
      let port = UInt16(value)
    {
      return [port]
    }
    return ports
  }

  private static func connectToApp() -> Int32? {
    for port in candidates {
      let fd = socket(AF_INET, SOCK_STREAM, 0)
      if fd < 0 { continue }
      var addr = sockaddr_in()
      addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
      addr.sin_family = sa_family_t(AF_INET)
      addr.sin_port = port.bigEndian
      addr.sin_addr.s_addr = inet_addr("127.0.0.1")
      let connected = withUnsafePointer(to: &addr) {
        $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
          Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
        }
      }
      if connected { return fd }
      close(fd)
    }
    return nil
  }

  private static func writeAll(_ fd: Int32, _ bytes: [UInt8]) -> Bool {
    var offset = 0
    while offset < bytes.count {
      let n = bytes[offset...].withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
      if n <= 0 { return false }
      offset += n
    }
    return true
  }
}
