// lib/features/camera/widgets/camera_preview_card.dart

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../services/camera/camera_service.dart';
import '../../../services/camera/frame_processor.dart';
import '../../../services/local_recognition/local_recognition_result.dart';
import 'recognition_overlay.dart';

class CameraPreviewCard extends StatelessWidget {
  final Map<String, dynamic> camera;
  final CameraService? cameraService;
  final FrameProcessorMetrics? metrics;
  final List<LocalRecognitionResult>? recognitionResults;
  final VoidCallback? onSwitchCamera;

  const CameraPreviewCard({
    super.key,
    required this.camera,
    this.cameraService,
    this.metrics,
    this.recognitionResults,
    this.onSwitchCamera,
  });

  double _getPreviewAspectRatio(CameraService cameraService) {
    final rawAR = cameraService.controller!.value.aspectRatio;
    final sensorOr = cameraService.sensorOrientation;
    if (sensorOr == 90 || sensorOr == 270) {
      return 1.0 / rawAR;
    }
    return rawAR;
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = camera['status'] == 'Connected';
    final hasRealController = cameraService != null &&
        cameraService!.controller != null &&
        cameraService!.controller!.value.isInitialized;

    return GlassCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'LIVE CAMERA FEED',
                  style: TextStyle(
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppTheme.neonCyan,
                  ),
                ),
              ),
              if (metrics != null)
                Text(
                  'Cam: ${metrics!.cameraFps.toStringAsFixed(1)} FPS | Proc: ${metrics!.processingFps.toStringAsFixed(1)} FPS',
                  style: TextStyle(
                    fontSize: 10,
                    fontFamily: 'Orbitron',
                    color: AppTheme.neonGreen.withOpacity(0.9),
                  ),
                ),
            ],
          ),
          // Live Camera Preview Container
          Container(
            height: 320,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isConnected
                    ? AppTheme.neonGreen.withOpacity(0.6)
                    : AppTheme.errorRed.withOpacity(0.6),
                width: 1.5,
              ),
              boxShadow: isConnected
                  ? [
                      BoxShadow(
                        color: AppTheme.neonGreen.withOpacity(0.15),
                        blurRadius: 12,
                      )
                    ]
                  : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Real Hardware Camera Preview or Dark Icon Fallback
                  hasRealController && isConnected
                      ? AspectRatio(
                          aspectRatio: _getPreviewAspectRatio(cameraService!),
                          child: CameraPreview(cameraService!.controller!),
                        )
                      : Center(
                          child: Icon(
                            isConnected ? Icons.videocam : Icons.videocam_off,
                            size: 48,
                            color: isConnected
                                ? AppTheme.neonGreen.withOpacity(0.6)
                                : AppTheme.errorRed.withOpacity(0.6),
                          ),
                        ),
                  // Glowing Neon Recognition Overlay (Phase 3B-2B Live HUD)
                  if (hasRealController && isConnected && recognitionResults != null && recognitionResults!.isNotEmpty)
                    RecognitionOverlay(
                      recognitionResults: recognitionResults!,
                      lensDirection: cameraService!.currentLensDirection,
                      sensorOrientation: cameraService!.sensorOrientation,
                    ),
                  // HUD Corners
                  CustomPaint(
                    size: Size.infinite,
                    painter: _HudCornersPainter(
                      color: isConnected ? AppTheme.neonGreen : AppTheme.errorRed,
                    ),
                  ),
                  // Debug Panel Overlay (Phase 3B-1 Debug Metrics)
                  if (metrics != null && isConnected)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.neonCyan.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'FACES DETECTED: ${metrics!.detectedFaceCount}',
                              style: const TextStyle(
                                color: AppTheme.neonCyan,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                            Text(
                              'DROPPED: ${metrics!.framesDropped} | AVG PROC: ${metrics!.averageProcessingTimeMs}ms',
                              style: TextStyle(
                                color: AppTheme.textSecondary.withOpacity(0.8),
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Connection Indicator
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isConnected
                              ? AppTheme.neonGreen.withOpacity(0.5)
                              : AppTheme.errorRed.withOpacity(0.5),
                        ),
                      ),
                      child: Text(
                        isConnected ? 'CONNECTED' : 'OFFLINE',
                        style: TextStyle(
                          color: isConnected ? AppTheme.neonGreen : AppTheme.errorRed,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  if (hasRealController && isConnected && onSwitchCamera != null)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: GestureDetector(
                        onTap: onSwitchCamera,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.neonCyan.withOpacity(0.5)),
                          ),
                          child: const Icon(Icons.cameraswitch, color: AppTheme.neonCyan, size: 20),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudCornersPainter extends CustomPainter {
  final Color color;
  _HudCornersPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const cornerLength = 20.0;
    // Top-left
    canvas.drawLine(const Offset(8, cornerLength), const Offset(8, 8), paint);
    canvas.drawLine(const Offset(8, 8), const Offset(cornerLength, 8), paint);
    // Top-right
    canvas.drawLine(Offset(size.width - cornerLength, 8), Offset(size.width - 8, 8), paint);
    canvas.drawLine(Offset(size.width - 8, 8), Offset(size.width - 8, cornerLength), paint);
    // Bottom-left
    canvas.drawLine(Offset(8, size.height - cornerLength), Offset(8, size.height - 8), paint);
    canvas.drawLine(Offset(8, size.height - 8), Offset(cornerLength, size.height - 8), paint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - cornerLength, size.height - 8),
        Offset(size.width - 8, size.height - 8), paint);
    canvas.drawLine(Offset(size.width - 8, size.height - 8),
        Offset(size.width - 8, size.height - cornerLength), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}