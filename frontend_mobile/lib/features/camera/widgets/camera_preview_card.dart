import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';

class CameraPreviewCard extends StatelessWidget {
  final Map<String, dynamic> camera;
  const CameraPreviewCard({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    final isConnected = camera['status'] == 'Connected';

    return GlassCard(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          // Mock preview
          Container(
            height: 200,
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
            child: Stack(
              children: [
                // Dark camera placeholder
                Center(
                  child: Icon(
                    isConnected ? Icons.videocam : Icons.videocam_off,
                    size: 48,
                    color: isConnected
                        ? AppTheme.neonGreen.withOpacity(0.6)
                        : AppTheme.errorRed.withOpacity(0.6),
                  ),
                ),
                // HUD corners
                CustomPaint(
                  size: Size.infinite,
                  painter: _HudCornersPainter(
                    color: isConnected ? AppTheme.neonGreen : AppTheme.errorRed,
                  ),
                ),
                // Connection indicator
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
              ],
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
    canvas.drawLine(Offset(8, cornerLength), Offset(8, 8), paint);
    canvas.drawLine(Offset(8, 8), Offset(cornerLength, 8), paint);
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