import '../../models/models.dart';
import 'domain_prompts.dart';

/// IMPROVED: 4-layer prompt system
/// Layer 1: system context + role injection
/// Layer 2: domain-specific extension
/// Layer 3: conversation history for pronoun/context resolution
/// Layer 4: output schema + user query
class PromptBuilder {
  PromptBuilder._();

  // ── Intent extraction prompt ──────────────────────────────
  static String buildIntentPrompt({
    required String      query,
    required String      role,
    String?              deptCode,
    IntentModel?         sessionContext,
    List<Map<String, String>>? conversationHistory,
  }) {
    final systemBlock      = _buildSystemBlock(role, deptCode, sessionContext);
    final domainBlock      = DomainSelector.selectExtension(query);
    // IMPROVEMENT 1: inject conversation history
    final historyBlock     = _buildHistoryBlock(conversationHistory);
    // IMPROVEMENT 2: inject role-aware few-shot examples
    final roleExampleBlock = _buildRoleExamples(role, deptCode, query);

    return '''
$systemBlock

${domainBlock.isNotEmpty ? '$domainBlock\n' : ''}
${roleExampleBlock.isNotEmpty ? '$roleExampleBlock\n' : ''}
${historyBlock.isNotEmpty ? '$historyBlock\n' : ''}
User query: "$query"''';
  }

  // ── Summary generation prompt ─────────────────────────────
  static String buildSummaryPrompt({
    required String               intent,
    required String               department,
    required Map<String, dynamic> data,
    required String               role,
  }) {
    final toneInstruction = _toneForRole(role);
    final dataDigest      = _digestData(intent, data);

    return '''
You are a university ERP voice assistant.
Generate a natural spoken summary of the following data.

$toneInstruction

Constraints:
- Maximum 2 sentences
- Maximum 30 words total
- Use numbers only (no percentages unless explicitly helpful)
- Present tense, active voice
- No markdown, no special characters
- Speak as if reading a brief to a senior official

Intent: $intent
Department: $department
Data: $dataDigest

Return ONLY the spoken summary text — no JSON, no labels, no explanation.''';
  }

  // ── Key validation prompt ─────────────────────────────────
  static String buildKeyTestPrompt() =>
      'Return exactly this JSON and nothing else: {"status":"ok"}';

  // ── IMPROVEMENT 1: Conversation history block ─────────────
  static String _buildHistoryBlock(List<Map<String, String>>? history) {
    if (history == null || history.isEmpty) return '';

    // Take last 6 messages (3 pairs) for context — enough without bloating prompt
    final recent = history.length > 6
        ? history.sublist(history.length - 6)
        : history;

    final lines = recent.map((m) {
      final speaker = m['role'] == 'user' ? 'User' : 'AI';
      return '$speaker: ${m['content']}';
    }).join('\n');

    return '''
Recent conversation context (use ONLY to resolve pronouns like "their", "same", "also", "that department"):
$lines''';
  }

  // ── IMPROVEMENT 2: Role-aware few-shot examples ───────────
  static String _buildRoleExamples(String role, String? dept, String query) {
    final lower = query.toLowerCase();

    // Only inject role examples when query is short/ambiguous
    final isAmbiguous = query.split(' ').length <= 5;
    if (!isAmbiguous) return '';

    switch (role) {
      case 'vc':
        return '''
VC-specific query examples:
  "how are we doing" → intent:GET_DEPT_COMPARISON, metric:attendance, confidence:0.90
  "overall performance" → intent:GET_ANALYTICS, department:null, metric:attendance, confidence:0.88
  "university status" → intent:GET_DEPT_COMPARISON, confidence:0.92
  "which department is best" → intent:GET_DEPT_COMPARISON, metric:attendance, confidence:0.94''';

      case 'hod':
        return '''
HOD-specific query examples (default dept = "$dept"):
  "how are my students" → intent:GET_ATTENDANCE_SUMMARY, department:$dept, date:TODAY, confidence:0.95
  "today attendance" → intent:GET_ATTENDANCE_SUMMARY, department:$dept, date:TODAY, confidence:0.97
  "pending fees" → intent:GET_FEE_SUMMARY, department:$dept, status:pending, confidence:0.96
  "my faculty today" → intent:GET_FACULTY_STATUS, department:$dept, date:TODAY, confidence:0.95
  "defaulters" → intent:GET_FEES, department:$dept, status:overdue, confidence:0.94''';

      case 'faculty':
        return '''
Faculty-specific query examples (default dept = "$dept"):
  "my class today" → intent:GET_ATTENDANCE, department:$dept, date:TODAY, confidence:0.95
  "absent students" → intent:GET_ATTENDANCE, department:$dept, date:TODAY, status:absent, confidence:0.96
  "who came late" → intent:GET_ATTENDANCE, department:$dept, date:TODAY, status:late, confidence:0.95''';

      case 'admin':
        return '''
Admin-specific query examples:
  "fee collection" → intent:GET_FEE_SUMMARY, department:null, confidence:0.95
  "today summary" → intent:GET_DEPT_COMPARISON, confidence:0.90
  "overdue fees" → intent:GET_FEE_SUMMARY, status:overdue, confidence:0.94
  "admissions status" → intent:GET_ADMISSION_STATS, confidence:0.93''';

      default:
        return '';
    }
  }

