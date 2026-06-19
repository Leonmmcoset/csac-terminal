import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let shortcutsChannel = FlutterMethodChannel(
      name: "ink.jjmm.csacflutter/shortcuts",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    shortcutsChannel.setMethodCallHandler { call, result in
      if call.method == "setUnreadStatus",
         let status = call.arguments as? [String: Any] {
        UserDefaults.standard.set(status, forKey: "CsACShortcutUnreadStatus")
        result(nil)
        return
      }
      result(FlutterMethodNotImplemented)
    }

    super.awakeFromNib()
  }
}
