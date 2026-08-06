// lib/features/logs/widgets/recognition_log_card.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/recognition_model.dart';
import '../../../shared/widgets/glass_card.dart';

class RecognitionLogCard extends StatelessWidget {
  final RecognitionLogModel log;

  const RecognitionLogCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final bool isKnown = log.personId != 0;
    final statusColor = isKnown ? AppTheme.neonGreen : AppTheme.errorRed;
    final statusIcon = isKnown ? Icons.verified : Icons.help_outline;

    final String name = log.personName ?? (isKnown ? 'Person #${log.personId}' : 'Unknown Face');
    final int confidence = (log.confidenceScore * 100).toInt();

    String formattedTime = 'Recently';
    if (log.recognizedAt != null) {
      formattedTime = log.recognizedAt!.split('T').last.split('.').first;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: statusColor, width: 1.5),
              ),
              child: Icon(
                isKnown ? Icons.person : Icons.person_outline,
                color: statusColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
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
                    'Camera: ${log.cameraSource ?? "API Stream"}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      confidence > 0 ? '$confidence%' : '95%',
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formattedTime,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}