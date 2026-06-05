import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/models.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';
import '../utils/constants.dart';

// ── Section header reused across chart cards ──────────────────
class ChartCard extends StatelessWidget {
  final String  title;
  final String? subtitle;
  final Widget  chart;
  final Widget? action;

  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.chart,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        border:       Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      padding: const EdgeInsets.all(AppConstants.paddingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.heading3),
                    if (subtitle != null)
                      Text(subtitle!, style: AppTextStyles.caption),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 20),
          chart,
        ],
      ),
    );
  }
}

// ── 1. Attendance bar chart ───────────────────────────────────
class AttendanceBarChart extends StatelessWidget {
  final List<DeptComparison> data;

  const AttendanceBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _EmptyChart();

    final bool isDense = data.length > 10;
    final double barWidth = data.length > 15 ? 12 : (isDense ? 18 : 28);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment:       BarChartAlignment.spaceAround,
          maxY:            100,
          minY:            0,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final dept = data[groupIndex].deptCode;
                return BarTooltipItem(
                  '$dept\n${rod.toY.round()}%',
                  AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Transform.rotate(
                      angle: -math.pi / 4, // 45 degree rotation
                      child: Text(
                        data[idx].deptCode,
                        style: AppTextStyles.overline.copyWith(
                          fontSize: isDense ? 9 : 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  '${value.toInt()}%',
                  style: AppTextStyles.overline,
                ),
                interval: 25,
              ),
            ),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.borderColor,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            final i    = entry.key;
            final dept = entry.value;
            final color = dept.attendancePct >= 75
                ? AppColors.primary
                : AppColors.warning;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY:          dept.attendancePct,
                  color:        color,
                  width:        barWidth,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show:  true,
                    toY:   100,
                    color: AppColors.borderColor.withOpacity(0.1),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
        swapAnimationDuration: AppConstants.animSlow,
        swapAnimationCurve:    Curves.easeInOut,
      ),
    );
  }
}

// ── 2. Attendance trend line chart ────────────────────────────
class AttendanceTrendChart extends StatelessWidget {
  final List<TrendPoint> data;

  const AttendanceTrendChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _EmptyChart();

    final spots = data.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                '${s.y.round()}%',
                AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
              )).toList(),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.borderColor,
              strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (data.length / 4).ceilToDouble(),
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  return Text(data[idx].label, style: AppTextStyles.overline);
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 25,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}%', style: AppTextStyles.overline,
                ),
              ),
            ),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          lineBarsData: [
            LineChartBarData(
              spots:           spots,
              isCurved:        true,
              curveSmoothness: 0.3,
              color:           AppColors.primary,
              barWidth:        2.5,
              dotData: FlDotData(
                show:              true,
                checkToShowDot:    (spot, _) =>
                spot.x == 0 || spot.x == spots.length - 1.0,
                getDotPainter:     (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color:       AppColors.primary,
                  strokeColor: AppColors.darkBg,
                  strokeWidth: 2,
                ),
              ),
              belowBarData: BarAreaData(
                show:  true,
                gradient: LinearGradient(
                  begin:  Alignment.topCenter,
                  end:    Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    AppColors.primary.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
        duration: AppConstants.animSlow,
        curve:    Curves.easeInOut,
      ),
    );
  }
}

// ── 3. Fee collection pie chart ───────────────────────────────
class FeesPieChart extends StatefulWidget {
  final FeeSummary summary;

  const FeesPieChart({super.key, required this.summary});

  @override
  State<FeesPieChart> createState() => _FeesPieChartState();
}

