import MediaPlayer

let nc = MPNowPlayingInfoCenter.default()
var info = [String: Any]()
info[MPMediaItemPropertyTitle] = "Test Tone"
info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0  // playing
nc.nowPlayingInfo = info
nc.playbackState = .playing  // macOS only

let playbackRate =
  MPNowPlayingInfoCenter.default()
  .nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] as? Double

print("Playback rate: \(playbackRate ?? 0.0)")

let nowPlaybackState =
  MPNowPlayingInfoCenter.default()
  .playbackState

print("Now Playback State: \(nowPlaybackState)")
