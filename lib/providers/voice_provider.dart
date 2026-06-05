import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../voice/voice_state.dart';
import '../voice/speech_service.dart';
import '../voice/tts_service.dart';
import '../voice/permission_service.dart';
import '../ai/gemini_service.dart';
import '../ai/gemini_exceptions.dart';
import 'dashboard_provider.dart';

export '../voice/voice_state.dart' show VoiceState, VoiceError, VoiceErrorCode;

class VoiceProvider extends ChangeNotifier {
  final DashboardProvider _dashProvider;

  VoiceProvider(this._dashProvider) {
    _init();
  }

  // ── State ─────────────────────────────────────────────────
  VoiceState            _state         = VoiceState.idle;
  String                _transcript    = '';
  String                _partialText   = '';  // IMPROVEMENT 4: live partial
  IntentModel?          _lastIntent;
  Map<String, dynamic>? _lastResult;
  String                _statusMessage = 'Tap the mic to start';
  VoiceError?           _lastError;
  double                _soundLevel    = 0.0;

  // IMPROVEMENT 7: auto-refresh timer
  Timer? _refreshTimer;

  // ── Getters ───────────────────────────────────────────────
  VoiceState            get state         => _state;
  String                get transcript    => _transcript;
  String                get partialText   => _partialText; // IMPROVEMENT 4
  IntentModel?          get lastIntent    => _lastIntent;
  Map<String, dynamic>? get lastResult    => _lastResult;
  String                get statusMessage => _statusMessage;
  VoiceError?           get lastError     => _lastError;
  double                get soundLevel    => _soundLevel;
  bool get isIdle       => _state == VoiceState.idle;
  bool get isListening  => _state == VoiceState.listening;
  bool get isProcessing => _state == VoiceState.processing;
  bool get isSpeaking   => _state == VoiceState.speaking;
  bool get hasError     => _state == VoiceState.error;

  Future<void> _init() async {
    await TtsService.instance.initialize();
  }

