import Carbon
import Cocoa
import FlutterMacOS

/// Media center controller for handling all media-related operations
/// Manages media key events and provides a centralized interface for media control
public class MediaCenterController: NSObject, FlutterPlugin {

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "com.normadit.whistle/MediaCenter",
      binaryMessenger: registrar.messenger)
    let instance = MediaCenterController()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "playPause":
      sendPlayPause()
      result(nil)
    case "nextTrack":
      sendNextTrack()
      result(nil)
    case "previousTrack":
      sendPreviousTrack()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func sendPlayPause() {
    sendMediaKey(keyType: NX_KEYTYPE_PLAY)
  }

  private func sendNextTrack() {
    sendMediaKey(keyType: NX_KEYTYPE_NEXT)
  }

  private func sendPreviousTrack() {
    sendMediaKey(keyType: NX_KEYTYPE_PREVIOUS)
  }

  private func sendMediaKey(keyType: Int32) {
    let usage = Int(keyType)

    func postEvent(down: Bool) {
      let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
      let data1 = (usage << 16) | ((down ? 0xA : 0xB) << 8)

      if let event = NSEvent.otherEvent(
        with: .systemDefined,
        location: .zero,
        modifierFlags: flags,
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: 0,
        context: nil,
        subtype: 8,
        data1: data1,
        data2: -1
      ) {
        event.cgEvent?.post(tap: .cghidEventTap)
      }
    }

    postEvent(down: true)
    postEvent(down: false)
  }
}
