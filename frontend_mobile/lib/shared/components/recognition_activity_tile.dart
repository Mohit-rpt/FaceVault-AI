// lib/shared/components/recognition_activity_tile.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/glass_card.dart';

class RecognitionActivityTile extends StatelessWidget {
  final String name;
  final int confidence;
  final String time;
  final String location;

  const RecognitionActivityTile({
    super.key,
    required this.name,
    required this.confidence,
    required this.time,
    required this.location,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.neonCyan, width: 1.5),
              color: AppTheme.surfaceDark,
            ),
            child: const Center(
              child: Icon(Icons.person, color: AppTheme.neonCyan, size: 20),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$location • $time',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$confidence%',
                style: const TextStyle(
                  color: AppTheme.neonGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const Text(
                'CONFIDENCE',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}