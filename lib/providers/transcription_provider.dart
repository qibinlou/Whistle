import 'package:flutter/material.dart';

/// A selectable transcription model exposed by a provider.
class TranscriptionModel {
  final String id;
  final String label;
  final String description;

  const TranscriptionModel({
    required this.id,
    required this.label,
    this.description = '',
  });
}

/// The result of a successful transcription request.
class TranscriptionResult {
  final String text;
  final Duration latency;
  final String providerId;
  final String modelId;

  const TranscriptionResult({
    required this.text,
    required this.latency,
    required this.providerId,
    required this.modelId,
  });
}

/// Raised when a provider cannot complete a transcription. The [message] is
/// safe to surface directly to the user.
class TranscriptionException implements Exception {
  final String message;
  const TranscriptionException(this.message);

  @override
  String toString() => message;
}

/// Common contract every AI transcription backend implements. Adding a new
/// provider is as simple as implementing this interface and registering it in
/// [providerRegistry].
abstract class TranscriptionProvider {
  /// Stable identifier persisted in preferences (never localize/change).
  String get id;

  /// Human readable name shown in the UI.
  String get displayName;

  /// One-line description of the provider's strengths.
  String get description;

  /// SharedPreferences key under which this provider's API key is stored.
  String get apiKeyPrefKey;

  /// Placeholder shown in the API key field (illustrates the expected format).
  String get apiKeyHint;

  /// Where users can obtain an API key.
  String get consoleUrl;

  /// Brand-ish accent color used for chips, avatars and the playground.
  Color get accentColor;

  /// Icon representing the provider.
  IconData get icon;

  /// Models the user can pick from.
  List<TranscriptionModel> get models;

  /// Model used when none has been explicitly selected.
  String get defaultModelId;

  /// Transcribe the audio file at [filePath] using [apiKey].
  ///
  /// Implementations should throw a [TranscriptionException] with a friendly
  /// message on failure. [prompt] is an optional steering hint that some
  /// providers can use to improve punctuation/formatting.
  Future<TranscriptionResult> transcribe({
    required String filePath,
    required String apiKey,
    String? modelId,
    String? prompt,
  });

  /// Convenience accessor for the model that will actually be used.
  TranscriptionModel resolveModel(String? modelId) {
    return models.firstWhere(
      (m) => m.id == (modelId ?? defaultModelId),
      orElse: () => models.first,
    );
  }
}
