// ignore_for_file: constant_identifier_names

import 'package:audioplayers/audioplayers.dart';

const SOUND_START = "/System/Library/Sounds/Glass.aiff";
const SOUND_STOP = "/System/Library/Sounds/Blow.aiff";
const SOUND_ALERT = "/System/Library/Sounds/Submarine.aiff";

final class SoundController {
  static final _audioPlayer = AudioPlayer();

  SoundController._();

  static Future<void> playStartSound() async {
    _audioPlayer.play(DeviceFileSource(SOUND_START));
  }

  static Future<void> playStopSound() async {
    _audioPlayer.play(DeviceFileSource(SOUND_STOP));
  }
}
