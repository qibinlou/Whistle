import AVFoundation
import Carbon
import Cocoa
import CoreAudio
import MediaPlayer

// Fallback logging for macOS 10.15 compatibility
private func logInfo(_ message: String) {
  NSLog("[MediaCenterController] %@", message)
}

// Global variable to store the original volume for restoration
private var storedSystemVolume: Float32?

print("Audio device running: \(checkAudioDeviceRunning())")
print("System audio active: \(isSystemAudioActive())")
print("System audio active (improved): \(isSystemAudioActiveImproved())")
print("System audio active (direct hardware): \(isSystemAudioActiveDirectHardware())")
print("System audio active (cache refresh): \(isSystemAudioActiveWithCacheRefresh())")

let SOUND_START = "/System/Library/Sounds/Glass.aiff"
let SOUND_STOP = "/System/Library/Sounds/Blow.aiff"
let SOUND_ALERT = "/System/Library/Sounds/Submarine.aiff"

// Test muting functionality
print("\n--- Testing Mute Functionality ---")

let audioHelper = AudioHelper()

print("Playing start sound BEFORE muting...")
audioHelper.playSystemSound(SOUND_START)

sleep(UInt32(1))  // Wait for sound to finish

print("Muting system audio...")
muteActiveSoundtracks()

sleep(UInt32(1))  // Wait for muting to take effect

print("Playing start sound AFTER muting (should still be audible)...")
audioHelper.playSystemSound(SOUND_ALERT)

print("Waiting 3 seconds before restoring...")
sleep(UInt32(3))

print("Restoring system audio...")
unmuteActiveSoundtracks()

audioHelper.playSystemSound(SOUND_STOP)

print("Audio restored - test complete")

// tesitng conclusion: ~5s delay due to system caching?

// Method to force flush Core Audio property cache
private func flushAudioPropertyCache(deviceID: AudioDeviceID) {
  // Force cache invalidation by querying multiple properties rapidly
  var dummy: UInt32 = 0
  var size = UInt32(MemoryLayout<UInt32>.size)

  let properties: [AudioObjectPropertySelector] = [
    kAudioDevicePropertyDeviceIsRunning,
    kAudioDevicePropertyDeviceIsRunningSomewhere,
    kAudioDevicePropertyStreamConfiguration,
    kAudioDevicePropertyNominalSampleRate,
  ]

  for property in properties {
    var addr = AudioObjectPropertyAddress(
      mSelector: property,
      mScope: kAudioDevicePropertyScopeOutput,
      mElement: kAudioObjectPropertyElementMain
    )
    // Force read multiple times to invalidate cache
    AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &dummy)
    AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &dummy)
  }
}

// Improved version with cache flushing
private func isSystemAudioActiveImproved() -> Bool {
  // 1. Get default output device with error handling
  var dev = AudioDeviceID(0)
  var size = UInt32(MemoryLayout<AudioDeviceID>.size)
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain)  // Keep Main for compatibility

  let status1 = AudioObjectGetPropertyData(
    AudioObjectID(kAudioObjectSystemObject),
    &addr, 0, nil, &size, &dev)

  guard status1 == noErr && dev != kAudioObjectUnknown else {
    logInfo("Failed to get default output device")
    return false
  }

  // 2. Force flush property cache before checking
  flushAudioPropertyCache(deviceID: dev)

  // 3. Check multiple audio states for better accuracy
  var running: UInt32 = 0
  size = UInt32(MemoryLayout<UInt32>.size)
  addr.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere

  let status2 = AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running)
  guard status2 == noErr else {
    logInfo("Failed to get device running status")
    return false
  }

  let isRunningSomewhere = running == 1

  // 4. Also check if device is actively running (more immediate state)
  var activelyRunning: UInt32 = 0
  addr.mSelector = kAudioDevicePropertyDeviceIsRunning
  addr.mScope = kAudioDevicePropertyScopeOutput

  let status3 = AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &activelyRunning)
  let isActivelyRunning = (status3 == noErr) && (activelyRunning != 0)

  logInfo("Running somewhere: \(isRunningSomewhere), Actively running: \(isActivelyRunning)")

  // Return true if either condition is met
  return isRunningSomewhere || isActivelyRunning
}

