import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../ai/gemini_service.dart';
import '../ai/gemini_exceptions.dart';
import '../utils/constants.dart';
import 'dashboard_provider.dart';

class ChatProvider extends ChangeNotifier {
  final DashboardProvider _dashProvider;
  ChatProvider(this._dashProvider);

  final List<ChatMessage> _messages   = [];
  bool                    _processing = false;
  final _uuid = const Uuid();

  // IMPROVEMENT 1: Multi-turn conversation history
  final List<Map<String, String>> _conversationHistory = [];

  List<ChatMessage> get messages   => List.unmodifiable(_messages);
  bool              get processing => _processing;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _processing) return;

    _addMessage(ChatMessage(
      id:        _uuid.v4(),
      text:      text,
      sender:    MessageSender.user,
      timestamp: DateTime.now(),
    ));

    final loadingId = _uuid.v4();
    _addMessage(ChatMessage(
      id:        loadingId,
      text:      '',
      sender:    MessageSender.ai,
      timestamp: DateTime.now(),
      isLoading: true,
    ));

    _processing = true;
    notifyListeners();

    try {
      // ── 1. GEMINI CALL with conversation history ──────────
      debugPrint('Sending to Gemini: $text');
      final intent = await GeminiService.instance.extractIntent(
        text,
        conversationHistory: _conversationHistory,
      );
      debugPrint('Gemini understood intent: ${intent.intent}');

      // Update conversation history
      _conversationHistory.add({'role': 'user',      'content': text});
      _conversationHistory.add({'role': 'assistant', 'content': intent.summary ?? intent.intent});
      // Keep only last 10 messages (5 pairs)
      if (_conversationHistory.length > 10) {
        _conversationHistory.removeRange(0, 2);
      }

      // ── 2. DATA FETCH ─────────────────────────────────────
      final result = await _callApi(intent);

      // ── 3. IMPROVED LOCAL SUMMARY ─────────────────────────
      final responseText = _buildLocalSummary(intent, result);

      // ── 4. Update dashboard cards ─────────────────────────
      _dashProvider.updateFromIntent(intent, result);

      _replaceLoading(loadingId, ChatMessage(
        id:          loadingId,
        text:        responseText,
        sender:      MessageSender.ai,
        timestamp:   DateTime.now(),
        intentModel: intent,
        resultData:  result['data'] as Map<String, dynamic>?,
      ));

    } on GeminiLowConfidenceException catch (e) {
      // IMPROVEMENT 5: Clarification flow instead of hard error
      final suggestions = _buildClarificationSuggestions(e.intent);
      _replaceLoading(loadingId, ChatMessage(
        id:        loadingId,
        text:      "I'm not quite sure what you meant "
            "(${(e.confidence * 100).round()}% confidence). "
            "Did you mean one of these?",
        sender:    MessageSender.ai,
        timestamp: DateTime.now(),
        isError:   false,
        resultData: {
          'clarify':     true,
          'suggestions': suggestions,
        },
      ));
    } on GeminiUnknownIntentException {
      _replaceLoading(loadingId, ChatMessage(
        id:        loadingId,
        text:      "I can answer questions about attendance, fees, "
            "admissions, faculty, and analytics. Try asking something like:\n"
            "• Show MCA attendance today\n"
            "• How many fees are pending?\n"
            "• Compare all departments",
        sender:    MessageSender.ai,
        timestamp: DateTime.now(),
        isError:   false,
        resultData: {
          'clarify':     true,
          'suggestions': [
            'Show MCA attendance today',
            'Fee collection summary',
            'Compare all departments',
            'Faculty status today',
          ],
        },
      ));
    } on GeminiKeyMissingException {
      _replaceLoading(loadingId, _errorMessage(
        loadingId,
        '⚙️ Gemini API key not configured. Please go to Settings and add your key.',
        originalQuery: text,
      ));
    } on GeminiRateLimitException {
      _replaceLoading(loadingId, _errorMessage(
        loadingId,
        '⏳ AI rate limit reached. Please wait a moment and try again.',
        originalQuery: text,
      ));
    } on GeminiTimeoutException {
      _replaceLoading(loadingId, _errorMessage(
        loadingId,
        '⏱️ AI took too long to respond. Check your connection and retry.',
        originalQuery: text,
      ));
    } on GeminiException catch (e) {
      _replaceLoading(loadingId, _errorMessage(
        loadingId, 'AI Error: ${e.message}', originalQuery: text,
      ));
    } on ApiException catch (e) {
      _replaceLoading(loadingId, _errorMessage(
        loadingId, 'Data Error: ${e.message}', originalQuery: text,
      ));
    } catch (e) {
      _replaceLoading(loadingId, _errorMessage(
        loadingId, 'Unexpected Error: $e', originalQuery: text,
      ));
    } finally {
      _processing = false;
      notifyListeners();
    }
  }

  // IMPROVEMENT 5: Build clarification suggestions based on partial intent
  List<String> _buildClarificationSuggestions(String partialIntent) {
    if (partialIntent.contains('ATTENDANCE')) {
      return [
        'Show today\'s attendance summary',
        'List absent students today',
        'Show this week\'s attendance trend',
        'Which department has lowest attendance?',
      ];
    }
    if (partialIntent.contains('FEE')) {
      return [
        'Show fee collection summary',
        'List students with pending fees',
        'Show overdue fees',
        'Total fee collection this month',
      ];
    }
    if (partialIntent.contains('FACULTY')) {
      return [
        'How many faculty are present today?',
        'Which faculty are absent today?',
        'Show all faculty status',
      ];
    }
    if (partialIntent.contains('ADMISSION')) {
      return [
        'Show admission statistics',
        'How many applications received?',
        'Compare admissions across departments',
      ];
    }
    return [
      'Show MCA attendance today',
      'Fee collection summary',
      'Compare all departments',
      'Faculty status today',
    ];
  }

  // IMPROVEMENT 3: Insight-aware local summary builder
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
          if (total == 0) return 'No attendance records found for $dept today. '
              'Make sure attendance has been marked.';
          final pct = ((present / total) * 100).round();

          // INSIGHT based on percentage
          String insight = '';
          if (pct >= 90)      insight = ' 🟢 Excellent turnout!';
          else if (pct >= 75) insight = ' Attendance is on track.';
          else if (pct >= 60) insight = ' ⚠️ Below 75% target — follow-up needed.';
          else                insight = ' 🔴 Critical shortage — immediate action required.';

          return '**$present of $total** students present in $dept today ($pct%).$insight'
              '${absent > 0 ? ' $absent absent' : ''}'
              '${late > 0   ? ', $late late.'   : '.'}';

        case IntentConstants.getFeeSummary:
        case IntentConstants.getFees:
          final collected = (data['collected'] ?? data['total_collected'] ?? 0) as num;
          final pending   = (data['pending']   ?? data['total_pending']   ?? 0) as num;
          final overdue   = (data['overdue']   ?? data['total_overdue']   ?? 0) as num;
          final pct       = data['percentage_collected'] ?? 0;
          if (collected == 0 && pending == 0) return 'No fee data found for $dept.';

          String urgency = '';
          if ((overdue as num) > 0) {
            urgency = '\n⚠️ **₹${_fmt(overdue.toDouble())}** is overdue — requires follow-up.';
          }
          return '**Fee collection** for $dept: ₹${_fmt(collected.toDouble())} collected (**$pct%**).'
              '\n₹${_fmt(pending.toDouble())} pending.$urgency';

        case IntentConstants.getFacultyStatus:
          final s       = (data['summary'] as Map<String, dynamic>?) ?? data;
          final total   = (s['total']   ?? 0) as int;
          final present = (s['present'] ?? 0) as int;
          final absent  = (s['absent']  ?? 0) as int;
          if (total == 0) return 'No faculty data found for $dept.';
          final pct = total > 0 ? ((present / total) * 100).round() : 0;
          String status = pct >= 80 ? ' 🟢' : pct >= 60 ? ' 🟡' : ' 🔴';
          return '**$present of $total** faculty present in $dept today ($pct%).$status'
              '${absent > 0 ? ' $absent on leave.' : ''}';

        case IntentConstants.getAdmissions:
        case IntentConstants.getAdmStats:
          final applied     = data['applied']     ?? 0;
          final admitted    = data['admitted']    ?? 0;
          final shortlisted = data['shortlisted'] ?? 0;
          final rejected    = data['rejected']    ?? 0;
          return '**Admissions** for $dept:\n'
              '📋 $applied applied · ✅ $admitted admitted · '
              '⏳ $shortlisted shortlisted · ❌ $rejected rejected.';

        case IntentConstants.getDeptComparison:
          final depts = data['departments'] as List<dynamic>? ?? [];
          if (depts.isEmpty) return 'Department comparison data is currently unavailable.';
          final sorted = List.from(depts)..sort((a, b) =>
              ((b['avg_attendance_pct'] ?? 0) as num)
                  .compareTo((a['avg_attendance_pct'] ?? 0) as num));
          final best  = sorted.first;
          final worst = sorted.last;
          return '**Department comparison** loaded.\n'
              '🏆 **${best['code']}** leads with ${best['avg_attendance_pct']}% attendance.\n'
              '📉 **${worst['code']}** needs attention at ${worst['avg_attendance_pct']}%.';

        case IntentConstants.getAnalytics:
          final metric = intent.metric ?? 'attendance';
          return '**Analytics** for $dept ($metric) loaded. '
              'Check the Analytics screen for detailed charts and trends.';

        case IntentConstants.getNotifications:
          final count = data['unread_count'] ?? 0;
          return count == 0
              ? 'All caught up — no unread notifications. ✓'
              : '🔔 You have **$count** unread notification${count == 1 ? '' : 's'}.';

        case IntentConstants.generateReport:
          return '📊 Report generation request received for $dept. '
              'Check the Reports screen to download.';

        default:
          return intent.summary ?? 'Request processed successfully for $dept.';
      }
    } catch (_) {
      return intent.summary ?? 'Data retrieved for $dept.';
    }
  }

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }

  // ── API routing ───────────────────────────────────────────
  Future<Map<String, dynamic>> _callApi(IntentModel intent) async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    return await switch (intent.intent) {
      IntentConstants.getAttendance || IntentConstants.getAttSummary =>
          ApiService.instance.getAttendanceSummary(
              department: intent.department, date: today),
      IntentConstants.getFeeSummary || IntentConstants.getFees =>
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

  void _addMessage(ChatMessage m) {
    _messages.add(m);
    notifyListeners();
  }

  void _replaceLoading(String id, ChatMessage r) {
    final idx = _messages.indexWhere((m) => m.id == id);
    if (idx != -1) _messages[idx] = r;
    notifyListeners();
  }

  // IMPROVEMENT 6: Retry button — pass originalQuery in resultData
  ChatMessage _errorMessage(String id, String text, {String? originalQuery}) =>
      ChatMessage(
        id:        id,
        text:      text,
        sender:    MessageSender.ai,
        timestamp: DateTime.now(),
        isError:   true,
        resultData: originalQuery != null
            ? {'retry_query': originalQuery}
            : null,
      );

  void clearHistory() {
    _messages.clear();
    _conversationHistory.clear();
    GeminiService.instance.clearSessionContext();
    notifyListeners();
  }
}