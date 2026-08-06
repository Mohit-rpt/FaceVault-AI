// lib/features/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'widgets/stats_grid.dart';
import 'widgets/recognition_activity_list.dart';
import 'widgets/camera_status_panel.dart';
import 'widgets/ai_core_visualization.dart';
import '../../shared/widgets/futuristic_app_bar.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isSmallScreen = screenWidth < 360;

    return Scaffold(
      appBar: const FuturisticAppBar(title: 'FACEVAULT AI'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const StatsGrid(),
              const SizedBox(height: 24),
              const RecognitionActivityList(),
              const SizedBox(height: 24),
              if (isSmallScreen) ...[
                const CameraStatusPanel(),
                const SizedBox(height: 16),
                const AiCoreVisualization(),
              ] else
                const Row(
                  children: [
                    Expanded(child: CameraStatusPanel()),
                    SizedBox(width: 16),
                    Expanded(child: AiCoreVisualization()),
                  ],
                ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}