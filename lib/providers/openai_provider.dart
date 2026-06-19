import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'transcription_provider.dart';

/// Transcription via OpenAI's audio models (`gpt-4o-transcribe`, Whisper).
class OpenAiProvider extends TranscriptionProvider {
  @override
  String get id => 'openai';

  @override
  String get displayName => 'OpenAI';

  @override
  String get description =>
      'Industry-leading accuracy with gpt-4o-transcribe and Whisper.';

  @override
  String get apiKeyPrefKey => 'OPENAI_API_KEY';

  @override
  String get apiKeyHint => 'sk-...';

  @override
  String get consoleUrl => 'https://platform.openai.com/api-keys';

  @override
  Color get accentColor => const Color(0xFF10A37F);

  @override
  IconData get icon => Icons.auto_awesome_rounded;

  @override
  List<TranscriptionModel> get models => const [
        TranscriptionModel(
          id: 'gpt-4o-transcribe',
          label: 'GPT-4o Transcribe',
          description: 'Highest accuracy, best for clean punctuation.',
        ),
        TranscriptionModel(
          id: 'gpt-4o-mini-transcribe',
          label: 'GPT-4o mini Transcribe',
          description: 'Faster and cheaper, great everyday quality.',
        ),
        TranscriptionModel(
          id: 'whisper-1',
          label: 'Whisper v1',
          description: 'Classic open Whisper model, broad language support.',
        ),
      ];

  @override
  String get defaultModelId => 'gpt-4o-transcribe';

  @override
  Future<TranscriptionResult> transcribe({
    required String filePath,
    required String apiKey,
    String? modelId,
    String? prompt,
  }) async {
    final model = resolveModel(modelId).id;
    final stopwatch = Stopwatch()..start();

    final url = Uri.parse('https://api.openai.com/v1/audio/transcriptions');
    final request = http.MultipartRequest('POST', url)
      ..fields['model'] = model
      ..files.add(await http.MultipartFile.fromPath('file', filePath));

    if (prompt != null && prompt.isNotEmpty) {
      request.fields['prompt'] = prompt;
    }
    request.headers['Authorization'] = 'Bearer $apiKey';

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
      throw TranscriptionException('Network error reaching OpenAI: $e');
    }
  }

  String _friendlyError(int status, String body) {
    String detail = body;
    try {
      final decoded = jsonDecode(body);
      detail = decoded['error']?['message'] ?? body;
    } catch (_) {/* keep raw body */}
    if (status == 401) {
      return 'Invalid OpenAI API key. Check your key in Settings.';
    }
    if (status == 429) {
      return 'OpenAI rate limit reached. Try again shortly.';
    }
    return 'OpenAI request failed ($status): $detail';
  }
}