// Method 2: Property Listener Approach (most responsive)
private func audioPropertyListener(
  objectID: AudioObjectID,
  numAddresses: UInt32,
  addresses: UnsafePointer<AudioObjectPropertyAddress>,
  clientData: UnsafeMutableRawPointer?
) -> OSStatus {
  logInfo("Audio property changed - cache invalidated")
  return noErr
}

private func setupAudioPropertyListener(deviceID: AudioDeviceID) {
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
    mScope: kAudioDevicePropertyScopeOutput,
    mElement: kAudioObjectPropertyElementMain
  )

  AudioObjectAddPropertyListener(deviceID, &addr, audioPropertyListener, nil)
}

// Method 3: Direct hardware query (bypasses most caching)
private func isSystemAudioActiveDirectHardware() -> Bool {
  var dev = AudioDeviceID(0)
  var size = UInt32(MemoryLayout<AudioDeviceID>.size)
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain)

  AudioObjectGetPropertyData(
    AudioObjectID(kAudioObjectSystemObject),
    &addr, 0, nil, &size, &dev)

  guard dev != kAudioObjectUnknown else { return false }

  // Query stream configuration directly (less cached than running state)
  var streamConfig: AudioBufferList = AudioBufferList()
  size = UInt32(MemoryLayout<AudioBufferList>.size)
  addr = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyStreamConfiguration,
    mScope: kAudioDevicePropertyScopeOutput,
    mElement: kAudioObjectPropertyElementMain
  )

  let configStatus = AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &streamConfig)

  // If we can get stream config, device is likely active
  if configStatus == noErr && streamConfig.mNumberBuffers > 0 {
    // Double-check with immediate running state
    var running: UInt32 = 0
    size = UInt32(MemoryLayout<UInt32>.size)
    addr.mSelector = kAudioDevicePropertyDeviceIsRunning

    AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running)
    return running != 0
  }

  return false
}

// Method 4: Multi-query with timing (force cache refresh)
private func isSystemAudioActiveWithCacheRefresh() -> Bool {
  var dev = AudioDeviceID(0)
  var size = UInt32(MemoryLayout<AudioDeviceID>.size)
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain)

  AudioObjectGetPropertyData(
    AudioObjectID(kAudioObjectSystemObject),
    &addr, 0, nil, &size, &dev)

  guard dev != kAudioObjectUnknown else { return false }

  // Force multiple rapid queries to bypass cache
  var running: UInt32 = 0
  size = UInt32(MemoryLayout<UInt32>.size)
  addr.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere

  // Query 3 times rapidly - often the 2nd or 3rd query gets fresh data
  AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running)
  usleep(1000)  // 1ms
  AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running)
  usleep(1000)  // 1ms
  AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running)

  return running == 1
}

private func isSystemAudioActive() -> Bool {
  // 1. Get default output device.
  var dev = AudioDeviceID(0)
  var size = UInt32(MemoryLayout<AudioDeviceID>.size)
  var addr = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain)

  AudioObjectGetPropertyData(
    AudioObjectID(kAudioObjectSystemObject),
    &addr, 0, nil, &size, &dev)

  // 2. Check “running somewhere”.
  var running: UInt32 = 0
  size = UInt32(MemoryLayout<UInt32>.size)
  addr.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere

  AudioObjectGetPropertyData(dev, &addr, 0, nil, &size, &running)
  return running == 1
}

