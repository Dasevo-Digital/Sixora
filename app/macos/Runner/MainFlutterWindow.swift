import Cocoa
import FlutterMacOS
import ImageIO
import ScreenCaptureKit

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
    MenuLanguage.register(flutterViewController.engine.binaryMessenger)
    ScreenShot.register(flutterViewController.engine.binaryMessenger)

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
          panel.prompt = args["prompt"] as? String ?? "OK"
          panel.message = args["message"] as? String ?? ""
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

/// The main menu comes from MainMenu.xib in German. When the app runs in
/// another language (Dart sends it), the titles are swapped; the German
/// originals stay in a table, so switching back works too.
enum MenuLanguage {
  private static var originals: [ObjectIdentifier: String] = [:]

  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "sixora/menu", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      if call.method == "setLanguage", let code = call.arguments as? String {
        apply(code)
      }
      result(nil)
    }
  }

  private static func apply(_ code: String) {
    guard let menu = NSApp.mainMenu else { return }
    let table = code == "en" ? english : code == "es" ? spanish : [:]
    let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Sixora"
    func walk(_ menu: NSMenu) {
      for item in menu.items {
        let id = ObjectIdentifier(item)
        let original = originals[id] ?? item.title
        originals[id] = original
        // Titles with the app name ("Über Sixora") are looked up as "Über %@".
        let pattern = original.replacingOccurrences(of: app, with: "%@")
        if let translated = table[pattern] {
          item.title = translated.replacingOccurrences(of: "%@", with: app)
        } else {
          item.title = original
        }
        if let sub = item.submenu {
          let subId = ObjectIdentifier(sub)
          let subOriginal = originals[subId] ?? sub.title
          originals[subId] = subOriginal
          sub.title = table[subOriginal] ?? subOriginal
          walk(sub)
        }
      }
    }
    walk(menu)
  }

  private static let english: [String: String] = [
    "Über %@": "About %@",
    "Einstellungen …": "Settings…",
    "Dienste": "Services",
    "%@ ausblenden": "Hide %@",
    "Andere ausblenden": "Hide Others",
    "Alle einblenden": "Show All",
    "%@ beenden": "Quit %@",
    "Bearbeiten": "Edit",
    "Widerrufen": "Undo",
    "Wiederholen": "Redo",
    "Ausschneiden": "Cut",
    "Kopieren": "Copy",
    "Einsetzen": "Paste",
    "Einsetzen und Stil anpassen": "Paste and Match Style",
    "Löschen": "Delete",
    "Alles auswählen": "Select All",
    "Suchen": "Find",
    "Suchen …": "Find…",
    "Suchen und ersetzen …": "Find and Replace…",
    "Weitersuchen": "Find Next",
    "Rückwärts suchen": "Find Previous",
    "Auswahl suchen": "Use Selection for Find",
    "Zur Auswahl springen": "Jump to Selection",
    "Rechtschreibung und Grammatik": "Spelling and Grammar",
    "Rechtschreibung": "Spelling",
    "Rechtschreibung und Grammatik einblenden": "Show Spelling and Grammar",
    "Dokument jetzt prüfen": "Check Document Now",
    "Während der Texteingabe prüfen": "Check Spelling While Typing",
    "Grammatik mit Rechtschreibung prüfen": "Check Grammar With Spelling",
    "Rechtschreibung automatisch korrigieren": "Correct Spelling Automatically",
    "Ersetzungen": "Substitutions",
    "Ersetzungen einblenden": "Show Substitutions",
    "Intelligentes Kopieren/Einsetzen": "Smart Copy/Paste",
    "Intelligente Anführungszeichen": "Smart Quotes",
    "Intelligente Gedankenstriche": "Smart Dashes",
    "Intelligente Links": "Smart Links",
    "Datenerkennung": "Data Detectors",
    "Textersetzung": "Text Replacement",
    "Umwandlungen": "Transformations",
    "In Großbuchstaben": "Make Upper Case",
    "In Kleinbuchstaben": "Make Lower Case",
    "Großschreibung": "Capitalize",
    "Sprachausgabe": "Speech",
    "Sprachausgabe starten": "Start Speaking",
    "Sprachausgabe stoppen": "Stop Speaking",
    "Darstellung": "View",
    "Vollbildmodus aktivieren": "Enter Full Screen",
    "Fenster": "Window",
    "Im Dock ablegen": "Minimize",
    "Zoomen": "Zoom",
    "Alle nach vorne bringen": "Bring All to Front",
    "Hilfe": "Help"
  ]

  private static let spanish: [String: String] = [
    "Über %@": "Acerca de %@",
    "Einstellungen …": "Ajustes…",
    "Dienste": "Servicios",
    "%@ ausblenden": "Ocultar %@",
    "Andere ausblenden": "Ocultar otros",
    "Alle einblenden": "Mostrar todo",
    "%@ beenden": "Salir de %@",
    "Bearbeiten": "Edición",
    "Widerrufen": "Deshacer",
    "Wiederholen": "Rehacer",
    "Ausschneiden": "Cortar",
    "Kopieren": "Copiar",
    "Einsetzen": "Pegar",
    "Einsetzen und Stil anpassen": "Pegar y adaptar estilo",
    "Löschen": "Eliminar",
    "Alles auswählen": "Seleccionar todo",
    "Suchen": "Buscar",
    "Suchen …": "Buscar…",
    "Suchen und ersetzen …": "Buscar y reemplazar…",
    "Weitersuchen": "Buscar siguiente",
    "Rückwärts suchen": "Buscar anterior",
    "Auswahl suchen": "Usar selección para buscar",
    "Zur Auswahl springen": "Ir a la selección",
    "Rechtschreibung und Grammatik": "Ortografía y gramática",
    "Rechtschreibung": "Ortografía",
    "Rechtschreibung und Grammatik einblenden": "Mostrar ortografía y gramática",
    "Dokument jetzt prüfen": "Comprobar documento ahora",
    "Während der Texteingabe prüfen": "Revisar ortografía mientras se escribe",
    "Grammatik mit Rechtschreibung prüfen": "Revisar gramática con ortografía",
    "Rechtschreibung automatisch korrigieren": "Corregir ortografía automáticamente",
    "Ersetzungen": "Sustituciones",
    "Ersetzungen einblenden": "Mostrar sustituciones",
    "Intelligentes Kopieren/Einsetzen": "Copiar/pegar inteligente",
    "Intelligente Anführungszeichen": "Comillas inteligentes",
    "Intelligente Gedankenstriche": "Guiones inteligentes",
    "Intelligente Links": "Enlaces inteligentes",
    "Datenerkennung": "Detectores de datos",
    "Textersetzung": "Sustitución de texto",
    "Umwandlungen": "Transformaciones",
    "In Großbuchstaben": "Convertir a mayúsculas",
    "In Kleinbuchstaben": "Convertir a minúsculas",
    "Großschreibung": "Poner en mayúscula inicial",
    "Sprachausgabe": "Voz",
    "Sprachausgabe starten": "Iniciar locución",
    "Sprachausgabe stoppen": "Detener locución",
    "Darstellung": "Visualización",
    "Vollbildmodus aktivieren": "Entrar en pantalla completa",
    "Fenster": "Ventana",
    "Im Dock ablegen": "Minimizar",
    "Zoomen": "Zoom",
    "Alle nach vorne bringen": "Traer todo al frente",
    "Hilfe": "Ayuda"
  ]
}

