import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let backupFolder = BackupFolder()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SixoraFolder") {
      backupFolder.register(registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SixoraClipboard") {
      let channel = FlutterMethodChannel(
        name: "sixora/clipboard", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { call, result in
        guard call.method == "copySensitive",
          let args = call.arguments as? [String: Any],
          let text = args["text"] as? String
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        // Only on this device (no Universal Clipboard) and gone after the
        // expiry, without the app having to run.
        var options: [UIPasteboard.OptionsKey: Any] = [.localOnly: true]
        if let seconds = args["expiresIn"] as? Int, seconds > 0 {
          options[.expirationDate] = Date().addingTimeInterval(TimeInterval(seconds))
        }
        UIPasteboard.general.setItems(
          [[UTType.utf8PlainText.identifier: text]], options: options)
        result(nil)
      }
    }
  }
}

/// The folder for automatic backups (also iCloud Drive or another file
/// provider): picked once, remembered as a bookmark.
final class BackupFolder: NSObject, UIDocumentPickerDelegate {
  private var pending: FlutterResult?

  func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "sixora/folder", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      let args = call.arguments as? [String: Any] ?? [:]
      switch call.method {
      case "pick":
        self.pick(result)
      case "write", "list", "delete":
        guard let ref = args["ref"] as? String, let data = Data(base64Encoded: ref) else {
          result(FlutterError(code: "bad_args", message: nil, details: nil))
          return
        }
        do {
          var stale = false
          let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
          let access = url.startAccessingSecurityScopedResource()
          defer { if access { url.stopAccessingSecurityScopedResource() } }
          result(try Self.call(call.method, url, args))
        } catch {
          result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func pick(_ result: @escaping FlutterResult) {
    let root = UIApplication.shared.connectedScenes
      .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
      .first
    guard var top = root else {
      result(FlutterError(code: "no_window", message: nil, details: nil))
      return
    }
    while let presented = top.presentedViewController { top = presented }
    pending = result
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
    picker.delegate = self
    top.present(picker, animated: true)
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    guard let result = pending, let url = urls.first else { return }
    pending = nil
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    do {
      let data = try url.bookmarkData()
      result(["ref": data.base64EncodedString(), "label": url.lastPathComponent])
    } catch {
      result(FlutterError(code: "io", message: error.localizedDescription, details: nil))
    }
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    pending?(nil)
    pending = nil
  }

  /// File access through a coordinator, as file providers expect.
  private static func call(_ method: String, _ url: URL, _ args: [String: Any]) throws -> Any? {
    let name = args["name"] as? String ?? ""
    let coordinator = NSFileCoordinator()
    var coordError: NSError?
    var failure: Error?
    var output: Any?
    switch method {
    case "write":
      let text = args["text"] as? String ?? ""
      coordinator.coordinate(
        writingItemAt: url.appendingPathComponent(name), options: .forReplacing,
        error: &coordError
      ) { target in
        do { try text.write(to: target, atomically: true, encoding: .utf8) } catch { failure = error }
      }
    case "list":
      coordinator.coordinate(readingItemAt: url, options: [], error: &coordError) { target in
        do {
          output = try FileManager.default.contentsOfDirectory(atPath: target.path)
        } catch { failure = error }
      }
    default:
      coordinator.coordinate(
        writingItemAt: url.appendingPathComponent(name), options: .forDeleting,
        error: &coordError
      ) { target in
        do { try FileManager.default.removeItem(at: target) } catch { failure = error }
      }
    }
    if let error = coordError ?? failure { throw error }
    return output
  }
}
