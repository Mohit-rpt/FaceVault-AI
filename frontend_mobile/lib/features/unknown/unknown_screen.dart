// lib/features/unknown/unknown_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/futuristic_app_bar.dart';
import 'widgets/unknown_face_card.dart';

class UnknownScreen extends ConsumerWidget {
  const UnknownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(recognitionLogsProvider(null));

    return Scaffold(
      appBar: const FuturisticAppBar(title: 'UNKNOWN FACES'),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.neonCyan,
          onRefresh: () async {
            ref.invalidate(recognitionLogsProvider(null));
          },
          child: logsAsync.when(
            data: (logs) {
              final unknownLogs = logs.where((l) => l.personId == 0).toList();

              if (unknownLogs.isEmpty) {
                return const Center(
                  child: Text(
                    'No unknown faces detected.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: unknownLogs.length,
                itemBuilder: (context, index) {
                  final log = unknownLogs[index];
                  return UnknownFaceCard(
                    face: {
                      'id': log.logId.toString(),
                      'time': log.recognizedAt != null
                          ? log.recognizedAt!.replaceFirst('T', ' ').split('.').first
                          : 'Recent',
                      'confidence': (log.confidenceScore * 100).toInt(),
                      'camera': log.cameraSource ?? 'API Camera',
                    },
                  );
                },
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppTheme.neonCyan),
            ),
            error: (e, _) => Center(
              child: Text('Failed to load unknown logs: $e',
                  style: const TextStyle(color: AppTheme.textSecondary)),
            ),
          ),
        ),
      ),
    );
  }
}