private func checkAudioDeviceRunning() -> Bool {
  // Get the default output device
  var deviceID = AudioDeviceID(0)
  var propSize = UInt32(MemoryLayout<AudioDeviceID>.size)
  var address = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
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
    mElement: kAudioObjectPropertyElementMain
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

private func muteActiveSoundtracks() {
  logInfo("Starting to mute active soundtracks")

  // Only reduce system volume slightly if needed
  // This preserves your dictation sounds while quieting background audio
  if isSystemAudioActive() {
    reduceSystemVolumeSlightly()
  }

  logInfo("Finished muting active soundtracks")
}

// New function: reduce volume slightly instead of aggressive muting
private func reduceSystemVolumeSlightly() {
  guard let defaultDevice = getDefaultOutputDevice() else {
    logInfo("Could not get default output device for volume reduction")
    return
  }

  // Store current volume for restoration later
  if let currentVolume = getDeviceVolume(deviceID: defaultDevice) {

    logInfo("Stored system volume: \(currentVolume)")

    // Only reduce if volume is high enough
    if currentVolume > 0.1 {
      let reducedVolume: Float32 = currentVolume * 0.3  // Reduce to 30% of current
      setDeviceVolume(deviceID: defaultDevice, volume: reducedVolume)
      logInfo("System volume reduced from \(currentVolume) to \(reducedVolume)")
    } else {
      logInfo("System volume already low (\(currentVolume)), not reducing further")
    }
  }
}

// MARK: - Audio Control Explanations

/*
SYSTEM AUDIO CONTROL - BEST FOR WHISTLE:
- Reduces system-wide audio mixer output to very low level
- Allows NEW audio (your dictation sounds) to play at full volume
- Existing audio becomes very quiet but isn't completely blocked
- Your app's sounds will play normally over the quieted background
*/
private func muteSystemVolume() {
  guard let defaultDevice = getDefaultOutputDevice() else {
    logInfo("Could not get default output device for muting")
    return
  }

  // Store current volume for restoration later
  if let currentVolume = getDeviceVolume(deviceID: defaultDevice) {
    logInfo("Stored system volume: \(currentVolume)")
  }

  // Set system volume to very low (not 0) - allows new sounds to play
  let mutedVolume: Float32 = 0.05  // 5% volume - quiet but not silent
  setDeviceVolume(deviceID: defaultDevice, volume: mutedVolume)
  logInfo("System volume reduced to \(mutedVolume) - existing audio quieted, new sounds can play")
}

/*
APPLICATION-LEVEL CONTROL:
- Sends control commands to individual applications
- Uses media key simulation (play/pause/stop)
- Only affects apps that respond to media keys
- Doesn't affect system sounds or non-media apps
*/
private func pauseMediaPlayers() {
  // Send pause command via media keys
  sendMediaKeyCommand(keyCode: NX_KEYTYPE_PLAY)  // Play/Pause toggle
  logInfo("Sent pause command to media players - only affects media apps")
}

/*
AUDIO DEVICE CONTROL:
- Controls the hardware device's mute state
- Uses kAudioDevicePropertyMute
- Hardware-level muting (lower level than system volume)
- Like pressing a physical mute button on speakers
*/
private func muteAudioDevices() {
  guard let defaultDevice = getDefaultOutputDevice() else { return }

  // Hardware-level mute of the actual output device
  setDeviceMute(deviceID: defaultDevice, isMuted: true)
  logInfo("Default audio device muted - hardware-level silence")
}

// MARK: - Helper Functions

private func getDefaultOutputDevice() -> AudioDeviceID? {
  var deviceID = AudioDeviceID(0)
  var size = UInt32(MemoryLayout<AudioDeviceID>.size)
  var address = AudioObjectPropertyAddress(
    mSelector: kAudioHardwarePropertyDefaultOutputDevice,
    mScope: kAudioObjectPropertyScopeGlobal,
    mElement: kAudioObjectPropertyElementMain
  )

  let status = AudioObjectGetPropertyData(
    AudioObjectID(kAudioObjectSystemObject),
    &address, 0, nil, &size, &deviceID)

  guard status == noErr && deviceID != kAudioObjectUnknown else {
    logInfo("Failed to get default output device")
    return nil
  }

  return deviceID
}

private func getDeviceVolume(deviceID: AudioDeviceID) -> Float32? {
  var volume: Float32 = 0.0
  var size = UInt32(MemoryLayout<Float32>.size)
  var address = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyVolumeScalar,
    mScope: kAudioDevicePropertyScopeOutput,
    mElement: kAudioObjectPropertyElementMain
  )

  let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &volume)

  if status == noErr {
    return volume
  } else {
    logInfo("Failed to get device volume, status: \(status)")
    return nil
  }
}

