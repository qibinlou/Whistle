import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import '../chinese_utils.dart';
import '../hotkey_options.dart';
import '../keyboard_controller.dart';
import '../providers/transcription_provider.dart';
import '../sound_controller.dart';
import 'app_settings.dart';

/// A single completed dictation, kept for the session history view.
class TranscriptionEntry {
  final String text;
  final String providerId;
  final String modelId;
  final DateTime timestamp;

  TranscriptionEntry({
    required this.text,
    required this.providerId,
    required this.modelId,
    required this.timestamp,
  });
}

enum DictationStatus { idle, recording, transcribing }

/// Owns all dictation behaviour: hotkey registration, audio capture,
/// transcription through the active provider, and inserting text at the
/// cursor. UI listens via [ChangeNotifier] so multiple screens stay in sync.
class DictationController extends ChangeNotifier {
  final AudioRecorder _recorder;

  DictationController({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  static const _statusBarChannel =
      MethodChannel('com.normadit.whistle/StatusBarController');
  static const _mediaCenterChannel =
      MethodChannel('com.normadit.whistle/MediaCenter');

  DictationStatus status = DictationStatus.idle;
  String? _recordingPath;
  bool _hasMutedSystemAudio = false;
  String? lastError;

  final List<TranscriptionEntry> history = [];

  /// Invoked when the active provider has no API key configured, so the UI can
  /// guide the user to Settings.
  VoidCallback? onNeedsApiKey;

  bool get isRecording => status == DictationStatus.recording;
  bool get isBusy => status != DictationStatus.idle;

  Future<void> init() async {
    await registerHotkey();
    _statusBarChannel.setMethodCallHandler((call) async {
      if (call.method == 'toggleVoiceInput') await toggle();
    });
  }

  void _setStatus(DictationStatus next) {
    status = next;
    notifyListeners();
    _statusBarChannel.invokeMethod('updateStatusBarIcon', isRecording);
  }

  /// (Re)registers the system-wide hotkey from the saved preference.
  Future<void> registerHotkey() async {
    await hotKeyManager.unregisterAll();
    final index = await _currentHotkeyIndex();
    try {
      final option = hotkeyOptions[index];
      await hotKeyManager.register(
        HotKey(
          key: option.key,
          modifiers: option.modifiers,
          scope: HotKeyScope.system,
        ),
        keyDownHandler: (_) => toggle(),
      );
    } catch (e) {
      debugPrint('Error registering hotkey: $e');
    }
  }

  Future<int> _currentHotkeyIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(AppSettings.kHotkeyIndex) ?? 0;
    return (stored >= 0 && stored < hotkeyOptions.length) ? stored : 0;
  }

  Future<String> currentShortcutLabel() async {
    return hotkeyOptions[await _currentHotkeyIndex()].shortcutString;
  }

  /// Toggles recording on/off. Stopping triggers transcription + insertion.
  Future<void> toggle() async {
    if (!isRecording) {
      await _startRecording();
    } else {
      await _stopAndTranscribe();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) return;

      final prefs = await SharedPreferences.getInstance();

      if (prefs.getBool(AppSettings.kPlaySounds) ?? true) {
        SoundController.playStartSound();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (prefs.getBool(AppSettings.kPauseMusic) ?? true) {
        try {
          await _mediaCenterChannel.invokeMethod('muteSystemAudio', true);
          _hasMutedSystemAudio = true;
        } catch (e) {
          _hasMutedSystemAudio = false;
          debugPrint('Failed to mute system audio: $e');
        }
      } else {
        _hasMutedSystemAudio = false;
      }

      final supportDir = await getApplicationSupportDirectory();
      await supportDir.create(recursive: true);
      final suffix = Random().nextInt(1000000).toString().padLeft(6, '0');
      _recordingPath = '${supportDir.path}/voice_input_$suffix.wav';
      debugPrint('Saving recorded audio to: $_recordingPath');
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.wav),
        path: _recordingPath!,
      );
      lastError = null;
      _setStatus(DictationStatus.recording);
    } catch (e) {
      lastError = 'Could not start recording: $e';
      _setStatus(DictationStatus.idle);
    }
  }

  Future<void> _stopAndTranscribe() async {
    try {
      await _recorder.stop();
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(AppSettings.kPlaySounds) ?? true) {
        SoundController.playStopSound();
      }
      if (_hasMutedSystemAudio) {
        try {
          await _mediaCenterChannel.invokeMethod('muteSystemAudio', false);
        } catch (e) {
          debugPrint('Failed to unmute system audio: $e');
        }
      }
      _hasMutedSystemAudio = false;
    } catch (e) {
      debugPrint('Error stopping recording: $e');
    }

    final path = _recordingPath;
    if (path == null) {
      _setStatus(DictationStatus.idle);
      return;
    }

    _setStatus(DictationStatus.transcribing);

    try {
      final provider = await AppSettings.activeProvider();
      final apiKey = await AppSettings.apiKey(provider);
      if (apiKey.isEmpty) {
        lastError = '${provider.displayName} API key is not set.';
        await windowManager.show();
        await windowManager.focus();
        onNeedsApiKey?.call();
        return;
      }

      final modelId = await AppSettings.selectedModelId(provider);
      final result = await provider.transcribe(
        filePath: path,
        apiKey: apiKey,
        modelId: modelId,
        prompt: AppSettings.transcriptionPrompt,
      );
      final processed = _postProcess(result.text);
      await _insertTextAtCursor(processed);
      history.insert(
        0,
        TranscriptionEntry(
          text: processed,
          providerId: provider.id,
          modelId: result.modelId,
          timestamp: DateTime.now(),
        ),
      );
      lastError = null;
    } on TranscriptionException catch (e) {
      lastError = e.message;
      SoundController.playAlertSound();
    } catch (e) {
      lastError = 'Transcription failed: $e';
      SoundController.playAlertSound();
    } finally {
      _setStatus(DictationStatus.idle);
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting temporary audio recording: $e');
      }
    }
  }

  String _postProcess(String text) {
    if (containsChineseCharacters(text)) {
      return text
          .replaceAll(',', '，')
          .replaceAll('.', '。')
          .replaceAll('?', '？')
          .replaceAll('!', '！')
          .replaceAll(';', '；')
          .replaceAll(':', '：');
    }
    return text;
  }

  Future<void> _insertTextAtCursor(String text) async {
    if (text.isEmpty) return;
    await MacOSKeyboardController.insertText(text);
  }

  void clearHistory() {
    history.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _recorder.dispose();
    hotKeyManager.unregisterAll();
    super.dispose();
  }
}
