import 'package:shared_preferences/shared_preferences.dart';

import '../providers/provider_registry.dart';
import '../providers/transcription_provider.dart';

/// Thin, typed wrapper around [SharedPreferences] for the settings Whistle
/// persists. Keeps preference keys in one place so screens and controllers
/// never disagree about naming.
class AppSettings {
  AppSettings._();

  static const _kSelectedProvider = 'selected_provider_id';
  static const _kModelPrefix = 'selected_model_';

  // Dictation behaviour keys (kept compatible with earlier versions).
  static const kEnableDictation = 'enableDictation';
  static const kHotkeyIndex = 'hotkey_option_index';
  static const kPlaySounds = 'playDictationSounds';
  static const kPauseMusic = 'pauseMusicDuringDictation';

  /// Steering prompt sent to providers that support it.
  static const transcriptionPrompt =
      'Ensure that grammar is corrected where necessary and punctuation is '
      'added to create a clean and polished transcript.';

  static Future<SharedPreferences> get _prefs =>
      SharedPreferences.getInstance();

  // ---- Active provider ------------------------------------------------------

  static Future<TranscriptionProvider> activeProvider() async {
    final prefs = await _prefs;
    return providerById(prefs.getString(_kSelectedProvider));
  }

  static Future<void> setActiveProvider(String providerId) async {
    final prefs = await _prefs;
    await prefs.setString(_kSelectedProvider, providerId);
  }

  // ---- Per-provider model selection ----------------------------------------

  static Future<String> selectedModelId(TranscriptionProvider provider) async {
    final prefs = await _prefs;
    return prefs.getString('$_kModelPrefix${provider.id}') ??
        provider.defaultModelId;
  }

  static Future<void> setSelectedModel(
      TranscriptionProvider provider, String modelId) async {
    final prefs = await _prefs;
    await prefs.setString('$_kModelPrefix${provider.id}', modelId);
  }

  // ---- API keys -------------------------------------------------------------

  static Future<String> apiKey(TranscriptionProvider provider) async {
    final prefs = await _prefs;
    return prefs.getString(provider.apiKeyPrefKey) ?? '';
  }

  static Future<void> setApiKey(
      TranscriptionProvider provider, String key) async {
    final prefs = await _prefs;
    await prefs.setString(provider.apiKeyPrefKey, key.trim());
  }

  static Future<bool> hasApiKey(TranscriptionProvider provider) async {
    return (await apiKey(provider)).isNotEmpty;
  }
}
