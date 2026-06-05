import 'package:speech_to_text/speech_to_text.dart' as stt;

/// Wraps permission checking for microphone access.
/// Uses speech_to_text's own permission bridge — no extra plugin needed.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();

  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _checked = false;
  bool _granted = false;

  /// Returns true if RECORD_AUDIO permission is already granted.
  Future<bool> hasMicPermission() async {
    if (_checked) return _granted;
    _granted = await _stt.hasPermission;
    _checked = true;
    return _granted;
  }

  /// Requests RECORD_AUDIO by triggering STT initialisation,
  /// which shows the system permission dialog on first run.
  Future<bool> requestMicPermission() async {
    final granted = await _stt.initialize();
    _granted = granted;
    _checked = true;
    return granted;
  }

  /// Resets cached state — call after the user returns from Settings.
  void reset() {
    _checked = false;
    _granted = false;
  }
}