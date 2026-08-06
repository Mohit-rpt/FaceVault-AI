// lib/features/dashboard/widgets/stats_grid.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/components/dashboard_stats_card.dart';

class StatsGrid extends ConsumerWidget {
  const StatsGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    // Adjust aspect ratio based on device width to avoid overflows
    final double aspectRatio = screenWidth < 380 ? 1.3 : 1.5;

    return statsAsync.when(
      data: (stats) {
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          children: [
            DashboardStatsCard(
              title: 'REGISTERED',
              value: '${stats['totalPersons'] ?? 0}',
              icon: Icons.people_alt_outlined,
            ),
            DashboardStatsCard(
              title: 'TODAY\'S MATCHES',
              value: '${stats['todayMatches'] ?? 0}',
              icon: Icons.face,
              accentColor: AppTheme.neonGreen,
            ),
            DashboardStatsCard(
              title: 'ACTIVE CAMERAS',
              value: '${stats['activeCameras'] ?? 1}',
              icon: Icons.videocam_outlined,
              accentColor: AppTheme.neonPurple,
            ),
            DashboardStatsCard(
              title: 'UNKNOWN FACES',
              value: '${stats['unknownFaces'] ?? 0}',
              icon: Icons.help_outline,
              accentColor: AppTheme.errorRed,
            ),
          ],
        );
      },
      loading: () => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: aspectRatio,
        children: List.generate(
          4,
          (index) => Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: CircularProgressIndicator(color: AppTheme.neonCyan),
            ),
          ),
        ),
      ),
      error: (_, __) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: aspectRatio,
        children: const [
          DashboardStatsCard(
            title: 'REGISTERED',
            value: '0',
            icon: Icons.people_alt_outlined,
          ),
          DashboardStatsCard(
            title: 'TODAY\'S MATCHES',
            value: '0',
            icon: Icons.face,
            accentColor: AppTheme.neonGreen,
          ),
          DashboardStatsCard(
            title: 'ACTIVE CAMERAS',
            value: '1',
            icon: Icons.videocam_outlined,
            accentColor: AppTheme.neonPurple,
          ),
          DashboardStatsCard(
            title: 'UNKNOWN FACES',
            value: '0',
            icon: Icons.help_outline,
            accentColor: AppTheme.errorRed,
          ),
        ],
      ),
    );
  }
}