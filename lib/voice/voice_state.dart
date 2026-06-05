/// The five mutually-exclusive states of the voice pipeline.
/// Every UI component that reacts to voice derives its appearance
/// from exactly this enum — nothing else.
enum VoiceState {
  /// No session active. Mic button is static, waveform collapsed.
  idle,

  /// Mic open, SpeechService streaming audio. Waveform animates.
  listening,

  /// Final transcript received, Gemini + PHP calls in-flight.
  /// Mic shows rotating arc, status message updates.
  processing,

  /// TTS is speaking the response aloud.
  speaking,

  /// An error occurred (permission denied, Gemini failure, etc.)
  error,
}

/// Typed error codes used by VoiceProvider to build user-facing messages.
enum VoiceErrorCode {
  permissionDenied,
  micNotAvailable,
  noSpeechDetected,
  geminiKeyMissing,
  geminiApiError,
  geminiTimeout,
  geminiParseFailed,
  lowConfidence,
  unknownIntent,
  apiError,
  networkError,
  unknown,
}

class VoiceError {
  final VoiceErrorCode code;
  final String         message;
  final List<String>   suggestions;

  const VoiceError({
    required this.code,
    required this.message,
    this.suggestions = const [],
  });

  // ── Factory constructors for every error type ──────────────
  factory VoiceError.permissionDenied() => const VoiceError(
    code:        VoiceErrorCode.permissionDenied,
    message:     'Microphone permission is required for voice commands.',
    suggestions: ['Open App Settings', 'Grant microphone access', 'Restart the app'],
  );

  factory VoiceError.micNotAvailable() => const VoiceError(
    code:        VoiceErrorCode.micNotAvailable,
    message:     'Speech recognition is not available on this device.',
    suggestions: ['Use the text chat instead'],
  );

  factory VoiceError.noSpeechDetected() => const VoiceError(
    code:        VoiceErrorCode.noSpeechDetected,
    message:     'No speech was detected. Please try again.',
    suggestions: [
      'Show MCA attendance today',
      'How many fees are pending?',
      'Faculty status today',
    ],
  );

  factory VoiceError.geminiKeyMissing() => const VoiceError(
    code:        VoiceErrorCode.geminiKeyMissing,
    message:     'Gemini API key not configured. Go to Settings to add it.',
    suggestions: ['Open Settings'],
  );

  factory VoiceError.geminiTimeout() => const VoiceError(
    code:        VoiceErrorCode.geminiTimeout,
    message:     'AI service took too long to respond. Please try again.',
    suggestions: [
      'Show MCA attendance today',
      'MCA fee summary',
    ],
  );

  factory VoiceError.lowConfidence(double conf, String? intent) => VoiceError(
    code:        VoiceErrorCode.lowConfidence,
    message:     'I\'m not sure what you meant (${(conf * 100).round()}% confidence). '
        'Please rephrase your query.',
    suggestions: const [
      'Show MCA attendance today',
      'How many fees are pending for BCA?',
      'Which faculty are absent today?',
      'Compare all departments',
    ],
  );

  factory VoiceError.unknownIntent() => const VoiceError(
    code:        VoiceErrorCode.unknownIntent,
    message:     'I can answer questions about attendance, fees, admissions, and faculty.',
    suggestions: [
      'Show MCA attendance today',
      'How many fees are pending?',
      'Faculty status today',
      'Admissions funnel for BCA',
    ],
  );

  factory VoiceError.apiError(String detail) => VoiceError(
    code:        VoiceErrorCode.apiError,
    message:     'Could not fetch data: $detail',
    suggestions: const ['Try again', 'Check network connection'],
  );

  factory VoiceError.networkError() => const VoiceError(
    code:        VoiceErrorCode.networkError,
    message:     'Network unavailable. Check your WiFi connection.',
    suggestions: ['Check WiFi', 'Make sure XAMPP is running'],
  );

  factory VoiceError.unknown(String detail) => VoiceError(
    code:        VoiceErrorCode.unknown,
    message:     'Something went wrong. Please try again.',
    suggestions: const ['Tap the mic to retry'],
  );
}