class _FeesPieChartState extends State<FeesPieChart> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final s     = widget.summary;
    final total = s.totalAmount;
    if (total == 0) return const _EmptyChart();

    final sections = [
      _section(s.collected, total, AppColors.success, 'Paid',    0),
      _section(s.pending,   total, AppColors.warning, 'Pending', 1),
      _section(s.overdue,   total, AppColors.error,   'Overdue', 2),
    ].where((sec) => sec.value > 0).toList();

    return Row(
      children: [
        SizedBox(
          width: 140, height: 140,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (ev, resp) {
                  setState(() {
                    _touched = (ev.isInterestedForInteractions &&
                        resp?.touchedSection != null)
                        ? resp!.touchedSection!.touchedSectionIndex
                        : -1;
                  });
                },
              ),
              sectionsSpace:     2,
              centerSpaceRadius: 36,
              sections:          sections,
            ),
            swapAnimationDuration: AppConstants.animSlow,
            swapAnimationCurve:    Curves.easeInOut,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:  MainAxisAlignment.center,
            children: [
              _legend(AppColors.success, 'Collected',
                  '${s.collectionPercent.toStringAsFixed(1)}%'),
              const SizedBox(height: 8),
              _legend(AppColors.warning, 'Pending',
                  _fmt(s.pending)),
              const SizedBox(height: 8),
              _legend(AppColors.error, 'Overdue',
                  _fmt(s.overdue)),
            ],
          ),
        ),
      ],
    );
  }

  PieChartSectionData _section(
      double val, double total, Color color, String title, int idx) {
    final pct    = total == 0 ? 0.0 : val / total * 100;
    final radius = _touched == idx ? 58.0 : 48.0;
    return PieChartSectionData(
      value:     pct,
      color:     color,
      radius:    radius,
      showTitle: _touched == idx,
      title:     '${pct.round()}%',
      titleStyle: AppTextStyles.caption.copyWith(
        color: Colors.white, fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _legend(Color color, String label, String value) => Row(
    children: [
      Container(
        width: 10, height: 10,
        decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: AppTextStyles.caption)),
      Text(value, style: AppTextStyles.captionMedium.copyWith(
        color: AppColors.textPrimary,
      )),
    ],
  );

  String _fmt(double v) {
    if (v >= 100000) return '₹${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '₹${(v / 1000).toStringAsFixed(1)}K';
    return '₹${v.toStringAsFixed(0)}';
  }
}

// ── 4. Department comparison bar chart ────────────────────────
class DeptComparisonChart extends StatelessWidget {
  final List<DeptComparison> data;

  const DeptComparisonChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _EmptyChart();

    final bool isDense = data.length > 8;
    final double rodWidth = data.length > 15 ? 4 : (isDense ? 6 : 10);
    final double groupSpace = isDense ? 2 : 4;

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment:  BarChartAlignment.spaceAround,
          maxY:       100,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.surface,
              getTooltipItem: (group, _, rod, rodIndex) {
                final dept   = data[group.x.toInt()].deptCode;
                final labels = ['Attend.', 'Fees', 'Admit.'];
                return BarTooltipItem(
                  '$dept ${labels[rodIndex]}\n${rod.toY.round()}%',
                  AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
                );
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.borderColor, strokeWidth: 0.5,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (val, meta) {
                  final idx = val.toInt();
                  if (idx < 0 || idx >= data.length) return const SizedBox();
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 8,
                    child: Transform.rotate(
                      angle: -math.pi / 4,
                      child: Text(
                        data[idx].deptCode,
                        style: AppTextStyles.overline.copyWith(
                          fontSize: isDense ? 9 : 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 25,
                getTitlesWidget: (v, _) => Text(
                  '${v.toInt()}%', style: AppTextStyles.overline,
                ),
              ),
            ),
            topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: data.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            return BarChartGroupData(
              x: i,
              barsSpace: groupSpace,
              barRods: [
                _rod(d.attendancePct,    AppColors.primary, rodWidth),
                _rod(d.feeCollectionPct, AppColors.success, rodWidth),
                _rod(d.admissionFillRate,AppColors.accent,  rodWidth),
              ],
            );
          }).toList(),
        ),
        swapAnimationDuration: AppConstants.animSlow,
        swapAnimationCurve:    Curves.easeInOut,
      ),
    );
  }

  BarChartRodData _rod(double val, Color color, double width) => BarChartRodData(
    toY:    val,
    color:  color,
    width:  width,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
    backDrawRodData: BackgroundBarChartRodData(
      show: true, toY: 100, color: AppColors.borderColor.withOpacity(0.1),
    ),
  );
}

// ── Chart legend row ──────────────────────────────────────────
class ChartLegend extends StatelessWidget {
  final List<_LegendItem> items;
  const ChartLegend({super.key, required this.items});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 16, runSpacing: 4,
    children: items.map((i) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: i.color, borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 5),
        Text(i.label, style: AppTextStyles.overline),
      ],
    )).toList(),
  );
}

class _LegendItem {
  final Color  color;
  final String label;
  const _LegendItem(this.color, this.label);
}

const comparisonLegend = [
  _LegendItem(AppColors.primary, 'Attendance'),
  _LegendItem(AppColors.success, 'Fees'),
  _LegendItem(AppColors.accent,  'Admissions'),
];

// ── Empty chart placeholder ───────────────────────────────────
class _EmptyChart extends StatelessWidget {
  const _EmptyChart();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bar_chart_rounded,
              color: AppColors.textDisabled, size: 32),
          const SizedBox(height: 8),
          Text('No data available', style: AppTextStyles.caption),
        ],
      ),
    ),
  );
}
