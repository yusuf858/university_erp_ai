import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';
import '../utils/constants.dart';

class DashboardCard extends StatelessWidget {
  final String       title;
  final String       value;
  final String?      subtitle;
  final IconData     icon;
  final Color        accentColor;
  final bool         isLoading;
  final VoidCallback? onTap;
  final Widget?      bottomWidget;

  const DashboardCard({
    super.key,
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.accentColor,
    this.isLoading  = false,
    this.onTap,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) return _Shimmer();

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animNormal,
        decoration: BoxDecoration(
          color:        AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
          border:       Border.all(color: AppColors.borderColor, width: 0.5),
        ),
        child: Stack(
          children: [
            // Glow effect
            Positioned(
              top: -20, right: -20,
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.06),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.paddingLG),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          color:        accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: accentColor, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Value
                  Text(value, style: AppTextStyles.metricMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (bottomWidget != null) ...[
                    const SizedBox(height: 10),
                    bottomWidget!,
                  ],
                ],
              ),
            ),
            // Accent bottom bar
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(AppConstants.radiusLG),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Shimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor:      AppColors.cardBg,
      highlightColor: AppColors.borderColor,
      period:         AppConstants.shimmerPeriod,
      child: Container(
        height: AppConstants.cardMinHeight,
        decoration: BoxDecoration(
          color:        AppColors.cardBg,
          borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        ),
      ),
    );
  }
}

// ── Attendance progress bar ───────────────────────────────────
class AttendanceBar extends StatelessWidget {
  final double percent; // 0.0 – 1.0
  final Color  color;

  const AttendanceBar({
    super.key,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value:            percent.clamp(0.0, 1.0),
        backgroundColor:  AppColors.borderColor,
        color:            color,
        minHeight:        5,
      ),
    );
  }
}

// ── Mini dot row (faculty presence indicators) ────────────────
class FacultyDots extends StatelessWidget {
  final int total;
  final int present;

  const FacultyDots({super.key, required this.total, required this.present});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4, runSpacing: 4,
      children: List.generate(total.clamp(0, 12), (i) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: i < present ? AppColors.success : AppColors.error,
        ),
      )),
    );
  }
}

// ── Mini sparkline bars ───────────────────────────────────────
class SparklineBars extends StatelessWidget {
  final List<double> values;
  final Color        color;

  const SparklineBars({super.key, required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    final max = values.isEmpty ? 1.0
        : values.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.map((v) {
        final frac = max == 0 ? 0.0 : (v / max);
        return Expanded(
          child: Container(
            height: 24 * frac + 4,
            margin: const EdgeInsets.symmetric(horizontal: 1),
            decoration: BoxDecoration(
              color:        color.withValues(alpha: 0.7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ),
        );
      }).toList(),
    );
  }
}
