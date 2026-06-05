import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/reports_provider.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';
import '../../utils/constants.dart';
import '../../models/models.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsProvider>().loadReports();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        title: const Text('Reports', style: AppTextStyles.heading3),
        backgroundColor: AppColors.surface,
        elevation: 0,
      ),
      body: Consumer<ReportsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (provider.status == ReportsStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                  const SizedBox(height: 16),
                  Text(provider.error, style: AppTextStyles.body),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadReports(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.reports.isEmpty) {
            return const Center(
              child: Text('No reports available', style: AppTextStyles.body),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppConstants.paddingLG),
            itemCount: provider.reports.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppConstants.paddingMD),
            itemBuilder: (context, index) {
              final report = provider.reports[index];
              return _ReportCard(report: report);
            },
          );
        },
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final bool isReady = report.status == 'READY';

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMD),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(AppConstants.radiusLG),
        border: Border.all(color: AppColors.borderColor, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (report.type == 'PDF' ? AppColors.error : AppColors.success).withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusMD),
            ),
            child: Icon(
              report.type == 'PDF' ? Icons.picture_as_pdf : Icons.table_chart,
              color: report.type == 'PDF' ? AppColors.error : AppColors.success,
            ),
          ),
          const SizedBox(width: AppConstants.paddingMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report.title, style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text(
                  '${report.createdAt} • ${report.size}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          if (isReady)
            IconButton(
              icon: const Icon(Icons.download_for_offline, color: AppColors.primary),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Downloading ${report.title}...')),
                );
              },
            )
          else
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}
