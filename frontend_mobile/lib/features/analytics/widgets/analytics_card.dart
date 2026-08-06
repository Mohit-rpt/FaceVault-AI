import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class AnalyticsCard extends StatelessWidget {
  final Map<String, dynamic> stat;
  const AnalyticsCard({super.key, required this.stat});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(stat['icon'], color: AppTheme.neonCyan, size: 24),
          const Spacer(),
          Text(
            stat['value'],
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppTheme.neonCyan,
              letterSpacing: 1,
            ),
          ),
          Text(
            stat['title'],
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}