/// Domain-specific prompt extensions appended to the base system prompt.
/// Each class owns the vocabulary, examples, and edge-case handling
/// for one ERP domain. GeminiService selects the right one via keyword scan.

abstract class DomainPrompt {
  String get extension;
  List<String> get keywords;
}

// ── 1. Attendance ─────────────────────────────────────────────
class AttendancePrompt implements DomainPrompt {
  const AttendancePrompt();

  @override
  List<String> get keywords => const [
    'attend', 'present', 'absent', 'late', 'bunk', 'bunked', 'bunking',
    'lecture', 'class', 'shortage', 'miss', 'missed', 'proxy',
  ];

  @override
  String get extension => '''
ATTENDANCE DOMAIN EXTENSION:
- "bunked" / "bunking" / "missed class" → status: absent
- "came late" / "late entry" → status: late
- "on duty" / "OD" → treat as absent for attendance query
- "short attendance" / "shortage" → GET_ATTENDANCE_SUMMARY without status filter
- "defaulters" (in attendance context) → status: absent
- If asking for a count/number → prefer GET_ATTENDANCE_SUMMARY (faster)
- If asking for a list/names → prefer GET_ATTENDANCE (full records)

Attendance examples:
  "how many MCA students absent today"
  → intent:GET_ATTENDANCE_SUMMARY, department:MCA, date:TODAY, status:absent, confidence:0.97

  "show semester 3 attendance this week"
  → intent:GET_ATTENDANCE, semester:3, date:THIS_WEEK, status:null, confidence:0.94

  "list students who were late in BCA"
  → intent:GET_ATTENDANCE, department:BCA, date:TODAY, status:late, confidence:0.92

  "attendance trend for MCA last month"
  → intent:GET_ANALYTICS, department:MCA, metric:attendance, period_days:30, confidence:0.95

  "which students bunked today"
  → intent:GET_ATTENDANCE, date:TODAY, status:absent, confidence:0.93''';
}

// ── 2. Fees ───────────────────────────────────────────────────
class FeesPrompt implements DomainPrompt {
  const FeesPrompt();

  @override
  List<String> get keywords => const [
    'fee', 'fees', 'paid', 'unpaid', 'payment', 'pending', 'due',
    'overdue', 'defaulter', 'challan', 'receipt', 'collection',
    'outstanding', 'tuition', 'dues', 'cleared', 'partial',
  ];

  @override
  String get extension => '''
FEES DOMAIN EXTENSION:
- "defaulters" (fee context) → status: overdue
- "unpaid" → status: pending OR overdue (use pending as default)
- "cleared" / "settled" → status: paid
- "partially paid" → status: partial
- "dues" → status: pending
- All amounts are Indian Rupees (INR). Do not convert.
- If asking for a summary/total → prefer GET_FEE_SUMMARY
- If asking for a list of students → prefer GET_FEES

Fees examples:
  "how many students paid fees this semester"
  → intent:GET_FEES, status:paid, confidence:0.95

  "total fee collection this month"
  → intent:GET_FEE_SUMMARY, date:THIS_MONTH, confidence:0.96

  "show pending fees for MCA"
  → intent:GET_FEES, department:MCA, status:pending, confidence:0.97

  "list fee defaulters in semester 2"
  → intent:GET_FEES, semester:2, status:overdue, confidence:0.94

  "how much fees are outstanding university wide"
  → intent:GET_FEE_SUMMARY, status:pending, department:null, confidence:0.93''';
}

// ── 3. Admissions ─────────────────────────────────────────────
class AdmissionsPrompt implements DomainPrompt {
  const AdmissionsPrompt();

  @override
  List<String> get keywords => const [
    'admission', 'admissions', 'apply', 'applied', 'application',
    'shortlist', 'shortlisted', 'admit', 'admitted', 'reject', 'rejected',
    'seat', 'seats', 'intake', 'candidate', 'waitlist', 'selection',
  ];

  @override
  String get extension => '''
ADMISSIONS DOMAIN EXTENSION:
- "selected" → status: admitted
- "waiting list" / "waitlisted" → status: shortlisted
- "new applications" / "received" → status: applied
- "filled seats" / "joined" → status: admitted
- "how many seats filled" → GET_ADMISSIONS, status: admitted

Department intake capacities (for summary field only, never invent actual counts):
  MCA: 60 seats, BCA: 120 seats, MBA: 60 seats, MTECH: 30 seats

Admissions examples:
  "how many applications received for MCA this year"
  → intent:GET_ADMISSIONS, department:MCA, status:applied, confidence:0.96

  "admissions funnel comparison across departments"
  → intent:GET_ADMISSION_STATS, department:null, confidence:0.94

  "show shortlisted candidates for BCA"
  → intent:GET_ADMISSIONS, department:BCA, status:shortlisted, confidence:0.95

  "how many seats are filled in MBA"
  → intent:GET_ADMISSIONS, department:MBA, status:admitted, confidence:0.96''';
}

