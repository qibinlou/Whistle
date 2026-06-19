import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'transcription_provider.dart';

/// Transcription via ElevenLabs Scribe speech-to-text models.
class ElevenLabsProvider extends TranscriptionProvider {
  @override
  String get id => 'elevenlabs';

  @override
  String get displayName => 'ElevenLabs';

  @override
  String get description =>
      'Scribe models with strong multilingual and noisy-audio performance.';

  @override
  String get apiKeyPrefKey => 'ELEVENLABS_API_KEY';

  @override
  String get apiKeyHint => 'Your xi-api-key';

  @override
  String get consoleUrl => 'https://elevenlabs.io/app/settings/api-keys';

  @override
  Color get accentColor => const Color(0xFF7C3AED);

  @override
  IconData get icon => Icons.graphic_eq_rounded;

  @override
  List<TranscriptionModel> get models => const [
        TranscriptionModel(
          id: 'scribe_v1',
          label: 'Scribe v1',
          description: 'Flagship accuracy with word-level timing.',
        ),
        TranscriptionModel(
          id: 'scribe_v1_experimental',
          label: 'Scribe v1 (Experimental)',
          description: 'Latest improvements, may change over time.',
        ),
      ];

  @override
  String get defaultModelId => 'scribe_v1';

  @override
  Future<TranscriptionResult> transcribe({
    required String filePath,
    required String apiKey,
    String? modelId,
    String? prompt,
  }) async {
    final model = resolveModel(modelId).id;
    final stopwatch = Stopwatch()..start();

    final url = Uri.parse('https://api.elevenlabs.io/v1/speech-to-text');
    final request = http.MultipartRequest('POST', url)
      ..fields['model_id'] = model
      ..files.add(await http.MultipartFile.fromPath('file', filePath));
    request.headers['xi-api-key'] = apiKey;

    try {
      final response = await request.send();
      final body = await response.stream.bytesToString();
      stopwatch.stop();

      if (response.statusCode == 200) {
        final text = (jsonDecode(body)['text'] as String?)?.trim() ?? '';
        return TranscriptionResult(
          text: text,
          latency: stopwatch.elapsed,
          providerId: id,
          modelId: model,
        );
      }
      throw TranscriptionException(_friendlyError(response.statusCode, body));
    } on TranscriptionException {
      rethrow;
    } catch (e) {
      throw TranscriptionException('Network error reaching ElevenLabs: $e');
    }
  }

  String _friendlyError(int status, String body) {
    String detail = body;
    try {
      final decoded = jsonDecode(body);
      detail = decoded['detail']?['message'] ?? decoded['detail'] ?? body;
    } catch (_) {/* keep raw body */}
    if (status == 401) {
      return 'Invalid ElevenLabs API key. Check your key in Settings.';
    }
    if (status == 429) {
      return 'ElevenLabs rate limit reached. Try again shortly.';
    }
    return 'ElevenLabs request failed ($status): $detail';
  }
}
