import Flutter
import UIKit
import UniformTypeIdentifiers

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
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
