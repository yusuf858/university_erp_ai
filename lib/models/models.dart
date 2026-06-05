// ── User Model ────────────────────────────────────────────────
class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final int? departmentId;
  final String? departmentCode;
  final String token;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.departmentId,
    this.departmentCode,
    required this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> j, String token) =>
      UserModel(
        id:             j['user_id'] ?? j['id'] ?? 0,
        name:           j['name'] ?? '',
        email:          j['email'] ?? '',
        role:           j['role'] ?? '',
        departmentId:   j['department_id'],
        departmentCode: j['department_code'],
        token:          token,
      );

  String get displayRole {
    switch (role) {
      case 'vc':      return 'Vice Chancellor';
      case 'hod':     return 'Head of Department';
      case 'admin':   return 'Administrator';
      case 'faculty': return 'Faculty';
      case 'student': return 'Student';
      default:        return role.toUpperCase();
    }
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}

// ── Intent Model ──────────────────────────────────────────────
class IntentModel {
  final String intent;
  final String? department;
  final int? semester;
  final String? date;
  final String? status;
  final String? faculty;
  final String? academicYear;
  final String? metric;
  final int? periodDays;
  final double confidence;
  final String? summary;

  const IntentModel({
    required this.intent,
    this.department,
    this.semester,
    this.date,
    this.status,
    this.faculty,
    this.academicYear,
    this.metric,
    this.periodDays,
    this.confidence = 0.0,
    this.summary,
  });

  factory IntentModel.fromJson(Map<String, dynamic> j) => IntentModel(
    intent:       j['intent'] ?? 'UNKNOWN',
    department:   j['department'],
    semester:     j['semester'] is int ? j['semester'] : null,
    date:         j['date'],
    status:       j['status'],
    faculty:      j['faculty'],
    academicYear: j['academic_year'],
    metric:       j['metric'],
    periodDays:   j['period_days'] is int ? j['period_days'] : null,
    confidence:   (j['confidence'] ?? 0.0).toDouble(),
    summary:      j['summary'],
  );

  IntentModel copyWith({String? department, String? date}) => IntentModel(
    intent:       intent,
    department:   department ?? this.department,
    semester:     semester,
    date:         date ?? this.date,
    status:       status,
    faculty:      faculty,
    academicYear: academicYear,
    metric:       metric,
    periodDays:   periodDays,
    confidence:   confidence,
    summary:      summary,
  );

  bool get isValid =>
      confidence >= 0.75 && intent != 'UNKNOWN';
}

// ── Attendance Models ──────────────────────────────────────────
class AttendanceSummary {
  final int total;
  final int present;
  final int absent;
  final int late;
  final String? department;
  final String? date;

  const AttendanceSummary({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    this.department,
    this.date,
  });

  factory AttendanceSummary.fromJson(Map<String, dynamic> j) =>
      AttendanceSummary(
        total:      j['total'] ?? 0,
        present:    j['present'] ?? 0,
        absent:     j['absent'] ?? 0,
        late:       j['late'] ?? 0,
        department: j['department'],
        date:       j['date'],
      );

  factory AttendanceSummary.empty() =>
      const AttendanceSummary(total: 0, present: 0, absent: 0, late: 0);

  double get presentPercent =>
      total == 0 ? 0 : (present / total * 100);
}

class AttendanceRecord {
  final String usn;
  final String studentName;
  final String department;
  final int semester;
  final String status;
  final String date;
  final String course;

  const AttendanceRecord({
    required this.usn,
    required this.studentName,
    required this.department,
    required this.semester,
    required this.status,
    required this.date,
    required this.course,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) =>
      AttendanceRecord(
        usn:         j['usn'] ?? '',
        studentName: j['student_name'] ?? '',
        department:  j['department'] ?? '',
        semester:    j['semester'] ?? 0,
        status:      j['status'] ?? '',
        date:        j['date'] ?? '',
        course:      j['course'] ?? '',
      );
}

// ── Fee Models ────────────────────────────────────────────────
class FeeSummary {
  final double totalAmount;
  final double collected;
  final double pending;
  final double overdue;
  final int    overdueCount;
  final double collectionPercent;

  const FeeSummary({
    required this.totalAmount,
    required this.collected,
    required this.pending,
    required this.overdue,
    required this.overdueCount,
    required this.collectionPercent,
  });

  factory FeeSummary.fromJson(Map<String, dynamic> j) => FeeSummary(
    totalAmount:       (j['total_fees'] ?? 0).toDouble(),
    collected:         (j['collected'] ?? 0).toDouble(),
    pending:           (j['pending'] ?? 0).toDouble(),
    overdue:           (j['overdue'] ?? 0).toDouble(),
    overdueCount:      j['overdue_count'] ?? 0,
    collectionPercent: (j['percentage_collected'] ?? 0).toDouble(),
  );

