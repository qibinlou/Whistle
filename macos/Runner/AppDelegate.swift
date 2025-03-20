import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  var statusBar: StatusBarController?
  var popover = NSPopover.init()

  override init() {
    popover.behavior = NSPopover.Behavior.transient  //to make the popover hide when the user clicks outside of it
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
}

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let controller: FlutterViewController =
      mainFlutterWindow!.contentViewController as! FlutterViewController

    popover.contentSize = NSSize(width: 360, height: 360)  //change this to your desired size
    popover.contentViewController = controller  //set the content view controller for the popover to flutter view controller
    statusBar = StatusBarController.init(popover, controller)

    let keyboardControllerChannel = FlutterMethodChannel(
      name: "com.normadit.whistle/keyboardController",
      binaryMessenger: controller.engine.binaryMessenger)

    keyboardControllerChannel.setMethodCallHandler({
      (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
      if call.method == "insertText" {
        guard let args = call.arguments as? [String: Any],
          let text = args["text"] as? String
        else {
          result(
            FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
          return
        }
        self.insertText(text: text)
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    })
  }

  // Function to simulate text input on macOS
  func insertText(text: String) {
    let source = CGEventSource(stateID: .combinedSessionState)

    for char in text {
      let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true)
      let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)

      // Convert Character to [UniChar]
      let unichars = Array(String(char).utf16)
      unichars.withUnsafeBufferPointer { buffer in
        keyDown?.keyboardSetUnicodeString(
          stringLength: unichars.count, unicodeString: buffer.baseAddress)
        keyUp?.keyboardSetUnicodeString(
          stringLength: unichars.count, unicodeString: buffer.baseAddress)
      }

      keyDown?.post(tap: .cghidEventTap)
      keyUp?.post(tap: .cghidEventTap)
    }
  }

}
