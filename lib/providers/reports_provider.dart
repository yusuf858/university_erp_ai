import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';

enum ReportsStatus { idle, loading, loaded, error }

class ReportsProvider extends ChangeNotifier {
  ReportsStatus _status = ReportsStatus.idle;
  List<ReportModel> _reports = [];
  String _error = '';

  ReportsStatus get status => _status;
  bool get isLoading => _status == ReportsStatus.loading;
  List<ReportModel> get reports => _reports;
  String get error => _error;

  Future<void> loadReports() async {
    _status = ReportsStatus.loading;
    _error = '';
    notifyListeners();

    try {
      // Assuming ApiService has a method to get reports, or using mock for now
      // final res = await ApiService.instance.getReports();
      // _reports = (res['data'] as List).map((e) => ReportModel.fromJson(e)).toList();
      
      // Using mock data as seen in the pattern of other providers
      await Future.delayed(const Duration(seconds: 1));
      _reports = _mockReports();
      _status = ReportsStatus.loaded;
    } catch (e) {
      _error = 'Failed to load reports';
      _status = ReportsStatus.error;
    }
    notifyListeners();
  }

  List<ReportModel> _mockReports() => [
    ReportModel(
      id: 1,
      title: 'Monthly Attendance Report - May 2024',
      type: 'PDF',
      status: 'READY',
      createdAt: '2024-05-31 10:00',
      size: '1.2 MB',
      downloadUrl: 'https://example.com/reports/att_may_24.pdf',
    ),
    ReportModel(
      id: 2,
      title: 'Department Fee Summary Q2',
      type: 'CSV',
      status: 'READY',
      createdAt: '2024-06-01 14:30',
      size: '450 KB',
      downloadUrl: 'https://example.com/reports/fees_q2.csv',
    ),
    ReportModel(
      id: 3,
      title: 'Admission Analytics 2024-25',
      type: 'PDF',
      status: 'GENERATING',
      createdAt: '2024-06-05 09:15',
      size: '—',
    ),
  ];
}
