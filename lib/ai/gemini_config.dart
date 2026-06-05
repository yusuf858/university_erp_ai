class GeminiConfig {
  GeminiConfig._();

  // ── Model ────────────────────────────────────────────────
  static const String model = 'gemini-2.5-flash';

  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

  // ── Intent Extraction parameters ─────────────────────────
  static const double intentTemperature = 0.1;
  static const int intentMaxTokens = 512;
  static const int intentTimeoutSeconds = 20;

  // ── Summary Generation parameters ────────────────────────
  static const double summaryTemperature = 0.3;
  static const int summaryMaxTokens = 200;
  static const int summaryTimeoutSeconds = 15;

  // ── Validation gate ──────────────────────────────────────
  static const double minConfidence = 0.75;
  static const double clarifyConfidence = 0.60;

  // ── Cooldowns ─────────────────────────────────────────────
  static const int callCooldownMs = 3000;
  static const int retryDelayMs = 2000;

  // ── Supported Registry ────────────────────────────────────
  static const Set<String> supportedIntents = {
    'GET_ATTENDANCE',
    'GET_ATTENDANCE_SUMMARY',
    'GET_FEES',
    'GET_FEE_SUMMARY',
    'GET_ADMISSIONS',
    'GET_ADMISSION_STATS',
    'GET_FACULTY_STATUS',
    'GET_ANALYTICS',
    'GET_DEPT_COMPARISON',
    'GET_NOTIFICATIONS',
    'GET_REPORTS',
    'GENERATE_REPORT',
    'UNKNOWN',
  };

  static const Set<String> validDepartments = {'MCA', 'BCA', 'MBA', 'MTECH'};
  static const Set<String> validDateTokens = {
    'TODAY',
    'YESTERDAY',
    'THIS_WEEK',
    'THIS_MONTH'
  };
  static const Set<String> validAttendanceStatus = {'present', 'absent', 'late'};
  static const Set<String> validFeeStatus = {
    'paid',
    'pending',
    'partial',
    'overdue'
  };
  static const Set<String> validMetrics = {
    'attendance',
    'fees',
    'admissions',
    'faculty'
  };
}