import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import '../models/models.dart';
import 'storage_service.dart';

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiService {
  const ApiService._();
  static const ApiService instance = ApiService._();

  static const Duration _timeout = Duration(seconds: AppConstants.apiTimeoutSeconds);

  // ── request logic ─────────────────────────────────────────
  Future<Map<String, dynamic>> _get(
      String endpoint, {
        Map<String, String?>? params,
        bool requiresAuth = true,
      }) async {
    final uri = _buildUri(endpoint, params);
    final headers = await _buildHeaders(requiresAuth);

    final response = await http
        .get(uri, headers: headers)
        .timeout(_timeout);

    return _parse(response);
  }

  Future<Map<String, dynamic>> _post(
      String endpoint,
      Map<String, dynamic> body, {
        bool requiresAuth = true,
      }) async {
    final uri = _buildUri(endpoint);
    final headers = await _buildHeaders(requiresAuth);

    final response = await http
        .post(uri, headers: headers, body: jsonEncode(body))
        .timeout(_timeout);

    return _parse(response);
  }

  // ── Auth ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) =>
      _post(
        AppConstants.loginEndpoint,
        {'email': email, 'password': password},
        requiresAuth: false,
      );

  // ── Attendance ───────────────────────────────────────────
  Future<Map<String, dynamic>> getAttendance({
    String? department,
    String? date,
    String? status,
    int? semester,
  }) =>
      _get(AppConstants.attendanceEndpoint, params: {
        if (department != null) 'department': department,
        if (date != null)       'date': date,
        if (status != null)     'status': status,
        if (semester != null)   'semester': semester.toString(),
      });

  Future<Map<String, dynamic>> getAttendanceSummary({
    String? department,
    String? date,
  }) =>
      _get(AppConstants.attSummaryEndpoint, params: {
        if (department != null) 'department': department,
        if (date != null)       'date': date,
      });

  // ── Fees ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getFeeSummary({String? department}) =>
      _get(AppConstants.feeSummaryEndpoint, params: {
        if (department != null) 'department': department,
      });

  Future<Map<String, dynamic>> getFees({
    String? department,
    String? status,
    int? semester,
  }) =>
      _get(AppConstants.feesEndpoint, params: {
        if (department != null) 'department': department,
        if (status != null)     'status': status,
        if (semester != null)   'semester': semester.toString(),
      });

  // ── Faculty ───────────────────────────────────────────────
  Future<Map<String, dynamic>> getFacultyStatus({String? department}) =>
      _get(AppConstants.facultyEndpoint, params: {
        if (department != null) 'department': department,
      });

  // ── Analytics ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getDeptComparison() =>
      _get(AppConstants.deptCompareEndpoint);

  Future<Map<String, dynamic>> getTrend({
    required String metric,
    String? department,
    int days = 30,
  }) =>
      _get(AppConstants.trendEndpoint, params: {
        'metric':     metric,
        'period_days': days.toString(),
        if (department != null) 'department': department,
      });

  // ── Notifications ─────────────────────────────────────────
  Future<Map<String, dynamic>> getNotifications() =>
      _get(AppConstants.notifEndpoint);

  // ── Helpers ───────────────────────────────────────────────
  Uri _buildUri(String endpoint, [Map<String, String?>? params]) {
    final base = '${AppConstants.baseUrl}$endpoint';
    if (params == null || params.isEmpty) return Uri.parse(base);
    final filtered = Map.fromEntries(
      params.entries.where((e) => e.value != null).map(
            (e) => MapEntry(e.key, e.value!),
      ),
    );
    return Uri.parse(base).replace(queryParameters: filtered);
  }

  Future<Map<String, String>> _buildHeaders(bool requiresAuth) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept':       'application/json',
    };
    if (requiresAuth) {
      final token = await StorageService.instance.readToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Map<String, dynamic> _parse(http.Response response) {
    // If the server returns HTML (e.g. 404 or 500 error), jsonDecode will fail.
    // We catch this to provide a better error message.
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return body;
      }
      throw ApiException(
        body['message'] as String? ?? 'Server Error (${response.statusCode})',
        response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      // If we reach here, the response wasn't JSON.
      throw ApiException(
        'Server returned non-JSON response. Status: ${response.statusCode}. '
        'Check if your IP and PHP path are correct.',
        response.statusCode,
      );
    }
  }
}
