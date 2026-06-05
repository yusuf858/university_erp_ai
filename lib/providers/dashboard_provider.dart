import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum DashboardStatus { idle, loading, loaded, error }

class DashboardProvider extends ChangeNotifier {
  DashboardStatus _status = DashboardStatus.idle;
  DashboardData   _data   = DashboardData.empty();
  String          _error  = '';
  DateTime?       _lastLoaded;
  bool            _silentRefresh = false; // IMPROVEMENT 7

  DashboardStatus      get status               => _status;
  DashboardData        get data                 => _data;
  String               get error                => _error;
  // IMPROVEMENT 7: isLoading is false during silent refresh
  bool                 get isLoading            => _status == DashboardStatus.loading && !_silentRefresh;
  bool                 get hasData              => _status == DashboardStatus.loaded;
  AttendanceSummary    get attendance           => _data.attendance;
  FeeSummary           get fees                 => _data.fees;
  FacultyStatusSummary get faculty              => _data.faculty;
  int                  get unreadNotifications  => _data.unreadNotifications;

  // ── IMPROVEMENT 7: silent refresh support ────────────────
  Future<void> loadDashboard({
    String? department,
    bool    silent = false,
  }) async {
    // Skip if recently loaded and not forced
    if (!silent &&
        _lastLoaded != null &&
        DateTime.now().difference(_lastLoaded!).inMinutes < 2 &&
        _status == DashboardStatus.loaded) return;

    _error         = '';
    _silentRefresh = silent;

    if (!silent) _setStatus(DashboardStatus.loading);

    try {
      final results = await Future.wait([
        _loadAttendance(department),
        _loadFees(department),
        _loadFaculty(department),
        _loadNotifCount(),
      ], eagerError: false);

      _data = DashboardData(
        attendance:          results[0] as AttendanceSummary,
        fees:                results[1] as FeeSummary,
        faculty:             results[2] as FacultyStatusSummary,
        unreadNotifications: results[3] as int,
      );

      _lastLoaded    = DateTime.now();
      _silentRefresh = false;
      _setStatus(DashboardStatus.loaded);
    } catch (e) {
      _silentRefresh = false;
      if (!silent) {
        _error = 'Failed to load dashboard. Tap to retry.';
        _setStatus(DashboardStatus.error);
      }
    }
  }

  // ── Update single card from voice/chat intent ─────────────
  void updateFromIntent(
      IntentModel          intent,
      Map<String, dynamic> apiData,
      ) {
    final data = apiData['data'] as Map<String, dynamic>?;
    if (data == null) return;

    switch (intent.intent) {
      case 'GET_ATTENDANCE':
      case 'GET_ATTENDANCE_SUMMARY':
      // Handle both flat and nested summary formats
        final summary = data['summary'] as Map<String, dynamic>? ?? data;
        if ((summary['total'] ?? 0) > 0) {
          _data = DashboardData(
            attendance:          AttendanceSummary.fromJson(summary),
            fees:                _data.fees,
            faculty:             _data.faculty,
            unreadNotifications: _data.unreadNotifications,
          );
        }
        break;

      case 'GET_FEE_SUMMARY':
      case 'GET_FEES':
        _data = DashboardData(
          attendance:          _data.attendance,
          fees:                FeeSummary.fromJson(data),
          faculty:             _data.faculty,
          unreadNotifications: _data.unreadNotifications,
        );
        break;

      case 'GET_FACULTY_STATUS':
        final summary = data['summary'] as Map<String, dynamic>? ?? data;
        if ((summary['total'] ?? 0) > 0) {
          _data = DashboardData(
            attendance: _data.attendance,
            fees:       _data.fees,
            faculty: FacultyStatusSummary(
              total:   summary['total']   ?? 0,
              present: summary['present'] ?? 0,
              absent:  summary['absent']  ?? 0,
              faculty: [],
            ),
            unreadNotifications: _data.unreadNotifications,
          );
        }
        break;
    }
    notifyListeners();
  }

  // ── Private loaders ───────────────────────────────────────
  Future<AttendanceSummary> _loadAttendance(String? dept) async {
    try {
      final today = _todayStr();
      final res   = await ApiService.instance
          .getAttendanceSummary(department: dept, date: today);
      // Handle both flat and nested response formats
      final d = res['data'] as Map<String, dynamic>? ?? {};
      final summary = d['summary'] as Map<String, dynamic>? ?? d;
      return AttendanceSummary.fromJson(summary);
    } catch (_) {
      return AttendanceSummary.empty();
    }
  }

  Future<FeeSummary> _loadFees(String? dept) async {
    try {
      final res = await ApiService.instance.getFeeSummary(department: dept);
      final d   = res['data'] as Map<String, dynamic>? ?? {};
      return FeeSummary.fromJson(d);
    } catch (_) {
      return FeeSummary.empty();
    }
  }

  Future<FacultyStatusSummary> _loadFaculty(String? dept) async {
    try {
      final res = await ApiService.instance.getFacultyStatus(department: dept);
      final d   = res['data'] as Map<String, dynamic>? ?? {};
      return FacultyStatusSummary(
        total:   d['summary']?['total']   ?? 0,
        present: d['summary']?['present'] ?? 0,
        absent:  d['summary']?['absent']  ?? 0,
        faculty: (d['faculty'] as List<dynamic>? ?? [])
            .map((f) => FacultyModel.fromJson(f as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      return FacultyStatusSummary.empty();
    }
  }

  Future<int> _loadNotifCount() async {
    try {
      final res = await ApiService.instance.getNotifications();
      final d   = res['data'] as Map<String, dynamic>? ?? {};
      return d['unread_count'] as int? ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  void _setStatus(DashboardStatus s) {
    if (_status == s && !_silentRefresh) return;
    _status = s;
    Future.microtask(() => notifyListeners());
  }
}