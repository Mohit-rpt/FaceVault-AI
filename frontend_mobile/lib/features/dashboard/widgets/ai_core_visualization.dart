import 'package:flutter/material.dart';
import '../../../shared/widgets/ai_scanner_animation.dart';
import '../../../shared/widgets/glass_card.dart';

class AiCoreVisualization extends StatelessWidget {
  const AiCoreVisualization({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Text(
            'AI CORE',
            style: TextStyle(
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          const AiScannerAnimation(size: 100),
          const SizedBox(height: 12),
          const Text(
            'PROCESSING ACTIVE',
            style: TextStyle(fontSize: 10, letterSpacing: 2),
          ),
        ],
      ),
    );
  }
}