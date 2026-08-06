import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/status_indicator.dart';
import 'camera_connection_indicator.dart';

class CameraStatusCard extends StatelessWidget {
  final Map<String, dynamic> camera;
  const CameraStatusCard({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    final isConnected = camera['status'] == 'Connected';

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.videocam, color: AppTheme.neonCyan, size: 22),
              const SizedBox(width: 8),
              Text(
                'CAMERA STATUS',
                style: TextStyle(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppTheme.neonCyan.withOpacity(0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusIndicator(
                      label: camera['status'].toString().toUpperCase(),
                      active: isConnected,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoLine('Source', camera['name']),
                    _buildInfoLine('Type', camera['type']),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoLine('FPS', '${camera['fps']}'),
                    _buildInfoLine('Resolution', camera['resolution']),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CameraConnectionIndicator(status: camera['status']),
        ],
      ),
    );
  }

  Widget _buildInfoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}