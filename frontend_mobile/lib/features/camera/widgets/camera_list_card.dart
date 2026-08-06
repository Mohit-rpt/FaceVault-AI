// lib/features/camera/widgets/camera_list_card.dart

import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import 'camera_connection_indicator.dart';

class CameraListCard extends StatelessWidget {
  final List<Map<String, dynamic>> cameras;
  final int selectedIndex;
  final Function(int) onSelect;
  final VoidCallback onAdd;

  const CameraListCard({
    super.key,
    required this.cameras,
    required this.selectedIndex,
    required this.onSelect,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'AVAILABLE CAMERAS',
                  style: TextStyle(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.neonCyan,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.neonPurple.withOpacity(0.6)),
                  ),
                  child: const Text(
                    '+ ADD',
                    style: TextStyle(
                      color: AppTheme.neonPurple,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(cameras.length, (index) {
            final cam = cameras[index];
            final isSelected = index == selectedIndex;
            return GestureDetector(
              onTap: () => onSelect(index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.neonCyan
                        : AppTheme.neonCyan.withOpacity(0.2),
                    width: isSelected ? 1.5 : 1,
                  ),
                  color: isSelected
                      ? AppTheme.neonCyan.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: Row(
                  children: [
                    CameraConnectionIndicator(
                      status: cam['status'],
                      small: true,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cam['name'],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${cam['type']} • ${cam['resolution']}',
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
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle, color: AppTheme.neonCyan, size: 20),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}