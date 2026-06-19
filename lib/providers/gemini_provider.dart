import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'transcription_provider.dart';

/// Transcription via Google Gemini's multimodal audio understanding.
class GeminiProvider extends TranscriptionProvider {
  @override
  String get id => 'gemini';

  @override
  String get displayName => 'Google Gemini';

  @override
  String get description =>
      'Multimodal Gemini models with excellent contextual transcription.';

  @override
  String get apiKeyPrefKey => 'GEMINI_API_KEY';

  @override
  String get apiKeyHint => 'AIza...';

  @override
  String get consoleUrl => 'https://aistudio.google.com/app/apikey';

  @override
  Color get accentColor => const Color(0xFF4285F4);

  @override
  IconData get icon => Icons.blur_on_rounded;

  @override
  List<TranscriptionModel> get models => const [
        TranscriptionModel(
          id: 'gemini-2.5-flash',
          label: 'Gemini 2.5 Flash',
          description: 'Fast, capable and cost-effective default.',
        ),
        TranscriptionModel(
          id: 'gemini-2.5-pro',
          label: 'Gemini 2.5 Pro',
          description: 'Highest reasoning quality for tricky audio.',
        ),
        TranscriptionModel(
          id: 'gemini-2.0-flash',
          label: 'Gemini 2.0 Flash',
          description: 'Previous generation, broadly available.',
        ),
      ];

  @override
  String get defaultModelId => 'gemini-2.5-flash';

  @override
  Future<TranscriptionResult> transcribe({
    required String filePath,
    required String apiKey,
    String? modelId,
    String? prompt,
  }) async {
    final model = resolveModel(modelId).id;
    final stopwatch = Stopwatch()..start();

    final bytes = await File(filePath).readAsBytes();
    final audioBase64 = base64Encode(bytes);

    final instruction = (prompt != null && prompt.isNotEmpty)
        ? prompt
        : 'Transcribe this audio verbatim. Return only the spoken text with '
            'natural punctuation and capitalization, no commentary.';

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final payload = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': instruction},
            {
              'inline_data': {
                'mime_type': _mimeForPath(filePath),
                'data': audioBase64,
              }
            },
          ]
        }
      ],
      'generationConfig': {'temperature': 0.0},
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: payload,
      );
      stopwatch.stop();

      if (response.statusCode == 200) {
        return TranscriptionResult(
          text: _extractText(response.body),
          latency: stopwatch.elapsed,
          providerId: id,
          modelId: model,
        );
      }
      throw TranscriptionException(
          _friendlyError(response.statusCode, response.body));
    } on TranscriptionException {
      rethrow;
    } catch (e) {
      throw TranscriptionException('Network error reaching Gemini: $e');
    }
  }

  String _extractText(String body) {
    final decoded = jsonDecode(body);
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const TranscriptionException(
          'Gemini returned no transcription candidates.');
    }
    final parts = candidates.first['content']?['parts'] as List?;
    if (parts == null || parts.isEmpty) {
      throw const TranscriptionException('Gemini returned an empty response.');
    }
    final buffer = StringBuffer();
    for (final part in parts) {
      final text = part['text'];
      if (text is String) buffer.write(text);
    }
    return buffer.toString().trim();
  }

  String _mimeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mp3';
    if (lower.endsWith('.m4a') || lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.flac')) return 'audio/flac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    return 'audio/wav';
  }

  String _friendlyError(int status, String body) {
    String detail = body;
    try {
      final decoded = jsonDecode(body);
      detail = decoded['error']?['message'] ?? body;
    } catch (_) {/* keep raw body */}
    if (status == 400 && detail.contains('API key')) {
      return 'Invalid Gemini API key. Check your key in Settings.';
    }
    if (status == 429) return 'Gemini rate limit reached. Try again shortly.';
    return 'Gemini request failed ($status): $detail';
  }
}
