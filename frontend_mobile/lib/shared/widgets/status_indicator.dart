import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class StatusIndicator extends StatelessWidget {
  final String label;
  final bool active;
  final Color? activeColor;

  const StatusIndicator({
    super.key,
    required this.label,
    this.active = true,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppTheme.neonGreen;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? color : Colors.grey,
            boxShadow: active
                ? [BoxShadow(color: color.withOpacity(0.6), blurRadius: 8)]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: active ? color : Colors.grey,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}