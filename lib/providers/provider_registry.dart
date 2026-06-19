import 'elevenlabs_provider.dart';
import 'gemini_provider.dart';
import 'openai_provider.dart';
import 'transcription_provider.dart';

/// Single source of truth for the transcription backends Whistle supports.
///
/// The first entry is treated as the default active provider.
final List<TranscriptionProvider> providerRegistry = [
  OpenAiProvider(),
  ElevenLabsProvider(),
  GeminiProvider(),
];

/// Looks up a provider by its stable [id], falling back to the default.
TranscriptionProvider providerById(String? id) {
  return providerRegistry.firstWhere(
    (p) => p.id == id,
    orElse: () => providerRegistry.first,
  );
}

/// The default provider used before the user picks one.
TranscriptionProvider get defaultProvider => providerRegistry.first;