  // ── Private: system block ─────────────────────────────────
  static String _buildSystemBlock(
      String       role,
      String?      deptCode,
      IntentModel? sessionContext,
      ) {
    final roleScope    = _roleScopeInstruction(role, deptCode);
    final sessionBlock = _sessionBlock(sessionContext);

    return '''
You are an AI assistant embedded in a university ERP management dashboard.
Your sole job: analyse voice/text queries and return structured intent JSON.
You do NOT query databases. You do NOT answer questions. You ONLY extract intent.

ABSOLUTE RULES:
  RULE 1: Return ONLY valid JSON — zero prose, zero explanation, zero markdown fences.
  RULE 2: Every field in the schema is required. Use null for unknown fields; never omit them.
  RULE 3: intent must be exactly one of the supported constants. If nothing fits, use UNKNOWN.
  RULE 4: Never invent department codes, student names, or data values.
  RULE 5: Never return partial JSON or truncate the response.
  RULE 6: department must be null or one of: MCA, BCA, MBA, MTECH exactly.
  RULE 7: If uncertain, return your best attempt with a lower confidence score.
  RULE 8: When conversation history is present, use it to resolve pronouns and references.

User role: $role
$roleScope
$sessionBlock

Supported intents:
  GET_ATTENDANCE, GET_ATTENDANCE_SUMMARY, GET_FEES, GET_FEE_SUMMARY,
  GET_ADMISSIONS, GET_ADMISSION_STATS, GET_FACULTY_STATUS, GET_ANALYTICS,
  GET_DEPT_COMPARISON, GET_NOTIFICATIONS, GET_REPORTS, GENERATE_REPORT, UNKNOWN

Entity rules:
  department   → null or one of: MCA, BCA, MBA, MTECH
  semester     → integer 1–6 or null
  date         → TODAY | YESTERDAY | THIS_WEEK | THIS_MONTH | YYYY-MM-DD (default: TODAY)
  status       → attendance: present|absent|late  /  fees: paid|pending|partial|overdue  /  null
  faculty      → name fragment if specific person mentioned, else null
  academic_year→ YYYY-YYYY format or null
  metric       → attendance | fees | admissions | faculty | null
  period_days  → integer (7=week, 30=month, 90=quarter) or null
  confidence   → float 0.00–1.00 reflecting your certainty
  summary      → one sentence describing what you understood (always populate)

Required output schema (return EXACTLY this structure):
{
  "intent": "INTENT_CONSTANT",
  "department": null,
  "semester": null,
  "date": "TODAY",
  "status": null,
  "faculty": null,
  "academic_year": null,
  "metric": null,
  "period_days": null,
  "confidence": 0.95,
  "summary": "one sentence describing what was understood"
}''';
  }

  static String _roleScopeInstruction(String role, String? dept) {
    switch (role) {
      case 'hod':
        return 'Role scope: HOD of $dept. '
            'Default department = "$dept" when none is mentioned in query. '
            'Never scope to other departments unless user explicitly names one.';
      case 'faculty':
        return 'Role scope: Faculty in $dept. Default department = "$dept".';
      case 'vc':
      case 'admin':
        return 'Role scope: University-wide access. Do NOT auto-scope to any department.';
      default:
        return 'Role scope: Standard access.';
    }
  }

  static String _sessionBlock(IntentModel? ctx) {
    if (ctx == null) return '';
    return '''
Previous query context (use ONLY for pronoun resolution — "their", "same", "also"):
  intent:     ${ctx.intent}
  department: ${ctx.department ?? 'none'}
  date:       ${ctx.date ?? 'none'}
  semester:   ${ctx.semester ?? 'none'}''';
  }

  static String _toneForRole(String role) => switch (role) {
    'vc'    => 'Tone: Brief executive summary for the Vice Chancellor.',
    'hod'   => 'Tone: Clear departmental update for the Head of Department.',
    'admin' => 'Tone: Factual administrative summary.',
    _       => 'Tone: Clear and helpful summary.',
  };

  static String _digestData(String intent, Map<String, dynamic> data) {
    final d = data['data'] as Map<String, dynamic>? ?? data;

    if (intent.contains('ATTENDANCE')) {
      final s = d['summary'] as Map<String, dynamic>? ?? {};
      return 'total=${s['total']}, present=${s['present']}, '
          'absent=${s['absent']}, late=${s['late']}';
    }
    if (intent.contains('FEE')) {
      return 'collected=${d['collected']}, pending=${d['pending']}, '
          'overdue=${d['overdue']}, pct=${d['percentage_collected']}';
    }
    if (intent.contains('FACULTY')) {
      final s = d['summary'] as Map<String, dynamic>? ?? {};
      return 'total=${s['total']}, present=${s['present']}, absent=${s['absent']}';
    }
    if (intent.contains('ADMISSION')) {
      return 'applied=${d['applied']}, admitted=${d['admitted']}, '
          'shortlisted=${d['shortlisted']}, rejected=${d['rejected']}';
    }
    return data.toString().substring(0, data.toString().length.clamp(0, 200));
  }
}