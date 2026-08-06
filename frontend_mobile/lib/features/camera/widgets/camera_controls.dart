import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_button.dart';

class CameraControls extends StatelessWidget {
  final bool isConnected;
  final VoidCallback onToggle;
  final VoidCallback onTest;

  const CameraControls({
    super.key,
    required this.isConnected,
    required this.onToggle,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: CyberButton(
            label: isConnected ? 'Disconnect' : 'Connect',
            icon: isConnected ? Icons.link_off : Icons.link,
            glowColor: isConnected ? AppTheme.errorRed : AppTheme.neonGreen,
            onPressed: onToggle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: CyberButton(
            label: 'Test Connection',
            icon: Icons.sensors,
            glowColor: AppTheme.neonCyan,
            onPressed: onTest,
          ),
        ),
      ],
    );
  }
}