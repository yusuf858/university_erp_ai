import 'package:flutter/material.dart';
import '../models/models.dart';
import '../themes/app_colors.dart';
import '../themes/app_text_styles.dart';

class IntentChip extends StatelessWidget {
  final IntentModel intent;

  const IntentChip({super.key, required this.intent});

  @override
  Widget build(BuildContext context) {
    final color = _confidenceColor(intent.confidence);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:        AppColors.cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatIntent(intent.intent),
            style: AppTextStyles.mono.copyWith(fontSize: 10),
          ),
          if (intent.department != null) ...[
            _sep(),
            Text(intent.department!,
                style: AppTextStyles.mono.copyWith(fontSize: 10)),
          ],
          if (intent.date != null) ...[
            _sep(),
            Text(_formatDate(intent.date!),
                style: AppTextStyles.mono.copyWith(fontSize: 10)),
          ],
          if (intent.status != null) ...[
            _sep(),
            Text(intent.status!,
                style: AppTextStyles.mono.copyWith(fontSize: 10)),
          ],
          _sep(),
          Text(
            '${(intent.confidence * 100).round()}%',
            style: AppTextStyles.mono.copyWith(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }

  Widget _sep() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text('·', style: AppTextStyles.mono.copyWith(
      fontSize: 10, color: AppColors.textDisabled,
    )),
  );

  String _formatIntent(String intent) =>
      intent.replaceAll('GET_', '').replaceAll('_', ' ');

  String _formatDate(String date) {
    switch (date) {
      case 'TODAY':      return 'today';
      case 'YESTERDAY':  return 'yesterday';
      case 'THIS_WEEK':  return 'this week';
      case 'THIS_MONTH': return 'this month';
      default:           return date;
    }
  }

  Color _confidenceColor(double c) {
    if (c >= 0.85) return AppColors.success;
    if (c >= 0.75) return AppColors.warning;
    return AppColors.error;
  }
}