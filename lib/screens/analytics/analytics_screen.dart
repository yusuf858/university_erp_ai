import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/auth_provider.dart';
import '../../analytics/chart_widgets.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/constants.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen>
    with AutomaticKeepAliveClientMixin {

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final dept = context.read<AuthProvider>().currentUser?.departmentCode;
    context.read<AnalyticsProvider>().loadAll(department: dept);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Analytics', style: AppTextStyles.heading3),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            icon:      const Icon(Icons.refresh_rounded),
            color:     AppColors.textMuted,
            onPressed: _load,
          ),
        ],
      ),
      body: Consumer<AnalyticsProvider>(
        builder: (_, ap, __) {
          if (ap.isLoading) return _LoadingState();
          if (ap.status == AnalyticsStatus.error) {
            return _ErrorState(onRetry: _load);
          }
          return _AnalyticsBody(provider: ap);
        },
      ),
    );
  }
}

class _AnalyticsBody extends StatelessWidget {
  final AnalyticsProvider provider;
  const _AnalyticsBody({required this.provider});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        final dept =
            context.read<AuthProvider>().currentUser?.departmentCode;
        await context.read<AnalyticsProvider>().loadAll(department: dept);
      },
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.all(AppConstants.paddingLG),
        children: [
          // ── Attendance by dept ───────────────────────────
          ChartCard(
            title:    'Attendance by Department',
            subtitle: 'Today — all departments',
            chart:    AttendanceBarChart(data: provider.deptComparison),
          ),
          const SizedBox(height: AppConstants.paddingMD),

          // ── Attendance trend ──────────────────────────────
          ChartCard(
            title:    'Attendance Trend',
            subtitle: 'Last 7 days',
            chart:    AttendanceTrendChart(data: provider.attendanceTrend),
          ),
          const SizedBox(height: AppConstants.paddingMD),

          // ── Department comparison ─────────────────────────
          ChartCard(
            title:    'Department Comparison',
            subtitle: 'Attendance · Fees · Admissions',
            chart: Column(
              children: [
                DeptComparisonChart(data: provider.deptComparison),
                const SizedBox(height: 10),
                ChartLegend(items: comparisonLegend),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.paddingMD),

          // ── Dept table ────────────────────────────────────
          if (provider.deptComparison.isNotEmpty) ...[
            _DeptTable(data: provider.deptComparison),
            const SizedBox(height: AppConstants.paddingMD),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

// ── Department stats table ─────────────────────────────────────
class _DeptTable extends StatelessWidget {
  final List<DeptComparison> data;
  const _DeptTable({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        border:       Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            child: const Text('Department Summary', style: AppTextStyles.heading3),
          ),
          const Divider(height: 0),
          // Header
          const _Row(
            dept:    'Dept',
            att:     'Attend.',
            fee:     'Fees',
            adm:     'Admit.',
            isHeader: true,
          ),
          const Divider(height: 0),
          ...data.map((d) => Column(
            children: [
              _Row(
                dept: d.deptCode,
                att:  '${d.attendancePct.round()}%',
                fee:  '${d.feeCollectionPct.round()}%',
                adm:  '${d.admissionFillRate.round()}%',
                attColor: d.attendancePct >= 75
                    ? AppColors.success : AppColors.warning,
                feeColor: d.feeCollectionPct >= 80
                    ? AppColors.success : AppColors.warning,
              ),
              if (data.last != d) const Divider(height: 0),
            ],
          )),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String  dept;
  final String  att;
  final String  fee;
  final String  adm;
  final bool    isHeader;
  final Color?  attColor;
  final Color?  feeColor;

  const _Row({
    required this.dept,
    required this.att,
    required this.fee,
    required this.adm,
    this.isHeader = false,
    this.attColor,
    this.feeColor,
  });

  @override
  Widget build(BuildContext context) {
    final style = isHeader
        ? AppTextStyles.overline
        : AppTextStyles.body.copyWith(color: AppColors.textPrimary);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLG,
        vertical:   AppConstants.paddingMD,
      ),
      child: Row(
        children: [
          Expanded(child: Text(dept, style: style)),
          SizedBox(width: 60, child: Text(att,
              style: isHeader ? style : (style.copyWith(color: attColor)),
              textAlign: TextAlign.center)),
          SizedBox(width: 60, child: Text(fee,
              style: isHeader ? style : (style.copyWith(color: feeColor)),
              textAlign: TextAlign.center)),
          SizedBox(width: 60, child: Text(adm,
              style: style, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppConstants.paddingLG),
    children: List.generate(3, (_) => Container(
      height: 240,
      margin: const EdgeInsets.only(bottom: AppConstants.paddingMD),
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary, strokeWidth: 1.5,
        ),
      ),
    )),
  );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.error, size: 40),
        const SizedBox(height: 12),
        const Text('Failed to load analytics', style: AppTextStyles.body),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    ),
  );
}