  factory FeeSummary.empty() => const FeeSummary(
    totalAmount: 0, collected: 0, pending: 0,
    overdue: 0, overdueCount: 0, collectionPercent: 0,
  );
}

// ── Faculty Model ─────────────────────────────────────────────
class FacultyModel {
  final String employeeId;
  final String name;
  final String designation;
  final String department;
  final bool isPresent;

  const FacultyModel({
    required this.employeeId,
    required this.name,
    required this.designation,
    required this.department,
    required this.isPresent,
  });

  factory FacultyModel.fromJson(Map<String, dynamic> j) => FacultyModel(
    employeeId:  j['employee_id'] ?? '',
    name:        j['name'] ?? '',
    designation: j['designation'] ?? '',
    department:  j['department'] ?? '',
    isPresent:   (j['is_present'] ?? 1) == 1,
  );
}

class FacultyStatusSummary {
  final int total;
  final int present;
  final int absent;
  final List<FacultyModel> faculty;

  const FacultyStatusSummary({
    required this.total,
    required this.present,
    required this.absent,
    required this.faculty,
  });

  factory FacultyStatusSummary.empty() => const FacultyStatusSummary(
    total: 0, present: 0, absent: 0, faculty: [],
  );
}

// ── Analytics Model ───────────────────────────────────────────
class TrendPoint {
  final String label;
  final double value;

  const TrendPoint({required this.label, required this.value});

  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
    label: j['label'] ?? '',
    value: (j['value'] ?? 0).toDouble(),
  );
}

class DeptComparison {
  final String deptCode;
  final double attendancePct;
  final double feeCollectionPct;
  final double admissionFillRate;
  final int    totalStudents;

  const DeptComparison({
    required this.deptCode,
    required this.attendancePct,
    required this.feeCollectionPct,
    required this.admissionFillRate,
    required this.totalStudents,
  });

  factory DeptComparison.fromJson(Map<String, dynamic> j) => DeptComparison(
    deptCode:          j['code'] ?? '',
    attendancePct:     (j['avg_attendance_pct'] ?? 0).toDouble(),
    feeCollectionPct:  (j['fee_collection_pct'] ?? 0).toDouble(),
    admissionFillRate: (j['admission_fill_rate'] ?? 0).toDouble(),
    totalStudents:     j['total_students'] ?? 0,
  );
}

// ── Report Model ──────────────────────────────────────────────
class ReportModel {
  final int id;
  final String title;
  final String type; // PDF, CSV
  final String status; // READY, GENERATING
  final String createdAt;
  final String? downloadUrl;
  final String size;

  const ReportModel({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    required this.createdAt,
    this.downloadUrl,
    required this.size,
  });

  factory ReportModel.fromJson(Map<String, dynamic> j) => ReportModel(
    id:          j['id'] ?? 0,
    title:       j['title'] ?? '',
    type:        j['type'] ?? 'PDF',
    status:      j['status'] ?? 'READY',
    createdAt:   j['created_at'] ?? '',
    downloadUrl: j['download_url'],
    size:        j['size'] ?? '0 KB',
  );
}

// ── Chat Message Model ────────────────────────────────────────
enum MessageSender { user, ai }

class ChatMessage {
  final String id;
  final String text;
  final MessageSender sender;
  final DateTime timestamp;
  final IntentModel? intentModel;
  final bool isLoading;
  final bool isError;
  final Map<String, dynamic>? resultData;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.sender,
    required this.timestamp,
    this.intentModel,
    this.isLoading = false,
    this.isError   = false,
    this.resultData,
  });

  ChatMessage copyWith({
    String? text,
    bool? isLoading,
    bool? isError,
    IntentModel? intentModel,
    Map<String, dynamic>? resultData,
  }) =>
      ChatMessage(
        id:          id,
        text:        text ?? this.text,
        sender:      sender,
        timestamp:   timestamp,
        intentModel: intentModel ?? this.intentModel,
        isLoading:   isLoading ?? this.isLoading,
        isError:     isError ?? this.isError,
        resultData:  resultData ?? this.resultData,
      );
}

// ── Notification Model ────────────────────────────────────────
class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final String priority;
  final bool isRead;
  final String createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.priority,
    required this.isRead,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> j) =>
      NotificationModel(
        id:        j['id'] ?? 0,
        title:     j['title'] ?? '',
        message:   j['message'] ?? '',
        type:      j['type'] ?? 'info',
        priority:  j['priority'] ?? 'medium',
        isRead:    (j['is_read'] ?? 0) == 1,
        createdAt: j['created_at'] ?? '',
      );
}

// ── Dashboard Data aggregate ──────────────────────────────────
class DashboardData {
  final AttendanceSummary attendance;
  final FeeSummary fees;
  final FacultyStatusSummary faculty;
  final int unreadNotifications;

  const DashboardData({
    required this.attendance,
    required this.fees,
    required this.faculty,
    required this.unreadNotifications,
  });

  factory DashboardData.empty() => DashboardData(
    attendance:           AttendanceSummary.empty(),
    fees:                 FeeSummary.empty(),
    faculty:              FacultyStatusSummary.empty(),
    unreadNotifications:  0,
  );
}