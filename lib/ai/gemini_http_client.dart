import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';
import 'gemini_config.dart';
import 'gemini_exceptions.dart';

class GeminiHttpClient {
  GeminiHttpClient._();
  static final GeminiHttpClient instance = GeminiHttpClient._();

  final http.Client _client = http.Client();

  Future<String> call({
    required String prompt,
    double          temperature = GeminiConfig.intentTemperature,
    int             maxTokens   = GeminiConfig.intentMaxTokens,
    int             timeoutSecs = GeminiConfig.intentTimeoutSeconds,
  }) async {
    final apiKey = await _readKey();
    final url    = Uri.parse('${GeminiConfig.baseUrl}?key=$apiKey');
    final body   = _buildBody(prompt, temperature, maxTokens);

    // ── TEMPORARY DEBUG ───────────────────────────────────
    debugPrint('═══════════════════════════════════════');
    debugPrint('GEMINI URL   : ${GeminiConfig.baseUrl}');
    debugPrint('GEMINI MODEL : ${GeminiConfig.model}');
    debugPrint('GEMINI KEY   : ${apiKey.length > 12 ? '${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)}' : 'TOO_SHORT'}');
    debugPrint('═══════════════════════════════════════');
    // ─────────────────────────────────────────────────────

    http.Response response;
    try {
      response = await _client
          .post(url, headers: _headers, body: body)
          .timeout(Duration(seconds: timeoutSecs));
    } on Exception catch (e) {
      final msg = e.toString();
      debugPrint('GEMINI NETWORK ERROR: $msg');
      if (msg.contains('TimeoutException') || msg.contains('timeout')) {
        throw const GeminiTimeoutException();
      }
      throw const GeminiTimeoutException();
    }

    return _handleResponse(response, retried: false,
        prompt: prompt, temperature: temperature,
        maxTokens: maxTokens, timeoutSecs: timeoutSecs);
  }

  Future<String> _handleResponse(
      http.Response response, {
        required bool   retried,
        required String prompt,
        required double temperature,
        required int    maxTokens,
        required int    timeoutSecs,
      }) async {
    final code = response.statusCode;

    // ── TEMPORARY DEBUG ───────────────────────────────────
    debugPrint('═══════════════════════════════════════');
    debugPrint('GEMINI HTTP CODE : $code');
    debugPrint('GEMINI RESPONSE  : ${response.body.length > 600 ? response.body.substring(0, 600) : response.body}');
    debugPrint('═══════════════════════════════════════');
    // ─────────────────────────────────────────────────────

    if (code == 200) return _extractText(response);

    if ((code == 500 || code == 503) && !retried) {
      await Future.delayed(Duration(milliseconds: GeminiConfig.retryDelayMs));
      final apiKey = await _readKey();
      final url    = Uri.parse('${GeminiConfig.baseUrl}?key=$apiKey');
      final retry  = await _client
          .post(url,
          headers: _headers,
          body: _buildBody(prompt, temperature, maxTokens))
          .timeout(Duration(seconds: timeoutSecs));
      return _handleResponse(retry,
          retried: true,
          prompt: prompt,
          temperature: temperature,
          maxTokens: maxTokens,
          timeoutSecs: timeoutSecs);
    }

    String errorDetail = '';
    try {
      final body = jsonDecode(response.body);
      errorDetail = body['error']?['message'] ?? response.body;
    } catch (_) {
      errorDetail = response.body;
    }

    debugPrint('GEMINI ERROR DETAIL: $errorDetail');

    switch (code) {
      case 400: throw GeminiServerException(400, 'Bad Request: $errorDetail');
      case 404: throw GeminiServerException(404, 'Endpoint Not Found. Check model name/version: $errorDetail');
      case 403: throw GeminiServerException(403, 'Key Invalid or No Access: $errorDetail');
      case 429: throw const GeminiRateLimitException();
      default:  throw GeminiServerException(code, 'Server Error ($code): $errorDetail');
    }
  }

  String _extractText(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (body.containsKey('error')) {
        final err = body['error'] as Map<String, dynamic>;
        throw GeminiServerException(err['code'] as int? ?? 500, err['message'] as String? ?? 'Unknown error');
      }

      final candidates = body['candidates'] as List<dynamic>?;
      if (candidates == null || candidates.isEmpty) throw const GeminiParseException('No candidates');
      final text = candidates[0]['content']?['parts']?[0]?['text'] as String?;
      if (text == null || text.isEmpty) throw const GeminiParseException('Empty response');
      return text;
    } catch (e) {
      if (e is GeminiException) rethrow;
      throw GeminiParseException('Parse error: $e');
    }
  }

  Future<String> _readKey() async {
    final key = await StorageService.instance.readGeminiKey();
    if (key == null || key.trim().isEmpty) throw const GeminiKeyMissingException();
    return key.trim();
  }

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
  };

  static String _buildBody(String prompt, double temperature, int maxTokens) {
    return jsonEncode({
      'contents': [{'parts': [{'text': prompt}]}],
      'generationConfig': {
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      },
    });
  }

  void dispose() => _client.close();
}

class GeminiServerException extends GeminiException {
  final int statusCode;
  GeminiServerException(this.statusCode, String detail) : super(detail);
}