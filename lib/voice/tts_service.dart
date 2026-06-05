import 'package:flutter_tts/flutter_tts.dart';
import '../utils/constants.dart';

enum TtsState { idle, playing, paused, stopped }

class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  TtsState _state = TtsState.idle;
  VoidCallback? _onComplete;
  VoidCallback? _onStart;

  TtsState get state   => _state;
  bool get isPlaying   => _state == TtsState.playing;

  // ── Initialise once ────────────────────────────────────────
  Future<void> initialize() async {
    await _tts.setLanguage(AppConstants.ttsLanguage);
    await _tts.setSpeechRate(AppConstants.ttsSpeechRate);
    await _tts.setVolume(AppConstants.ttsVolume);
    await _tts.setPitch(AppConstants.ttsPitch);

    _tts.setStartHandler(() {
      _state = TtsState.playing;
      _onStart?.call();
    });

    _tts.setCompletionHandler(() {
      _state = TtsState.idle;
      _onComplete?.call();
    });

    _tts.setCancelHandler(() {
      _state = TtsState.stopped;
    });

    _tts.setErrorHandler((msg) {
      _state = TtsState.idle;
      _onComplete?.call(); // treat error as complete so UI resets
    });
  }

  // ── Speak ──────────────────────────────────────────────────
  Future<void> speak(
      String text, {
        VoidCallback? onComplete,
        VoidCallback? onStart,
      }) async {
    if (text.trim().isEmpty) {
      onComplete?.call();
      return;
    }
    _onComplete = onComplete;
    _onStart    = onStart;

    // Stop any ongoing speech first
    if (_state == TtsState.playing) await _tts.stop();

    final cleaned = _cleanText(text);
    await _tts.speak(cleaned);
  }

  // ── Stop ───────────────────────────────────────────────────
  Future<void> stop() async {
    await _tts.stop();
    _state = TtsState.stopped;
  }

  // ── Pause / Resume (Android only) ─────────────────────────
  Future<void> pause()  async => _tts.pause();
  Future<void> resume() async => _tts.speak('');  // resume not supported on all engines

  // ── Change settings at runtime ────────────────────────────
  Future<void> setRate(double rate)     => _tts.setSpeechRate(rate.clamp(0.1, 1.0));
  Future<void> setVolume(double volume) => _tts.setVolume(volume.clamp(0.0, 1.0));
  Future<void> setPitch(double pitch)   => _tts.setPitch(pitch.clamp(0.5, 2.0));

  // ── Available languages ───────────────────────────────────
  Future<List<dynamic>> availableLanguages() async {
    final result = await _tts.getLanguages;
    return result is List ? result : [];
  }

  // ── Clean text before speaking ────────────────────────────
  String _cleanText(String text) => text
      .replaceAll('**', '')       // remove markdown bold
      .replaceAll('*',  '')
      .replaceAll('#',  '')
      .replaceAll('`',  '')
      .replaceAll('✅', '')
      .replaceAll('❌', '')
      .replaceAll('🕐', '')
      .replaceAll('⏳', '')
      .replaceAll('₹',  'Rupees ')
      .replaceAll('%',  ' percent')
      .replaceAll('\n', '. ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
}

// Lightweight callback typedef (avoids importing dart:ui)
typedef VoidCallback = void Function();