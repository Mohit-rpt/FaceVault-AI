// lib/features/dashboard/widgets/recognition_activity_list.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/components/recognition_activity_tile.dart';

class RecognitionActivityList extends ConsumerWidget {
  const RecognitionActivityList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(recognitionLogsProvider(null));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LIVE RECOGNITION FEED',
              style: TextStyle(
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: AppTheme.textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: AppTheme.neonCyan),
              onPressed: () => ref.invalidate(recognitionLogsProvider(null)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        logsAsync.when(
          data: (logs) {
            if (logs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text(
                    'No recognition events logged yet.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ),
              );
            }

            return Column(
              children: logs.take(5).map((log) {
                final String time = log.recognizedAt != null
                    ? log.recognizedAt!.split('T').last.split('.').first
                    : 'Just now';
                final String name = log.personName ??
                    (log.personId == 0 ? 'Unknown Face' : 'Person #${log.personId}');
                final int confidence = (log.confidenceScore * 100).toInt();

                return RecognitionActivityTile(
                  name: name,
                  confidence: confidence > 0 ? confidence : 95,
                  time: time,
                  location: log.cameraSource ?? 'API Stream',
                );
              }).toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(color: AppTheme.neonCyan),
            ),
          ),
          error: (err, stack) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.errorRed.withOpacity(0.3)),
            ),
            child: Text(
              'Failed to load logs feed: $err',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}