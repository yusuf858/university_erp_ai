import 'dart:convert';
import '../models/models.dart';
import 'gemini_config.dart';
import 'gemini_exceptions.dart';

/// Responsible for everything that happens AFTER the raw Gemini
/// response text arrives: stripping fences, parsing JSON, validating
/// the schema, normalising entity values, and running the confidence gate.
class IntentParser {
  IntentParser._();

  // ── Main entry point ──────────────────────────────────────
  /// Takes the raw response text from Gemini and returns a validated
  /// [IntentModel]. Throws a typed [GeminiException] on any failure.
  static IntentModel parse(String rawText) {
    // Step 1 — strip markdown fences and whitespace
    final cleaned = _stripFences(rawText);

    // Step 2 — parse JSON
    final Map<String, dynamic> json = _parseJson(cleaned);

    // Step 3 — validate schema (required fields present)
    _validateSchema(json);

    // Step 4 — normalise entity values
    final normalised = _normalise(json);

    // Step 5 — build IntentModel
    final model = _toModel(normalised);

    // Step 6 — validate confidence gate
    _validateConfidence(model);

    return model;
  }

  // ── Step 1: Strip fences ──────────────────────────────────
  static String _stripFences(String raw) {
    var text = raw.trim();

    // Remove ```json ... ``` or ``` ... ``` fences
    text = text.replaceAll(RegExp(r'^```json\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^```\s*',     multiLine: true), '');
    text = text.replaceAll(RegExp(r'\s*```$',     multiLine: true), '');

    // If Gemini prepended prose before the JSON, extract the first { ... }
    final braceStart = text.indexOf('{');
    final braceEnd   = text.lastIndexOf('}');
    if (braceStart > 0 && braceEnd > braceStart) {
      text = text.substring(braceStart, braceEnd + 1);
    }

    return text.trim();
  }

  // ── Step 2: Parse JSON ────────────────────────────────────
  static Map<String, dynamic> _parseJson(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, dynamic>) {
        throw GeminiParseException(text.substring(0, text.length.clamp(0, 120)));
      }
      return decoded;
    } on FormatException catch (e) {
      throw GeminiParseException('FormatException: ${e.message} | raw: '
          '${text.substring(0, text.length.clamp(0, 120))}');
    }
  }

  // ── Step 3: Schema validation ─────────────────────────────
  static void _validateSchema(Map<String, dynamic> json) {
    const required = ['intent', 'confidence', 'summary'];
    for (final field in required) {
      if (!json.containsKey(field)) {
        throw GeminiSchemaException('Missing required field: "$field"');
      }
    }

    // confidence must be a number
    if (json['confidence'] is! num) {
      throw GeminiSchemaException(
          'confidence must be a number, got: ${json['confidence']}');
    }

    // intent must be a string
    if (json['intent'] is! String) {
      throw GeminiSchemaException(
          'intent must be a string, got: ${json['intent']}');
    }
  }

  // ── Step 4: Normalise entities ────────────────────────────
  static Map<String, dynamic> _normalise(Map<String, dynamic> json) {
    final out = Map<String, dynamic>.from(json);

    // intent — uppercase, trim
    out['intent'] = (json['intent'] as String).trim().toUpperCase();

    // Reject intent not in whitelist (treat as UNKNOWN)
    if (!GeminiConfig.supportedIntents.contains(out['intent'])) {
      out['intent'] = 'UNKNOWN';
    }

    // department — uppercase, validate against allowed codes
    if (json['department'] != null) {
      final dept = (json['department'] as String).trim().toUpperCase();
      out['department'] = GeminiConfig.validDepartments.contains(dept)
          ? dept
          : null; // invalid code → null rather than crash
    }

    // date — uppercase, trim
    if (json['date'] != null) {
      final date = (json['date'] as String).trim().toUpperCase();
      out['date'] = GeminiConfig.validDateTokens.contains(date)
          ? date
          : _isIsoDate(date) ? date : 'TODAY';
    } else {
      out['date'] = 'TODAY';
    }

    // status — lowercase, validate
    if (json['status'] != null) {
      final status = (json['status'] as String).trim().toLowerCase();
      final allValid = <String>{
        ...GeminiConfig.validAttendanceStatus,
        ...GeminiConfig.validFeeStatus,
      };
      out['status'] = allValid.contains(status) ? status : null;
    }

    // semester — must be 1–6
    if (json['semester'] != null) {
      final sem = json['semester'];
      final semInt = sem is int ? sem : int.tryParse(sem.toString());
      out['semester'] = (semInt != null && semInt >= 1 && semInt <= 6)
          ? semInt
          : null;
    }

    // period_days — coerce to int
    if (json['period_days'] != null) {
      final pd = json['period_days'];
      out['period_days'] = pd is int ? pd : int.tryParse(pd.toString());
    }

    // metric — lowercase, validate
    if (json['metric'] != null) {
      final metric = (json['metric'] as String).trim().toLowerCase();
      out['metric'] = GeminiConfig.validMetrics.contains(metric)
          ? metric
          : null;
    }

    // confidence — clamp to 0.0–1.0
    final rawConf = (json['confidence'] as num).toDouble();
    out['confidence'] = rawConf.clamp(0.0, 1.0);

    // faculty — trim if present
    if (json['faculty'] != null) {
      out['faculty'] = (json['faculty'] as String).trim();
      if (out['faculty'] == '') out['faculty'] = null;
    }

    // academic_year — validate YYYY-YYYY format
    if (json['academic_year'] != null) {
      final ay = (json['academic_year'] as String).trim();
      out['academic_year'] = RegExp(r'^\d{4}-\d{4}$').hasMatch(ay) ? ay : null;
    }

    // summary — trim
    if (json['summary'] != null) {
      out['summary'] = (json['summary'] as String).trim();
    }

    return out;
  }

  // ── Step 5: Build model ───────────────────────────────────
  static IntentModel _toModel(Map<String, dynamic> json) => IntentModel(
    intent:       json['intent']       as String,
    department:   json['department']   as String?,
    semester:     json['semester']     as int?,
    date:         json['date']         as String?,
    status:       json['status']       as String?,
    faculty:      json['faculty']      as String?,
    academicYear: json['academic_year']as String?,
    metric:       json['metric']       as String?,
    periodDays:   json['period_days']  as int?,
    confidence:   (json['confidence']  as num).toDouble(),
    summary:      json['summary']      as String?,
  );

  // ── Step 6: Confidence gate ───────────────────────────────
  static void _validateConfidence(IntentModel model) {
    // Hard reject — intent is UNKNOWN
    if (model.intent == 'UNKNOWN') {
      throw GeminiUnknownIntentException(model.intent);
    }

    // Hard reject — confidence too low
    if (model.confidence < GeminiConfig.minConfidence) {
      throw GeminiLowConfidenceException(model.confidence, model.intent);
    }
  }

  // ── Helpers ───────────────────────────────────────────────
  static bool _isIsoDate(String s) =>
      RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);
}