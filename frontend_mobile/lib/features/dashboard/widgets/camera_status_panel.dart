import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/status_indicator.dart';

class CameraStatusPanel extends StatelessWidget {
  const CameraStatusPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'CAMERA STATUS',
            style: TextStyle(
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
             StatusIndicator(
            label: AppConstants.cameraStatus,
            active: true,
          ),
          const SizedBox(height: 8),
          Text(
            'FPS: ${AppConstants.cameraFps.toInt()}',
            style: const TextStyle(
              fontSize: 16,
              color: AppTheme.neonCyan,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}