private func setDeviceVolume(deviceID: AudioDeviceID, volume: Float32) {
  var newVolume = volume
  let size = UInt32(MemoryLayout<Float32>.size)
  var address = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyVolumeScalar,
    mScope: kAudioDevicePropertyScopeOutput,
    mElement: kAudioObjectPropertyElementMain
  )

  let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &newVolume)

  if status != noErr {
    logInfo("Failed to set device volume, status: \(status)")
  }
}

private func setDeviceMute(deviceID: AudioDeviceID, isMuted: Bool) {
  var muteValue: UInt32 = isMuted ? 1 : 0
  let size = UInt32(MemoryLayout<UInt32>.size)
  var address = AudioObjectPropertyAddress(
    mSelector: kAudioDevicePropertyMute,
    mScope: kAudioDevicePropertyScopeOutput,
    mElement: kAudioObjectPropertyElementMain
  )

  let status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, size, &muteValue)

  if status != noErr {
    logInfo("Failed to set device mute state, status: \(status)")
  }
}

private func sendMediaKeyCommand(keyCode: Int32) {
  let usage = Int(keyCode)

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

// MARK: - Unmute Functions (for restoration)

private func unmuteActiveSoundtracks() {
  logInfo("Restoring audio state")

  guard let defaultDevice = getDefaultOutputDevice() else { return }

  var storedSystemVolume = Optional(Float32(0.5))

  // Restore the original volume level
  if let originalVolume = storedSystemVolume {
    setDeviceVolume(deviceID: defaultDevice, volume: originalVolume)
    logInfo("System volume restored to: \(originalVolume)")
    storedSystemVolume = nil  // Clear stored volume
  } else {
    // Fallback: set to a reasonable default if we don't have stored volume
    setDeviceVolume(deviceID: defaultDevice, volume: 0.7)  // 70% volume
    logInfo("System volume restored to default: 0.7")
  }

  logInfo("Audio state restored")
}

// MARK: - Whistle-Specific Audio Functions

/*
For Whistle dictation workflow:
1. Call muteActiveSoundtracks() when starting dictation
2. Play your start sound (will play at full volume)
3. Record speech
4. Play your stop sound (will play at full volume)
5. Call unmuteActiveSoundtracks() when done
*/
private func startDictationAudioSetup() {
  logInfo("Setting up audio for dictation")
  muteActiveSoundtracks()

  // Your dictation start sound would play here
  // playDictationStartSound()
}

private func endDictationAudioSetup() {
  logInfo("Cleaning up audio after dictation")

  // Your dictation stop sound would play here
  // playDictationStopSound()

  // Small delay to ensure stop sound finishes before restoring volume
  DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
    unmuteActiveSoundtracks()
  }
}

// MARK: - Audio Helper Class

class AudioHelper {
  private var audioPlayer: AVAudioPlayer?

  public func playSystemSound(_ soundPath: String) {
    // Use NSSound for macOS - it bypasses system volume controls better
    playSystemSoundDirect(soundPath)
  }

  // macOS-specific method using NSSound (bypasses system volume reduction)
  public func playSystemSoundDirect(_ soundPath: String) {
    if let sound = NSSound(contentsOfFile: soundPath, byReference: false) {
      sound.volume = 1.0  // Full volume - independent of system volume
      let result = sound.play()
      print("Playing sound with NSSound: \(soundPath), result: \(result), volume: 1.0")
    } else {
      print("Failed to create NSSound from: \(soundPath)")
    }
  }

  // Alternative using AVAudioPlayer with manual volume boost
  public func playSystemSoundWithAVPlayer(_ soundPath: String) {
    let url = URL(fileURLWithPath: soundPath)
    do {
      audioPlayer = try AVAudioPlayer(contentsOf: url)

      // Set volume to maximum for dictation sounds
      audioPlayer?.volume = 1.0

      let result = audioPlayer?.play() ?? false
      print(
        "Playing sound with AVAudioPlayer: \(soundPath), result: \(result), volume: \(audioPlayer?.volume ?? 0)"
      )
    } catch {
      print("Failed to play sound: \(error)")
    }
  }
}
