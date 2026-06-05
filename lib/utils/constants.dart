class AppConstants {
  AppConstants._();

  // ── IMPORTANT: UPDATE THIS IP TO YOUR CURRENT COMPUTER IP ──
  static const String baseUrl = 'http://172.21.2.122/university_erp/api';

  // ── Endpoints ─────────────────────────────────────────────
  static const String loginEndpoint       = '/auth/login.php';
  static const String attendanceEndpoint  = '/attendance/get_attendance.php';
  static const String attSummaryEndpoint  = '/attendance/get_summary.php';
  static const String feesEndpoint        = '/fees/get_fees.php';
  static const String feeSummaryEndpoint  = '/fees/get_fee_summary.php';
  static const String admissionsEndpoint  = '/admissions/get_admissions.php';
  static const String facultyEndpoint     = '/faculty/get_faculty_status.php';
  static const String analyticsEndpoint   = '/analytics/get_analytics.php';
  static const String deptCompareEndpoint = '/analytics/get_dept_comparison.php';
  static const String trendEndpoint       = '/analytics/get_trend.php';
  static const String notifEndpoint       = '/notifications/get_notifications.php';
  static const String reportsEndpoint     = '/reports/get_reports.php';
  static const String voiceLogEndpoint    = '/ai/log_voice_command.php';

  // ── AI settings ───────────────────────────────────────────
  static const double confidenceThreshold  = 0.75;
  static const int    geminiTimeoutSeconds = 20; 
  static const int    apiTimeoutSeconds    = 10;
  static const int    callCooldownMs       = 3000; 

  // ── Voice & TTS ───────────────────────────────────────────
  static const int voiceMaxSeconds   = 15;
  static const int voicePauseSeconds = 3;
  static const String voiceLocale    = 'en_IN';
  static const String ttsLanguage    = 'en-IN';
  static const double ttsSpeechRate  = 0.5;
  static const double ttsVolume      = 1.0;
  static const double ttsPitch       = 1.0;

  // ── Animation durations ────────────────────────────────────
  static const Duration animFast   = Duration(milliseconds: 200);
  static const Duration animNormal = Duration(milliseconds: 350);
  static const Duration animSlow   = Duration(milliseconds: 600);
  static const Duration shimmerPeriod = Duration(milliseconds: 1500);

  // ── Layout ────────────────────────────────────────────────
  static const double paddingXS  = 4.0;
  static const double paddingSM  = 8.0;
  static const double paddingMD  = 12.0;
  static const double paddingLG  = 16.0;
  static const double paddingXL  = 24.0;
  static const double radiusMD = 10.0;
  static const double radiusLG = 12.0;
  static const double radiusXL = 16.0;
  static const double navBarHeight = 60.0;
  
  // FIXED: Restored missing constant
  static const double cardMinHeight = 120.0;
}

class StorageKeys {
  StorageKeys._();
  static const String jwtToken    = 'jwt_token';
  static const String geminiApiKey= 'gemini_api_key';
  static const String userRole    = 'user_role';
  static const String deptCode    = 'dept_code';
  static const String userName    = 'user_name';
  static const String userId      = 'user_id';
  
  // FIXED: Restored missing member
  static const String deptId      = 'dept_id';
}

class UserRole {
  static const String vc      = 'vc';
  static const String hod     = 'hod';
  static const String admin   = 'admin';
  static const String faculty = 'faculty';
  static const String student = 'student';
}

class IntentConstants {
  static const String getAttendance     = 'GET_ATTENDANCE';
  static const String getAttSummary     = 'GET_ATTENDANCE_SUMMARY';
  static const String getFees           = 'GET_FEES';
  static const String getFeeSummary     = 'GET_FEE_SUMMARY';
  static const String getAdmissions     = 'GET_ADMISSIONS';
  static const String getFacultyStatus  = 'GET_FACULTY_STATUS';
  static const String getAnalytics      = 'GET_ANALYTICS';
  static const String getDeptComparison = 'GET_DEPT_COMPARISON';
  static const String getNotifications  = 'GET_NOTIFICATIONS';
  static const String getReports        = 'GET_REPORTS';
  static const String generateReport    = 'GENERATE_REPORT';
  static const String unknown           = 'UNKNOWN';
  
  // FIXED: Restored missing member
  static const String getAdmStats       = 'GET_ADMISSION_STATS';
}
