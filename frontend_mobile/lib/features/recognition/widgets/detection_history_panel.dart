import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class DetectionHistoryPanel extends StatelessWidget {
  final List<Map<String, dynamic>> history;

  const DetectionHistoryPanel({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECENT DETECTIONS',
            style: TextStyle(
              letterSpacing: 1.5,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppTheme.neonCyan,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                final isKnown = item['name'] != 'Unknown Person';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isKnown
                                ? AppTheme.neonGreen.withOpacity(0.6)
                                : AppTheme.errorRed.withOpacity(0.6),
                            width: 1.5,
                          ),
                        ),
                        child: Icon(
                          isKnown ? Icons.person : Icons.help,
                          color: isKnown
                              ? AppTheme.neonGreen
                              : AppTheme.errorRed,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              item['time'],
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${item['confidence']}%',
                        style: TextStyle(
                          color: isKnown
                              ? AppTheme.neonGreen
                              : AppTheme.errorRed,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}