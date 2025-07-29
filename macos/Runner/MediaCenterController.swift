import Carbon
import Cocoa
import CoreAudio
import FlutterMacOS
import MediaPlayer

// Fallback logging for macOS 10.15 compatibility
private func logInfo(_ message: String) {
  NSLog("[MediaCenterController] %@", message)
}

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
    case "isAudioPlaying":
      isAudioAudible(completion: result)
    case "muteSystemAudio":
      if let shouldMute = call.arguments as? Bool {
        muteSystemAudio(mute: shouldMute)
      }
      result(nil)
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

  func isAudioPlaying() -> Bool {
    if transportIsPlaying() { return true }
    return audibleOutput()
  }

  // MARK: – Public-API audio probe ------------------------------------------

  /// Combines Core Audio’s “device is running” flag with a short RMS probe
  /// so we don’t mistake silent WebAudio / VoiceOver / system beeps for music.
  private func isAudioAudible(
    threshold: Float = 0.0004,
    probeMillis: UInt32 = 20,
    completion: @escaping (Bool) -> Void
  ) {

    // ① cheap fast-path
    guard deviceIsRunningSomewhere() else {
      logInfo("No audio device running, returning false")
      completion(false)
      return
    }

    // ② tiny tap on the output mix
    let engine = AVAudioEngine()
    let mixer = engine.mainMixerNode
    var audible = false

    mixer.installTap(
      onBus: 0,
      bufferSize: 256,
      format: mixer.outputFormat(forBus: 0)
    ) { buf, _ in
      let ch = buf.floatChannelData![0]
      let n = Int(buf.frameLength)
      var sum: Float = 0
      for i in 0..<n { sum += ch[i] * ch[i] }
      let rms = sqrt(sum / Float(n))
      audible = rms > threshold
    }

    do { try engine.start() } catch {
      logInfo("RMS probe failed – falling back to ‘true’: \(error)")
      completion(true)  // be conservative if we can’t probe
      return
    }

    DispatchQueue.global().asyncAfter(
      deadline: .now() + .milliseconds(Int(probeMillis))
    ) {
      engine.stop()
      mixer.removeTap(onBus: 0)
      logInfo("RMS probe completed, audible: \(audible)")
      completion(audible)
    }
  }

  /// Core Audio flag: “is any client running an I/O proc on the default device?”
  private func deviceIsRunningSomewhere() -> Bool {
    var dev = AudioDeviceID(0)
    var sz = UInt32(MemoryLayout<AudioDeviceID>.size)
    var addr = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster)

    AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &addr, 0, nil, &sz, &dev)

    var running: UInt32 = 0
    sz = UInt32(MemoryLayout<UInt32>.size)
    addr.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere

    AudioObjectGetPropertyData(dev, &addr, 0, nil, &sz, &running)
    return running == 1
  }

  private func transportIsPlaying() -> Bool {
    if let rate = MPNowPlayingInfoCenter.default()
      .nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double
    {
      logInfo("Playback rate: \(rate)")
      return rate > 0.01  // 0 = paused / stopped, 1 = playing
    }
    return false  // no client registered
  }

  private func audibleOutput(threshold: Float = 0.0003) -> Bool {
    let engine = AVAudioEngine()
    let mixer = engine.mainMixerNode
    var audible = false

    mixer.installTap(
      onBus: 0,
      bufferSize: 256,
      format: mixer.outputFormat(forBus: 0)
    ) { buf, _ in
      let ch = buf.floatChannelData![0]
      let frames = Int(buf.frameLength)
      var sum: Float = 0
      for i in 0..<frames { sum += ch[i] * ch[i] }
      let rms = sqrt(sum / Float(frames))
      audible = rms > threshold
    }

    try? engine.start()
    usleep(10000)  // 10 ms probe
    engine.stop()
    mixer.removeTap(onBus: 0)
    return audible
  }

  private func hasAudibleAudioSignal(deviceID: AudioDeviceID) -> Bool {
    // Check if device has volume control and current volume level
    var addr = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: 1  // Left channel
    )

    var volume: Float32 = 0.0
    var size = UInt32(MemoryLayout<Float32>.size)

    let volumeStatus = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &volume)

    // If we can get volume and it's very low, consider it silent
    if volumeStatus == noErr {
      logInfo("Current volume level: \(volume)")
      if volume < 0.01 {  // Volume less than 1% is considered silent
        logInfo("Volume too low, treating as silent")
        return false
      }
    }

    // Check if device is muted
    addr.mSelector = kAudioDevicePropertyMute
    var isMuted: UInt32 = 0
    size = UInt32(MemoryLayout<UInt32>.size)

    let muteStatus = AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &isMuted)
    if muteStatus == noErr && isMuted != 0 {
      logInfo("Device is muted")
      return false
    }

    // If we reach here, device is running, has reasonable volume, and not muted
    logInfo("Device appears to have audible audio signal")
    return true
  }

  private func checkAudioDeviceRunning() -> Bool {
    // Get the default output device
    var deviceID = AudioDeviceID(0)
    var propSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )

    let status1 = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address, 0, nil, &propSize, &deviceID)

    logInfo("Get default output device status: \(status1), deviceID: \(deviceID)")
    guard status1 == noErr && deviceID != kAudioObjectUnknown else {
      logInfo("Failed to get default output device or device unknown")
      return false
    }

    // Check if device is actually running (not just available)
    var isRunning: UInt32 = 0
    propSize = UInt32(MemoryLayout<UInt32>.size)
    address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyDeviceIsRunning,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMaster
    )

    let status2 = AudioObjectGetPropertyData(
      deviceID,
      &address, 0, nil, &propSize, &isRunning)

    logInfo("Device running status: \(status2), isRunning: \(isRunning)")
    if status2 != noErr {
      logInfo("Failed to get device running status")
      return false
    }

    return isRunning != 0
  }

  // MARK: - Volume Management

  private var storedVolume: Float = 0.0

  private func muteSystemAudio(mute: Bool) {
    guard let defaultDevice = getDefaultOutputDevice() else {
      logInfo("Could not get default output device for volume control")
      return
    }

    if mute {
      // Store current volume before muting
      if let currentVolume = getDeviceVolume(deviceID: defaultDevice) {
        storedVolume = currentVolume
        logInfo("Stored system volume: \(currentVolume)")

        // Mute by setting volume to 0
        setDeviceVolume(deviceID: defaultDevice, volume: 0.0)
        logInfo("System audio muted")
      }
    } else {
      // Restore previous volume
      if storedVolume > 0 {
        setDeviceVolume(deviceID: defaultDevice, volume: storedVolume)
        logInfo("System audio unmuted, restored volume to: \(storedVolume)")
        storedVolume = 0.0
      }
    }
  }

  private func getDefaultOutputDevice() -> AudioDeviceID? {
    var deviceID = AudioDeviceID(0)
    var propSize = UInt32(MemoryLayout<AudioDeviceID>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioHardwarePropertyDefaultOutputDevice,
      mScope: kAudioObjectPropertyScopeGlobal,
      mElement: kAudioObjectPropertyElementMaster
    )

    let status = AudioObjectGetPropertyData(
      AudioObjectID(kAudioObjectSystemObject),
      &address, 0, nil, &propSize, &deviceID)

    if status != noErr || deviceID == kAudioObjectUnknown {
      logInfo("Failed to get default output device")
      return nil
    }

    return deviceID
  }

  private func getDeviceVolume(deviceID: AudioDeviceID) -> Float? {
    var volume: Float32 = 0.0
    var propSize = UInt32(MemoryLayout<Float32>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMaster
    )

    let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propSize, &volume)

    if status != noErr {
      logInfo("Failed to get device volume")
      return nil
    }

    return volume
  }

  private func setDeviceVolume(deviceID: AudioDeviceID, volume: Float) {
    var newVolume = Float32(volume)
    let propSize = UInt32(MemoryLayout<Float32>.size)
    var address = AudioObjectPropertyAddress(
      mSelector: kAudioDevicePropertyVolumeScalar,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMaster
    )

    let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, propSize, &newVolume)

    if status != noErr {
      logInfo("Failed to set device volume to \(volume)")
    } else {
      logInfo("Successfully set device volume to \(volume)")
    }
  }

}
