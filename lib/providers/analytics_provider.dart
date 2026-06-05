import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum AnalyticsStatus { idle, loading, loaded, error }

class AnalyticsProvider extends ChangeNotifier {
  AnalyticsStatus _status = AnalyticsStatus.idle;
  List<TrendPoint>     _attendanceTrend  = [];
  List<TrendPoint>     _feeTrend         = [];
  List<DeptComparison> _deptComparison   = [];
  String _error = '';

  AnalyticsStatus      get status           => _status;
  bool                 get isLoading        => _status == AnalyticsStatus.loading;
  List<TrendPoint>     get attendanceTrend  => _attendanceTrend;
  List<TrendPoint>     get feeTrend         => _feeTrend;
  List<DeptComparison> get deptComparison   => _deptComparison;
  String               get error            => _error;

  Future<void> loadAll({String? department}) async {
    _error = '';
    _setStatus(AnalyticsStatus.loading);
    try {
      final results = await Future.wait([
        _loadAttendanceTrend(department),
        _loadFeeTrend(department),
        _loadDeptComparison(),
      ], eagerError: false);

      _attendanceTrend = results[0] as List<TrendPoint>;
      _feeTrend        = results[1] as List<TrendPoint>;
      _deptComparison  = results[2] as List<DeptComparison>;

      _setStatus(AnalyticsStatus.loaded);
    } catch (e) {
      _error = 'Failed to load analytics.';
      _setStatus(AnalyticsStatus.error);
    }
  }

  Future<List<TrendPoint>> _loadAttendanceTrend(String? dept) async {
    try {
      final res = await ApiService.instance.getTrend(
        metric: 'attendance', department: dept, days: 30,
      );
      final list = res['data']?['trend'] as List<dynamic>? ?? [];
      return list.map((e) => TrendPoint.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) {
      return _mockTrend();
    }
  }

  Future<List<TrendPoint>> _loadFeeTrend(String? dept) async {
    try {
      final res = await ApiService.instance.getTrend(
        metric: 'fees', department: dept, days: 30,
      );
      final list = res['data']?['trend'] as List<dynamic>? ?? [];
      return list.map((e) => TrendPoint.fromJson(e as Map<String,dynamic>)).toList();
    } catch (_) {
      return _mockTrend(base: 70);
    }
  }

  Future<List<DeptComparison>> _loadDeptComparison() async {
    try {
      final res  = await ApiService.instance.getDeptComparison();
      final list = res['data']?['departments'] as List<dynamic>? ?? [];
      final raw  = list.map((e) => DeptComparison.fromJson(e as Map<String,dynamic>)).toList();

      if (raw.isEmpty) return [];

      // Group by deptCode to merge multiple entries (e.g., from different sections or years)
      // into a single department-level aggregate for the comparison charts.
      final Map<String, List<DeptComparison>> grouped = {};
      for (var d in raw) {
        if (d.deptCode.isNotEmpty) {
          grouped.putIfAbsent(d.deptCode, () => []).add(d);
        }
      }

      return grouped.entries.map((e) {
        final code  = e.key;
        final items = e.value;
        final count = items.length;

        return DeptComparison(
          deptCode:          code,
          attendancePct:     items.map((i) => i.attendancePct).reduce((a, b) => a + b) / count,
          feeCollectionPct:  items.map((i) => i.feeCollectionPct).reduce((a, b) => a + b) / count,
          admissionFillRate: items.map((i) => i.admissionFillRate).reduce((a, b) => a + b) / count,
          totalStudents:     items.map((i) => i.totalStudents).reduce((a, b) => a + b),
        );
      }).toList();

    } catch (_) {
      return _mockDeptComparison();
    }
  }

  // ── Mock data for offline / demo use ─────────────────────
  List<TrendPoint> _mockTrend({double base = 80}) => List.generate(7, (i) {
    final labels = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    final values = [base, base+5, base-3, base+8, base+2, base-5, base+6];
    return TrendPoint(label: labels[i], value: values[i]);
  });

  List<DeptComparison> _mockDeptComparison() => [
    const DeptComparison(deptCode:'MCA', attendancePct:90, feeCollectionPct:84, admissionFillRate:95, totalStudents:60),
    const DeptComparison(deptCode:'BCA', attendancePct:82, feeCollectionPct:78, admissionFillRate:88, totalStudents:120),
    const DeptComparison(deptCode:'MBA', attendancePct:75, feeCollectionPct:91, admissionFillRate:100, totalStudents:58),
    const DeptComparison(deptCode:'MTECH', attendancePct:88, feeCollectionPct:95, admissionFillRate:80, totalStudents:24),
  ];

  void _setStatus(AnalyticsStatus s) {
    _status = s;
    notifyListeners();
  }
}