  // IMPROVEMENT 7: start auto-refresh for dashboard
  void startAutoRefresh({String? department}) {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _dashProvider.loadDashboard(department: department, silent: true);
    });
  }

  void stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // ═══════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════

  Future<void> startListening() async {
    if (_state == VoiceState.listening) return;
    _resetSession();

    final hasPerm = await PermissionService.instance.hasMicPermission();
    if (!hasPerm) {
      final granted = await PermissionService.instance.requestMicPermission();
      if (!granted) { _setError(VoiceError.permissionDenied()); return; }
    }

    final initRes = await SpeechService.instance.initialize();
    if (initRes != SpeechResult.success) {
      _setError(VoiceError.micNotAvailable()); return;
    }

    _setState(VoiceState.listening, 'Listening...');

    final res = await SpeechService.instance.startListening(
      SpeechCallbacks(
        onResult: (text, isFinal) {
          // IMPROVEMENT 4: update partial text on every recognition event
          _partialText = text;
          if (isFinal) _transcript = text;
          notifyListeners();
        },
        onDone: _onSpeechDone,
        onSoundLevel: (level) {
          _soundLevel = level;
          notifyListeners();
        },
      ),
    );

    if (res != SpeechResult.success) _setError(_speechToError(res));
  }

  Future<void> stopListening() async {
    if (!isListening) return;
    await SpeechService.instance.stopListening();
  }

  Future<void> cancel() async {
    await SpeechService.instance.cancel();
    if (isSpeaking) await TtsService.instance.stop();
    _setState(VoiceState.idle, 'Tap the mic to start');
  }

  Future<void> stopSpeaking() async {
    await TtsService.instance.stop();
    _setState(VoiceState.idle, 'Tap the mic to start');
  }

  Future<void> processTranscript(String text) async {
    if (text.trim().isEmpty) {
      _setState(VoiceState.idle, 'No speech detected. Tap to try again.');
      return;
    }
    _transcript  = text;
    _partialText = text;
    notifyListeners();
    await _runPipeline(text);
  }

  void resetError() {
    _lastError = null;
    _setState(VoiceState.idle, 'Tap the mic to start');
  }

  // ═══════════════════════════════════════════════════════════
  // STT CALLBACKS
  // ═══════════════════════════════════════════════════════════

  Future<void> _onSpeechDone(SpeechServiceResult result) async {
    if (result.type == SpeechResult.permissionDenied) {
      _setError(VoiceError.permissionDenied()); return;
    }
    if (result.type == SpeechResult.notAvailable) {
      _setError(VoiceError.micNotAvailable()); return;
    }
    final text = result.transcript ?? _partialText;
    if (text.trim().isEmpty) {
      _setError(VoiceError.noSpeechDetected()); return;
    }
    _transcript  = text;
    _partialText = text;
    notifyListeners();
    await _runPipeline(text);
  }

  // ═══════════════════════════════════════════════════════════
  // VOICE PIPELINE
  // ═══════════════════════════════════════════════════════════

  Future<void> _runPipeline(String transcript) async {
    try {
      // ── Step 1: Gemini intent extraction ─────────────────
      _setState(VoiceState.processing, 'Understanding...');

      IntentModel intent;
      try {
        intent = await GeminiService.instance.extractIntent(transcript);
      } on GeminiKeyMissingException {
        _setError(VoiceError.geminiKeyMissing()); return;
      } on GeminiKeyInvalidException {
        _setError(VoiceError(
            code: VoiceErrorCode.geminiApiError,
            message: 'Invalid API Key — please update in Settings.')); return;
      } on GeminiRateLimitException {
        _setError(VoiceError(
            code:    VoiceErrorCode.geminiApiError,
            message: 'Rate limit reached. Please wait a moment.',
            suggestions: ['Wait 10 seconds', 'Try a simpler query'])); return;
      } on GeminiTimeoutException {
        _setError(VoiceError.geminiTimeout()); return;
      } on GeminiLowConfidenceException catch (e) {
        // IMPROVEMENT 5: Voice clarification — speak the suggestions
        _lastIntent = IntentModel(
          intent:     e.intent,
          confidence: e.confidence,
          summary:    'Low confidence query',
        );
        notifyListeners();
        // Speak clarification request
        final ttsText = "I'm not sure what you meant. "
            "Try saying: Show MCA attendance, or Fee collection summary, "
            "or Faculty status today.";
        _setState(VoiceState.speaking, ttsText);
        await TtsService.instance.speak(ttsText, onComplete: () {
          if (_state == VoiceState.speaking) {
            _setState(VoiceState.idle, 'Tap the mic to start');
          }
        });
        return;
      } on GeminiUnknownIntentException {
        _setError(VoiceError.unknownIntent()); return;
      } on GeminiServerException catch (e) {
        _setError(VoiceError(
            code:    VoiceErrorCode.geminiApiError,
            message: 'AI Error (${e.statusCode}) — ${e.message}')); return;
      } on GeminiParseException {
        _setError(VoiceError(
            code:    VoiceErrorCode.geminiParseFailed,
            message: 'Could not parse AI response. Please try again.')); return;
      }

      _lastIntent = intent;
      notifyListeners();

      // ── Step 2: PHP API call ──────────────────────────────
      _setState(VoiceState.processing, 'Fetching data...');

      Map<String, dynamic> result;
      try {
        result = await _callApi(intent);
      } on ApiException catch (e) {
        _setError(VoiceError.apiError(e.message)); return;
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('socket') || msg.contains('connection')) {
          _setError(VoiceError.networkError());
        } else {
          _setError(VoiceError.apiError(e.toString().split('\n').first));
        }
        return;
      }

      _lastResult = result;
      _dashProvider.updateFromIntent(intent, result);

      // ── Step 3: IMPROVED insight-aware summary ────────────
      final ttsText = _buildLocalSummary(intent, result);
      _setState(VoiceState.speaking, ttsText);

      // ── Step 4: Speak ─────────────────────────────────────
      await TtsService.instance.speak(
        ttsText,
        onComplete: () {
          if (_state == VoiceState.speaking) {
            _setState(VoiceState.idle, 'Tap the mic to start');
          }
        },
      );

    } catch (e) {
      _setError(VoiceError(
          code:    VoiceErrorCode.unknown,
          message: 'System Error: ${e.toString().split('\n').first}'));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // IMPROVEMENT 3: Insight-aware local summary for TTS
  // ═══════════════════════════════════════════════════════════

  String _buildLocalSummary(IntentModel intent, Map<String, dynamic> apiResult) {
    final data = apiResult['data'] as Map<String, dynamic>? ?? {};
    final dept = intent.department ?? 'all departments';

    try {
      switch (intent.intent) {
        case IntentConstants.getAttendance:
        case IntentConstants.getAttSummary:
          final s       = (data['summary'] as Map<String, dynamic>?) ?? data;
          final total   = (s['total']   ?? 0) as int;
          final present = (s['present'] ?? 0) as int;
          final absent  = (s['absent']  ?? 0) as int;
          final late    = (s['late']    ?? 0) as int;
          if (total == 0) {
            return 'No attendance data found for $dept today. '
                'Please ensure attendance has been marked.';
          }
          final pct = ((present / total) * 100).round();

          String insight = '';
          if (pct >= 90)      insight = ' Excellent turnout today.';
          else if (pct >= 75) insight = ' Attendance is on track.';
          else if (pct >= 60) insight = ' Below target. Follow-up may be needed.';
          else                insight = ' Critical shortage. Immediate action required.';

          return '$present of $total students are present in $dept today, '
              'that is $pct percent.$insight '
              '${absent > 0 ? '$absent absent' : ''}'
              '${late > 0   ? ', $late late.'  : '.'}';

        case IntentConstants.getFeeSummary:
        case IntentConstants.getFees:
          final collected = (data['collected'] ?? data['total_collected'] ?? 0) as num;
          final pending   = (data['pending']   ?? data['total_pending']   ?? 0) as num;
          final overdue   = (data['overdue']   ?? data['total_overdue']   ?? 0) as num;
          final pct       = data['percentage_collected'] ?? 0;
          if (collected == 0 && pending == 0) return 'No fee data found for $dept.';

          String urgency = overdue > 0
              ? ' Warning: ${_fmtSpeak(overdue.toDouble())} is overdue and needs follow-up.'
              : '';
          return 'Fee collection for $dept is $pct percent. '
              '${_fmtSpeak(collected.toDouble())} collected, '
              '${_fmtSpeak(pending.toDouble())} pending.$urgency';

        case IntentConstants.getFacultyStatus:
          final s       = (data['summary'] as Map<String, dynamic>?) ?? data;
          final total   = (s['total']   ?? 0) as int;
          final present = (s['present'] ?? 0) as int;
          final absent  = (s['absent']  ?? 0) as int;
          if (total == 0) return 'No faculty data found for $dept.';
          final pct = total > 0 ? ((present / total) * 100).round() : 0;
          return '$present of $total faculty are present in $dept today, '
              'that is $pct percent. '
              '${absent > 0 ? '$absent are on leave.' : 'Full faculty attendance.'}';

        case IntentConstants.getAdmissions:
        case IntentConstants.getAdmStats:
          final applied     = data['applied']     ?? 0;
          final admitted    = data['admitted']    ?? 0;
          final shortlisted = data['shortlisted'] ?? 0;
          return 'Admissions for $dept: $applied applied, '
              '$shortlisted shortlisted, $admitted admitted.';

        case IntentConstants.getDeptComparison:
          final depts = data['departments'] as List<dynamic>? ?? [];
          if (depts.isEmpty) return 'Department comparison data is not available.';
          final sorted = List.from(depts)..sort((a, b) =>
              ((b['avg_attendance_pct'] ?? 0) as num)
                  .compareTo((a['avg_attendance_pct'] ?? 0) as num));
          final best  = sorted.first;
          final worst = sorted.last;
          return '${best['code']} leads with ${best['avg_attendance_pct']} percent attendance. '
              '${worst['code']} needs attention at ${worst['avg_attendance_pct']} percent.';

        case IntentConstants.getAnalytics:
          final metric = intent.metric ?? 'attendance';
          return '$metric analytics for $dept loaded. '
              'Please check the analytics screen for detailed charts.';

        case IntentConstants.getNotifications:
          final count = data['unread_count'] ?? 0;
          return count == 0
              ? 'All caught up. No unread notifications.'
              : 'You have $count unread notification${count == 1 ? '' : 's'}.';

        case IntentConstants.generateReport:
          return 'Report generation request received for $dept. '
              'Please check the Reports screen to download.';

        default:
          return intent.summary ?? 'Request processed successfully for $dept.';
      }
    } catch (_) {
      return intent.summary ?? 'Data retrieved for $dept.';
    }
  }

  // Speak-friendly number formatting (no symbols)
  String _fmtSpeak(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)} lakh rupees';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(1)} thousand rupees';
    return '${v.toStringAsFixed(0)} rupees';
  }

  // ═══════════════════════════════════════════════════════════
  // API ROUTING
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> _callApi(IntentModel intent) async {
    final today = _todayStr();
    final date  = switch (intent.date) {
      'TODAY'     => today,
      'YESTERDAY' => _yesterdayStr(),
      null        => today,
      _           => intent.date!,
    };

    return await switch (intent.intent) {
      IntentConstants.getAttendance ||
      IntentConstants.getAttSummary =>
          ApiService.instance.getAttendanceSummary(
              department: intent.department, date: date),
      IntentConstants.getFees || IntentConstants.getFeeSummary =>
          ApiService.instance.getFeeSummary(department: intent.department),
      IntentConstants.getFacultyStatus =>
          ApiService.instance.getFacultyStatus(department: intent.department),
      IntentConstants.getDeptComparison =>
          ApiService.instance.getDeptComparison(),
      IntentConstants.getAnalytics =>
          ApiService.instance.getTrend(
            metric:     intent.metric ?? 'attendance',
            department: intent.department,
            days:       intent.periodDays ?? 30,
          ),
      IntentConstants.getNotifications =>
          ApiService.instance.getNotifications(),
      _ => Future.value({'status': 'success', 'data': {}}),
    };
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════

  void _resetSession() {
    _lastError   = null;
    _partialText = '';
    _transcript  = '';
    _lastIntent  = null;
    _lastResult  = null;
  }

  void _setState(VoiceState s, String msg) {
    _state         = s;
    _statusMessage = msg;
    notifyListeners();
  }

  void _setError(VoiceError err) {
    _lastError     = err;
    _state         = VoiceState.error;
    _statusMessage = err.message;
    notifyListeners();
  }

  VoiceError _speechToError(SpeechResult r) => switch (r) {
    SpeechResult.permissionDenied => VoiceError.permissionDenied(),
    SpeechResult.notAvailable     => VoiceError.micNotAvailable(),
    SpeechResult.noSpeechDetected => VoiceError.noSpeechDetected(),
    _                             => VoiceError.unknown('STT error'),
  };

  String _todayStr() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayStr() {
    final n = DateTime.now().subtract(const Duration(days: 1));
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    SpeechService.instance.cancel();
    TtsService.instance.stop();
    super.dispose();
  }
}