// ── 4. Faculty ────────────────────────────────────────────────
class FacultyPrompt implements DomainPrompt {
  const FacultyPrompt();

  @override
  List<String> get keywords => const [
    'faculty', 'professor', 'staff', 'teacher', 'lecturer', 'hod',
    'sir', 'madam', 'on leave', 'leave', 'joining', 'employee',
  ];

  @override
  String get extension => '''
FACULTY DOMAIN EXTENSION:
- Faculty status always refers to TODAY unless a specific date is mentioned
- "on leave" / "taking leave" / "not available" → status: absent
- "came in" / "in campus" → status: present
- If a specific faculty name is mentioned, populate the faculty field
  with their name fragment (e.g. "Naik" not "Prof. Naik")
- Historical faculty attendance is not supported in Phase 1

Faculty examples:
  "how many faculty are present today"
  → intent:GET_FACULTY_STATUS, status:present, date:TODAY, confidence:0.97

  "which MCA faculty are absent"
  → intent:GET_FACULTY_STATUS, department:MCA, status:absent, date:TODAY, confidence:0.95

  "is Professor Naik present today"
  → intent:GET_FACULTY_STATUS, faculty:Naik, date:TODAY, confidence:0.93

  "show all faculty status"
  → intent:GET_FACULTY_STATUS, status:null, date:TODAY, confidence:0.96''';
}

// ── 5. Analytics ──────────────────────────────────────────────
class AnalyticsPrompt implements DomainPrompt {
  const AnalyticsPrompt();

  @override
  List<String> get keywords => const [
    'analytics', 'analysis', 'trend', 'trends', 'chart', 'graph',
    'compare', 'comparison', 'performance', 'statistics', 'stats',
    'report', 'generate', 'overview', 'summary report',
    'week', 'month', 'quarter', 'semester', 'last', 'past',
  ];

  @override
  String get extension => '''
ANALYTICS DOMAIN EXTENSION:
- "performance" → metric: attendance (default)
- "collection" / "collection rate" → metric: fees
- "intake" / "fill rate" → metric: admissions
- For comparison across departments → GET_DEPT_COMPARISON
- Period mapping: "last week"=7, "last month"=30, "this semester"=90, "last quarter"=90
- If user says "generate", "create", "give me", "make" a report → GENERATE_REPORT
- If no period mentioned → default period_days: 30

Analytics examples:
  "show attendance trend for MCA last month"
  → intent:GET_ANALYTICS, department:MCA, metric:attendance, period_days:30, confidence:0.97

  "compare all departments"
  → intent:GET_DEPT_COMPARISON, department:null, confidence:0.96

  "generate monthly attendance report for MCA"
  → intent:GENERATE_REPORT, department:MCA, metric:attendance, period_days:30, confidence:0.95

  "fee collection trend this quarter"
  → intent:GET_ANALYTICS, metric:fees, period_days:90, confidence:0.94

  "which department has the best attendance"
  → intent:GET_DEPT_COMPARISON, metric:attendance, confidence:0.93''';
}

// ── Selector — picks the right extension from a transcript ────
class DomainSelector {
  static const _domains = <DomainPrompt>[
    AttendancePrompt(),
    FeesPrompt(),
    AdmissionsPrompt(),
    FacultyPrompt(),
    AnalyticsPrompt(),
  ];

  /// Returns the domain extension text for the given transcript.
  /// Falls back to empty string if no domain keywords are found.
  static String selectExtension(String transcript) {
    final lower = transcript.toLowerCase();

    // Score each domain by how many keywords appear
    int bestScore = 0;
    DomainPrompt? bestDomain;

    for (final domain in _domains) {
      final score = domain.keywords
          .where((k) => lower.contains(k))
          .length;
      if (score > bestScore) {
        bestScore = score;
        bestDomain = domain;
      }
    }

    return bestDomain?.extension ?? '';
  }

  /// Returns all matched domains for a transcript (for multi-intent prompts).
  static List<String> selectAllExtensions(String transcript) {
    final lower = transcript.toLowerCase();
    return _domains
        .where((d) => d.keywords.any((k) => lower.contains(k)))
        .map((d) => d.extension)
        .toList();
  }
}