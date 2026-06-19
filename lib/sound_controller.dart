// ignore_for_file: constant_identifier_names

import 'package:audioplayers/audioplayers.dart';

const SOUND_START = "/System/Library/Sounds/Glass.aiff";
const SOUND_STOP = "/System/Library/Sounds/Blow.aiff";
const SOUND_ALERT = "/System/Library/Sounds/Submarine.aiff";

final class SoundController {
  static final _audioPlayer = AudioPlayer();

  SoundController._();

  static Future<void> playStartSound() async {
    return _audioPlayer.play(
      DeviceFileSource(SOUND_START),
      mode: PlayerMode.lowLatency,
    );
  }

  static Future<void> playStopSound() async {
    return _audioPlayer.play(
      DeviceFileSource(SOUND_STOP),
      mode: PlayerMode.lowLatency,
    );
  }

  static Future<void> playAlertSound() async {
    return _audioPlayer.play(
      DeviceFileSource(SOUND_ALERT),
      mode: PlayerMode.lowLatency,
    );
  }
}
