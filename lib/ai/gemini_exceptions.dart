/// Base class for all Gemini-related exceptions.
/// Every failure in the AI layer throws a subclass of this —
/// callers (VoiceProvider, ChatProvider) switch on the type.
abstract class GeminiException implements Exception {
  final String message;
  const GeminiException(this.message);

  @override
  String toString() => 'GeminiException: $message';
}

/// API key absent from secure storage or empty string.
class GeminiKeyMissingException extends GeminiException {
  const GeminiKeyMissingException()
      : super('Gemini API key not configured. '
      'Go to Settings to add your key.');
}

/// API key present but rejected by Google (HTTP 400 / 403).
class GeminiKeyInvalidException extends GeminiException {
  final int statusCode;
  const GeminiKeyInvalidException(this.statusCode)
      : super('Gemini API key is invalid or has been revoked. '
      'Please check your key in Settings.');
}

/// HTTP 429 — free-tier rate limit hit.
class GeminiRateLimitException extends GeminiException {
  const GeminiRateLimitException()
      : super('AI rate limit reached. '
      'Please wait a moment and try again.');
}

/// Network call timed out or no connectivity.
class GeminiTimeoutException extends GeminiException {
  const GeminiTimeoutException()
      : super('AI service took too long to respond. '
      'Check your connection and try again.');
}

/// Gemini returned HTTP 5xx — server-side error.
class GeminiServerException extends GeminiException {
  final int statusCode;
  const GeminiServerException(this.statusCode)
      : super('Gemini server error ($statusCode). '
      'Please try again in a moment.');
}

/// Response text could not be decoded as valid JSON.
class GeminiParseException extends GeminiException {
  final String raw;
  const GeminiParseException(this.raw)
      : super('Could not parse AI response as JSON.');
}

/// Parsed JSON is missing required fields or has wrong types.
class GeminiSchemaException extends GeminiException {
  final String detail;
  const GeminiSchemaException(this.detail)
      : super('AI response did not match expected schema: $detail');
}

/// Intent confidence is below the configured threshold.
class GeminiLowConfidenceException extends GeminiException {
  final double confidence;
  final String intent;
  GeminiLowConfidenceException(this.confidence, this.intent)
      : super('Low confidence (${(confidence * 100).round()}%) '
      'for intent "$intent". Please rephrase your query.');
}

/// Intent string not in the supported registry.
class GeminiUnknownIntentException extends GeminiException {
  final String intent;
  const GeminiUnknownIntentException(this.intent)
      : super('Unrecognised intent "$intent". '
      'Try asking about attendance, fees, or faculty.');
}