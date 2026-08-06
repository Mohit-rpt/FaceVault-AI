// lib/shared/components/dashboard_stats_card.dart

import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';
import '../../core/theme/app_theme.dart';

class DashboardStatsCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;

  const DashboardStatsCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.accentColor = AppTheme.neonCyan,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: accentColor.withOpacity(0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor, size: 20),
              const SizedBox(width: 4),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: accentColor,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              maxLines: 1,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}