/// QR codes on the screen: the system picker lets the user choose a window
/// or a display. What is chosen there is shared for this one picture, so
/// Sixora needs no screen recording permission. macOS 14 and later; before
/// that Dart falls back to the screenshot tool (`screencapture -i`).
enum ScreenShot {
  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "sixora/screen", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      guard call.method == "pick" else { return result(FlutterMethodNotImplemented) }
      if #available(macOS 14.0, *) {
        ScreenPicker.shared.pick(result)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

/// Answers with the path of a PNG in the temporary folder, or nil if the
/// user cancelled.
@available(macOS 14.0, *)
private final class ScreenPicker: NSObject, SCContentSharingPickerObserver {
  static let shared = ScreenPicker()
  private var pending: FlutterResult?

  func pick(_ result: @escaping FlutterResult) {
    pending?(nil)
    pending = result
    var config = SCContentSharingPickerConfiguration()
    config.allowedPickerModes = [.singleWindow, .singleDisplay]
    if let id = Bundle.main.bundleIdentifier { config.excludedBundleIDs = [id] }
    let picker = SCContentSharingPicker.shared
    picker.defaultConfiguration = config
    picker.add(self)
    picker.isActive = true
    picker.present()
  }

  func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
    finish(nil)
  }

  func contentSharingPickerStartDidFailWithError(_ error: Error) {
    finish(FlutterError(code: "capture", message: error.localizedDescription, details: nil))
  }

  func contentSharingPicker(
    _ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter,
    for stream: SCStream?
  ) {
    Task {
      do {
        finish(try await capture(filter))
      } catch {
        finish(FlutterError(code: "capture", message: error.localizedDescription, details: nil))
      }
    }
  }

  /// Full pixel resolution: on a large screen the code is small.
  private func capture(_ filter: SCContentFilter) async throws -> String {
    let config = SCStreamConfiguration()
    let scale = CGFloat(filter.pointPixelScale)
    config.width = Int(filter.contentRect.width * scale)
    config.height = Int(filter.contentRect.height * scale)
    config.showsCursor = false
    let image = try await SCScreenshotManager.captureImage(
      contentFilter: filter, configuration: config)
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("sixora-screen-\(UUID().uuidString).png")
    guard
      let target = CGImageDestinationCreateWithURL(
        url as CFURL, "public.png" as CFString, 1, nil)
    else { throw CocoaError(.fileWriteUnknown) }
    CGImageDestinationAddImage(target, image, nil)
    guard CGImageDestinationFinalize(target) else { throw CocoaError(.fileWriteUnknown) }
    return url.path
  }

  private func finish(_ value: Any?) {
    DispatchQueue.main.async {
      let picker = SCContentSharingPicker.shared
      picker.remove(self)
      picker.isActive = false
      self.pending?(value)
      self.pending = nil
    }
  }
}
