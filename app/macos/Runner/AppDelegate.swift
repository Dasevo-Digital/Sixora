import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
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
