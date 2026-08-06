import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class TimelineEventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const TimelineEventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final bool isKnown = event['person'] != 'Unknown';
    final Color accent = isKnown ? AppTheme.neonGreen : AppTheme.errorRed;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time column
          SizedBox(
            width: 60,
            child: Text(
              event['time'],
              style: const TextStyle(
                color: AppTheme.neonCyan,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Timeline indicator
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent,
                  boxShadow: [
                    BoxShadow(color: accent.withOpacity(0.6), blurRadius: 6),
                  ],
                ),
              ),
              Container(
                width: 2,
                height: 30,
                color: accent.withOpacity(0.3),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event['person'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  event['event'],
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Camera: ${event['camera']}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Confidence badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.5)),
            ),
            child: Text(
              '${event['confidence']}%',
              style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}