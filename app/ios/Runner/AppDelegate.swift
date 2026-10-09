import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let backupFolder = BackupFolder()
  private let privacyCover = PrivacyCover()

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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SixoraPrivacy") {
      privacyCover.register(registrar.messenger())
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
      case "write", "list", "delete", "read":
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
    case "read":
      coordinator.coordinate(
        readingItemAt: url.appendingPathComponent(name), options: [], error: &coordError
      ) { target in
        do { output = try String(contentsOf: target, encoding: .utf8) } catch { failure = error }
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

/// Covers the window natively as soon as the app stops being active. iOS
/// takes its app switcher picture right then, and shows that picture again
/// when the app comes back – before Flutter has drawn anything new. A cover
/// drawn by Flutter may come too late for both; this one is there at once.
/// Flutter removes it once the current state (e.g. the lock screen) is on
/// screen; a timer removes it in any case.
final class PrivacyCover: NSObject {
  private var cover: UIView?
  private var fallback: Timer?

  func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "sixora/privacy", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "uncover" { self?.uncover() }
      result(nil)
    }
    let center = NotificationCenter.default
    center.addObserver(
      self, selector: #selector(willDeactivate(_:)),
      name: UIScene.willDeactivateNotification, object: nil)
    center.addObserver(
      self, selector: #selector(didActivate(_:)),
      name: UIScene.didActivateNotification, object: nil)
  }

  @objc private func willDeactivate(_ note: Notification) {
    fallback?.invalidate()
    guard cover == nil,
      let window = (note.object as? UIWindowScene)?.windows.first(where: { $0.isKeyWindow })
        ?? (note.object as? UIWindowScene)?.windows.first
    else { return }
    let view = UIView(frame: window.bounds)
    view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    view.backgroundColor = UIColor(red: 0x4F / 255, green: 0x46 / 255, blue: 0xE5 / 255, alpha: 1)
    let icon = UIImageView(
      image: UIImage(
        systemName: "lock.shield.fill",
        withConfiguration: UIImage.SymbolConfiguration(pointSize: 64, weight: .regular)))
    icon.tintColor = .white
    icon.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(icon)
    NSLayoutConstraint.activate([
      icon.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      icon.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])
    window.addSubview(view)
    cover = view
  }

  @objc private func didActivate(_ note: Notification) {
    fallback?.invalidate()
    fallback = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
      self?.uncover()
    }
  }

  private func uncover() {
    fallback?.invalidate()
    fallback = nil
    cover?.removeFromSuperview()
    cover = nil
  }
}
