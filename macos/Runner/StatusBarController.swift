import AppKit
import FlutterMacOS

class StatusBarController {
  private var statusBar: NSStatusBar
  private var statusItem: NSStatusItem
  private var popover: NSPopover
  private var flutterViewController: FlutterViewController

  init(_ popover: NSPopover, _ flutterViewController: FlutterViewController) {
    self.popover = popover
    self.flutterViewController = flutterViewController

    print("Initialize StatusBarController...")

    statusBar = NSStatusBar.init()
    statusItem = statusBar.statusItem(withLength: 22.0)

    if let statusBarButton = statusItem.button {
      statusBarButton.image = self.createLogoImage(
        named: "Microphone-Inactive", size: NSSize(width: 22.0, height: 22.0), isTemplate: true)
      statusBarButton.action = #selector(toggleVoiceInput(sender:))
      statusBarButton.target = self
    }

    setupMethodChannel()
  }

  private func setupMethodChannel() {
    let channel = FlutterMethodChannel(
      name: "com.normadit.whistle/StatusBarController",
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    channel.setMethodCallHandler {
      [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "toggleVoiceInput":
        self?.toggleVoiceInput(sender: NSObject())
        result(nil)
      case "updateStatusBarIcon":
        if let isRecording = call.arguments as? Bool {
          self?.updateStatusBarIcon(isRecording: isRecording)
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @objc func toggleVoiceInput(sender: AnyObject) {
    let channel = FlutterMethodChannel(
      name: "com.normadit.whistle/StatusBarController",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.invokeMethod("toggleVoiceInput", arguments: nil)
  }

  private func updateStatusBarIcon(isRecording: Bool) {
    DispatchQueue.main.async {
      if let statusBarButton = self.statusItem.button {
        statusBarButton.image = self.createLogoImage(
          named: isRecording ? "Microphone-Recording" : "Microphone-Inactive",
          size: NSSize(width: 22.0, height: 22.0), isTemplate: true)
      }
    }
  }

  private func createLogoImage(named name: String, size: NSSize, isTemplate: Bool) -> NSImage? {
    let image = NSImage(named: NSImage.Name(name))
    image?.size = size
    image?.isTemplate = isTemplate
    return image
  }

}
