import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import '../utils/constants.dart';

/// All possible outcomes of a speech session
enum SpeechResult {
  success,
  permissionDenied,
  notAvailable,
  noSpeechDetected,
  networkError,
  unknownError,
}

class SpeechServiceResult {
  final SpeechResult type;
  final String?      transcript;
  final String?      errorMessage;

  const SpeechServiceResult({
    required this.type,
    this.transcript,
    this.errorMessage,
  });

  bool get isSuccess => type == SpeechResult.success;
}

/// Callbacks the VoiceProvider registers on startListening()
class SpeechCallbacks {
  /// Fires on every partial + final recognition update
  final void Function(String text, bool isFinal) onResult;

  /// Fires when the speech session ends naturally (pause detected)
  final void Function(SpeechServiceResult result) onDone;

  /// Fires on sound-level changes (–1.0 to 10.0)
  final void Function(double level)? onSoundLevel;

  const SpeechCallbacks({
    required this.onResult,
    required this.onDone,
    this.onSoundLevel,
  });
}

class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _initialized = false;
  bool _isListening  = false;

  // Last recognised words carried between partial updates
  String _accumulatedText = '';

  bool get isListening   => _isListening;
  bool get isInitialized => _initialized;

  // ── Initialise once ────────────────────────────────────────
  Future<SpeechResult> initialize() async {
    if (_initialized) return SpeechResult.success;
    try {
      _initialized = await _stt.initialize(
        onError:            _onError,
        onStatus:           _onStatus,
        debugLogging:       false,
        finalTimeout:       Duration(seconds: AppConstants.voiceMaxSeconds),
      );
      return _initialized ? SpeechResult.success : SpeechResult.notAvailable;
    } catch (e) {
      _initialized = false;
      return SpeechResult.unknownError;
    }
  }

  // ── Start listening ────────────────────────────────────────
  Future<SpeechResult> startListening(SpeechCallbacks callbacks) async {
    // Re-initialise if needed
    if (!_initialized) {
      final init = await initialize();
      if (init != SpeechResult.success) return init;
    }

    if (_isListening) await stopListening();
    _accumulatedText = '';

    final available = await _stt.hasPermission;
    if (!available) {
      final granted = await _requestPermission();
      if (!granted) return SpeechResult.permissionDenied;
    }

    _isListening = true;

    await _stt.listen(
      onResult: (SpeechRecognitionResult result) {
        _accumulatedText = result.recognizedWords;
        callbacks.onResult(result.recognizedWords, result.finalResult);

        if (result.finalResult) {
          _isListening = false;
          callbacks.onDone(SpeechServiceResult(
            type:       SpeechResult.success,
            transcript: result.recognizedWords,
          ));
        }
      },
      onSoundLevelChange: callbacks.onSoundLevel,
      listenFor:    Duration(seconds: AppConstants.voiceMaxSeconds),
      pauseFor:     Duration(seconds: AppConstants.voicePauseSeconds),
      localeId:     AppConstants.voiceLocale,
      cancelOnError: true,
      partialResults: true,
      listenMode:   stt.ListenMode.dictation,
    );

    return SpeechResult.success;
  }

  // ── Stop listening ─────────────────────────────────────────
  Future<void> stopListening() async {
    if (!_isListening) return;
    await _stt.stop();
    _isListening = false;
  }

  // ── Cancel (discard partial results) ──────────────────────
  Future<void> cancel() async {
    await _stt.cancel();
    _isListening = false;
    _accumulatedText = '';
  }

  // ── Check permission without requesting ───────────────────
  Future<bool> hasPermission() => _stt.hasPermission;

  // ── Available locales ─────────────────────────────────────
  Future<List<stt.LocaleName>> availableLocales() => _stt.locales();

  // ── Private helpers ───────────────────────────────────────
  Future<bool> _requestPermission() async {
    // SpeechToText handles the system permission dialog internally on
    // the first initialize() call — this is a belt-and-suspenders check
    final result = await _stt.initialize();
    _initialized = result;
    return result;
  }

  void _onError(SpeechRecognitionError error) {
    _isListening = false;
    // Errors are surfaced via onDone callback — no direct handling here
    // because the caller (VoiceProvider) owns the response logic
  }

  void _onStatus(String status) {
    if (status == 'notListening' || status == 'done') {
      _isListening = false;
    }
  }
}