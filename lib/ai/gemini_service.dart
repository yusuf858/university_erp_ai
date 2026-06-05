import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/storage_service.dart';
import 'gemini_config.dart';
import 'gemini_exceptions.dart';
import 'gemini_http_client.dart';
import 'intent_parser.dart';
import 'prompts/prompt_builder.dart';

class GeminiService {
  GeminiService._();
  static final GeminiService instance = GeminiService._();

  final GeminiHttpClient _http = GeminiHttpClient.instance;
  DateTime? _lastCallTime;
  IntentModel? _sessionContext;

  // ── IMPROVEMENT 1: Multi-turn conversation history ────────
  final List<Map<String, String>> _conversationHistory = [];

  void clearSessionContext() {
    _sessionContext = null;
    _conversationHistory.clear();
  }

  // ── 1. INTENT EXTRACTION with conversation history ────────
  Future<IntentModel> extractIntent(
      String query, {
        List<Map<String, String>>? conversationHistory,
      }) async {
    if (query.trim().isEmpty) throw const GeminiUnknownIntentException('empty');

    await _enforceCooldown();

    final role = await StorageService.instance.readRole() ?? 'admin';
    final dept = await StorageService.instance.readDeptCode();

    // Use passed history or internal history
    final history = conversationHistory ?? _conversationHistory;

    final prompt = PromptBuilder.buildIntentPrompt(
      query:               query,
      role:                role,
      deptCode:            dept,
      sessionContext:      _sessionContext,
      conversationHistory: history,
    );

    final rawText = await _http.call(
      prompt:      prompt,
      temperature: GeminiConfig.intentTemperature,
      maxTokens:   GeminiConfig.intentMaxTokens,
      timeoutSecs: GeminiConfig.intentTimeoutSeconds,
    );

    final intent = IntentParser.parse(rawText);
    _sessionContext = intent;

    // Add to internal history (keep last 10 turns = 5 pairs)
    _conversationHistory.add({'role': 'user',      'content': query});
    _conversationHistory.add({'role': 'assistant', 'content': intent.summary ?? intent.intent});
    if (_conversationHistory.length > 10) {
      _conversationHistory.removeRange(0, 2);
    }

    return intent;
  }

  // ── 2. SUMMARY GENERATION ─────────────────────────────────
  Future<String> generateSummary({
    required IntentModel intent,
    required Map<String, dynamic> data,
  }) async {
    final role   = await StorageService.instance.readRole() ?? 'admin';
    final prompt = PromptBuilder.buildSummaryPrompt(
      intent:     intent.intent,
      department: intent.department ?? 'all departments',
      data:       data,
      role:       role,
    );

    final rawText = await _http.call(
      prompt:      prompt,
      temperature: GeminiConfig.summaryTemperature,
      maxTokens:   GeminiConfig.summaryMaxTokens,
      timeoutSecs: GeminiConfig.summaryTimeoutSeconds,
    );

    return rawText.trim().replaceAll(RegExp(r'^"|"$'), '').trim();
  }

  // ── 3. KEY VALIDATION ─────────────────────────────────────
  Future<GeminiKeyValidationResult> validateKey(String key) async {
    final cleanKey = key.trim();
    if (cleanKey.isEmpty) {
      return const GeminiKeyValidationResult(isValid: false, error: 'Key is empty');
    }

    try {
      await StorageService.instance.saveGeminiKey(cleanKey);
      debugPrint('Testing Gemini key: ${cleanKey.substring(0, 8)}...');
      final response = await _http.call(
        prompt:      'Say "Ready"',
        temperature: 0.0,
        maxTokens:   10,
        timeoutSecs: 8,
      );
      debugPrint('Key test response: $response');
      return const GeminiKeyValidationResult(isValid: true);
    } on GeminiKeyInvalidException {
      return const GeminiKeyValidationResult(
          isValid: false, error: 'Google rejected this key. Check AI Studio.');
    } on GeminiRateLimitException {
      return const GeminiKeyValidationResult(
          isValid: true, error: 'Key valid, but rate limited. Please wait.');
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('handshake') || errorMsg.contains('connection')) {
        return GeminiKeyValidationResult(
          isValid: true,
          error: 'Saved! (Warning: Network handshake failed. Check your internet).',
        );
      }
      return GeminiKeyValidationResult(isValid: true, error: 'Saved. (Note: $e)');
    }
  }

  Future<void> _enforceCooldown() async {
    if (_lastCallTime == null) {
      _lastCallTime = DateTime.now();
      return;
    }
    final elapsed =
        DateTime.now().difference(_lastCallTime!).inMilliseconds;
    if (elapsed < GeminiConfig.callCooldownMs) {
      await Future.delayed(
          Duration(milliseconds: GeminiConfig.callCooldownMs - elapsed));
    }
    _lastCallTime = DateTime.now();
  }
}

class GeminiKeyValidationResult {
  final bool    isValid;
  final String? error;
  const GeminiKeyValidationResult({required this.isValid, this.error});
}