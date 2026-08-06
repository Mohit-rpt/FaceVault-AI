import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class RecognitionResultCard extends StatelessWidget {
  final bool isKnown;
  final String? name;
  final int confidence;

  const RecognitionResultCard({
    super.key,
    required this.isKnown,
    this.name,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      borderColor: isKnown
          ? AppTheme.neonGreen.withOpacity(0.6)
          : AppTheme.errorRed.withOpacity(0.6),
      child: Row(
        children: [
          // Avatar or unknown icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isKnown ? AppTheme.neonGreen : AppTheme.errorRed,
                width: 2,
              ),
            ),
            child: Icon(
              isKnown ? Icons.person : Icons.help_outline,
              color: isKnown ? AppTheme.neonGreen : AppTheme.errorRed,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isKnown ? 'IDENTITY VERIFIED' : 'UNKNOWN PERSON',
                  style: TextStyle(
                    color: isKnown ? AppTheme.neonGreen : AppTheme.errorRed,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isKnown ? name ?? '' : 'No Match Found',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Confidence badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isKnown
                    ? AppTheme.neonGreen.withOpacity(0.6)
                    : AppTheme.errorRed.withOpacity(0.6),
              ),
              color: (isKnown ? AppTheme.neonGreen : AppTheme.errorRed)
                  .withOpacity(0.1),
            ),
            child: Text(
              '$confidence%',
              style: TextStyle(
                color: isKnown ? AppTheme.neonGreen : AppTheme.errorRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}