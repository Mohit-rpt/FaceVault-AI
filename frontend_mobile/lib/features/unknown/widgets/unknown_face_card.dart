// lib/features/unknown/widgets/unknown_face_card.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/cyber_button.dart';

class UnknownFaceCard extends StatelessWidget {
  final Map<String, dynamic> face;
  const UnknownFaceCard({super.key, required this.face});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.errorRed.withOpacity(0.6)),
                    color: AppTheme.surfaceDark,
                  ),
                  child: const Center(
                    child: Icon(Icons.help_outline, color: AppTheme.errorRed, size: 32),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'UNKNOWN PERSON',
                        style: TextStyle(
                          color: AppTheme.errorRed,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _infoRow('Time', face['time'] ?? 'Recent'),
                      _infoRow('Confidence', '${face['confidence'] ?? 0}%'),
                      _infoRow('Camera', face['camera'] ?? 'API Stream'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CyberButton(
                    label: 'REVIEW',
                    icon: Icons.search,
                    glowColor: AppTheme.neonCyan,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Unknown face log details logged.')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: CyberButton(
                    label: 'REGISTER',
                    icon: Icons.person_add_alt,
                    glowColor: AppTheme.neonPurple,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Navigate to Registration screen to enroll face.')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}