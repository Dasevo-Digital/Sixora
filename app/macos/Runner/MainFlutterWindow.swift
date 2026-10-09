import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    // A narrow window like an authenticator on the phone; resizable.
    self.setContentSize(NSSize(width: 480, height: 760))
    self.contentMinSize = NSSize(width: 360, height: 480)
    self.center()
    self.setFrameAutosaveName("SixoraMainWindow")

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerClipboard(flutterViewController.engine.binaryMessenger)
    BackupFolder.register(flutterViewController.engine.binaryMessenger)
    registerLinkHandler(flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  /// Control-click is a right click on the Mac. Flutter only knows the
  /// right button, so the click is passed on as one: the context menu
  /// (e.g. „Einfügen“) opens either way.
  private var controlClick = false

  override func sendEvent(_ event: NSEvent) {
    switch event.type {
    case .leftMouseDown where event.modifierFlags.contains(.control):
      controlClick = true
      super.sendEvent(asRightButton(event, .rightMouseDown))
    case .leftMouseDragged where controlClick:
      super.sendEvent(asRightButton(event, .rightMouseDragged))
    case .leftMouseUp where controlClick:
      controlClick = false
      super.sendEvent(asRightButton(event, .rightMouseUp))
    default:
      super.sendEvent(event)
    }
  }

  private func asRightButton(_ event: NSEvent, _ type: NSEvent.EventType) -> NSEvent {
    NSEvent.mouseEvent(
      with: type, location: event.locationInWindow,
      modifierFlags: event.modifierFlags.subtracting(.control), timestamp: event.timestamp,
      windowNumber: event.windowNumber, context: nil, eventNumber: event.eventNumber,
      clickCount: event.clickCount, pressure: event.pressure) ?? event
  }
}

/// Copies codes marked as concealed and transient (nspasteboard.org), so
/// clipboard managers and history tools leave them out.
private func registerClipboard(_ messenger: FlutterBinaryMessenger) {
  let channel = FlutterMethodChannel(name: "sixora/clipboard", binaryMessenger: messenger)
  channel.setMethodCallHandler { call, result in
    guard call.method == "copySensitive",
      let args = call.arguments as? [String: Any],
      let text = args["text"] as? String
    else {
      result(FlutterMethodNotImplemented)
      return
    }
    let board = NSPasteboard.general
    board.clearContents()
    let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    board.declareTypes([.string, concealed, transient], owner: nil)
    board.setString(text, forType: .string)
    board.setString("", forType: concealed)
    board.setString("", forType: transient)
    result(nil)
  }
}

/// The folder for automatic backups: picked once, remembered as a
/// security-scoped bookmark, so the sandboxed app may write there later.
enum BackupFolder {
  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "sixora/folder", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      let args = call.arguments as? [String: Any] ?? [:]
      do {
        switch call.method {
        case "pick":
          let panel = NSOpenPanel()
          panel.canChooseDirectories = true
          panel.canChooseFiles = false
          panel.canCreateDirectories = true
          panel.allowsMultipleSelection = false
          panel.prompt = "Auswählen"
          panel.message = "Ordner für die automatische Sicherung"
          guard panel.runModal() == .OK, let url = panel.url else {
            result(nil)
            return
          }
          let data = try url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
          result(["ref": data.base64EncodedString(), "label": url.path])
        case "write", "list", "delete", "read":
          guard let ref = args["ref"] as? String, let data = Data(base64Encoded: ref) else {
            result(FlutterError(code: "bad_args", message: nil, details: nil))
            return
          }
          var stale = false
          let url = try URL(
            resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil,
            bookmarkDataIsStale: &stale)
          guard url.startAccessingSecurityScopedResource() else {
            result(FlutterError(code: "denied", message: "Kein Zugriff auf den Ordner", details: nil))
            return
          }
          defer { url.stopAccessingSecurityScopedResource() }
          result(try folderCall(call.method, url, args))
        default:
          result(FlutterMethodNotImplemented)
        }
      } catch {
        result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
      }
    }
  }
}

private func folderCall(_ method: String, _ url: URL, _ args: [String: Any]) throws -> Any? {
  let fm = FileManager.default
  switch method {
  case "write":
    let name = args["name"] as? String ?? ""
    let text = args["text"] as? String ?? ""
    try text.write(to: url.appendingPathComponent(name), atomically: true, encoding: .utf8)
    return nil
  case "list":
    return try fm.contentsOfDirectory(atPath: url.path)
  case "read":
    let name = args["name"] as? String ?? ""
    return try String(contentsOf: url.appendingPathComponent(name), encoding: .utf8)
  default:
    let name = args["name"] as? String ?? ""
    try fm.removeItem(at: url.appendingPathComponent(name))
    return nil
  }
}

/// Which app opens otpauth:// links. Apple's Passwords app claims them too,
/// and macOS has no setting for it: Sixora asks to become the handler (the
/// system confirms with its own dialog).
private func registerLinkHandler(_ messenger: FlutterBinaryMessenger) {
  let schemes = ["otpauth", "otpauth-migration"]
  let channel = FlutterMethodChannel(name: "sixora/links", binaryMessenger: messenger)
  channel.setMethodCallHandler { call, result in
    let me = Bundle.main.bundleURL.standardizedFileURL
    switch call.method {
    case "handler":
      let app = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "otpauth://totp/x")!)
      result([
        "isDefault": app?.standardizedFileURL == me,
        "name": app.map { FileManager.default.displayName(atPath: $0.path) } ?? "",
      ])
    case "makeDefault":
      let group = DispatchGroup()
      var failure: Error?
      for scheme in schemes {
        group.enter()
        NSWorkspace.shared.setDefaultApplication(at: me, toOpenURLsWithScheme: scheme) { error in
          if let error, failure == nil { failure = error }
          group.leave()
        }
      }
      group.notify(queue: .main) {
        if let failure {
          result(FlutterError(code: "declined", message: failure.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
