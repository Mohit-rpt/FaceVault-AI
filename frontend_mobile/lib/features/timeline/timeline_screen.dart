// lib/features/timeline/timeline_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/futuristic_app_bar.dart';
import '../../shared/widgets/glass_card.dart';

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(recognitionLogsProvider(null));

    return Scaffold(
      appBar: const FuturisticAppBar(title: 'SYSTEM TIMELINE'),
      body: RefreshIndicator(
        color: AppTheme.neonCyan,
        onRefresh: () async {
          ref.invalidate(recognitionLogsProvider(null));
        },
        child: logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return const Center(
                child: Text(
                  'No timeline events logged yet.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                final bool isKnown = log.personId != 0;
                final String name = log.personName ?? (isKnown ? 'Person #${log.personId}' : 'Unknown Face');
                final String time = log.recognizedAt != null
                    ? log.recognizedAt!.replaceFirst('T', ' ').split('.').first
                    : 'Recent';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isKnown ? AppTheme.neonGreen : AppTheme.errorRed,
                            boxShadow: [
                              BoxShadow(
                                color: (isKnown ? AppTheme.neonGreen : AppTheme.errorRed).withOpacity(0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Camera Source: ${log.cameraSource ?? "API Stream"}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          time,
                          style: const TextStyle(
                            color: AppTheme.neonCyan,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.neonCyan),
          ),
          error: (e, _) => Center(
            child: Text('Failed to load timeline: $e',
                style: const TextStyle(color: AppTheme.textSecondary)),
          ),
        ),
      ),
    );
  }
}