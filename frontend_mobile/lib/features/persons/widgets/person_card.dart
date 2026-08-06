// lib/features/persons/widgets/person_card.dart
import 'package:flutter/material.dart';
import '../../../models/person_model.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class PersonCard extends StatelessWidget {
  final PersonModel person;
  final VoidCallback? onTap;

  const PersonCard({
    super.key,
    required this.person,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar / Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.neonCyan, width: 2),
                color: AppTheme.surfaceDark,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neonCyan.withOpacity(0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.person, color: AppTheme.neonCyan, size: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.fullName.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 1,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (person.relationship != null && person.relationship!.isNotEmpty)
                    Text(
                      person.relationship!,
                      style: TextStyle(
                        color: AppTheme.neonCyan.withOpacity(0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else if (person.company != null && person.company!.isNotEmpty)
                    Text(
                      person.company!,
                      style: TextStyle(
                        color: AppTheme.neonCyan.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        person.createdAt != null
                            ? 'Registered ${person.createdAt!.split('T').first}'
                            : 'Registered',
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
            // Embeddings / Registered Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.neonGreen.withOpacity(0.6)),
                color: AppTheme.neonGreen.withOpacity(0.1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified, size: 14, color: AppTheme.neonGreen),
                  const SizedBox(width: 4),
                  Text(
                    '${person.embeddingsCount} Embeds',
                    style: const TextStyle(
                      color: AppTheme.neonGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}