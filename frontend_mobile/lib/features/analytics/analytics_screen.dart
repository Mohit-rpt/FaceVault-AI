// lib/features/analytics/analytics_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/futuristic_app_bar.dart';
import '../../shared/widgets/glass_card.dart';
import 'widgets/analytics_card.dart';
import 'widgets/activity_chart.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final double aspectRatio = screenWidth < 380 ? 1.3 : 1.5;

    final List<double> dailyData = [12, 28, 45, 32, 60, 48, 35];

    return Scaffold(
      appBar: const FuturisticAppBar(title: 'ANALYTICS'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              statsAsync.when(
                data: (stats) {
                  final statItems = [
                    {
                      'title': 'TOTAL PERSONS',
                      'value': '${stats['totalPersons'] ?? 0}',
                      'icon': Icons.people_alt
                    },
                    {
                      'title': 'TODAY MATCHES',
                      'value': '${stats['todayMatches'] ?? 0}',
                      'icon': Icons.verified_user
                    },
                    {
                      'title': 'UNKNOWN FACES',
                      'value': '${stats['unknownFaces'] ?? 0}',
                      'icon': Icons.help_outline
                    },
                    {
                      'title': 'ACTIVE CAMERAS',
                      'value': '${stats['activeCameras'] ?? 1}',
                      'icon': Icons.videocam
                    },
                  ];

                  return GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: aspectRatio,
                    children: statItems.map((s) => AnalyticsCard(stat: s)).toList(),
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
                error: (e, _) => const Text('Could not load analytics stats',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
              const SizedBox(height: 20),

              // Activity Chart
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DAILY RECOGNITION ACTIVITY',
                      style: TextStyle(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.neonCyan,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ActivityChart(data: dailyData, height: 140),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                          .map((e) => Text(
                                e,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // AI Insight Panel
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI INSIGHTS',
                      style: TextStyle(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppTheme.neonCyan,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _insightRow('Recognition Model', 'InsightFace buffalo_l'),
                    _insightRow('Vector Search Engine', 'FAISS IndexFlatL2'),
                    _insightRow('Database Storage', 'PostgreSQL 17 (Docker)'),
                    _insightRow('System Status', 'Operational (Healthy)'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insightRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}