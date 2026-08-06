// lib/features/recognition/recognition_screen.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../models/recognition_model.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/cyber_button.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/status_indicator.dart';
import 'widgets/ai_scanning_animation.dart';
import 'widgets/recognition_result_card.dart';

class RecognitionScreen extends ConsumerStatefulWidget {
  const RecognitionScreen({super.key});

  @override
  ConsumerState<RecognitionScreen> createState() => _RecognitionScreenState();
}

class _RecognitionScreenState extends ConsumerState<RecognitionScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isProcessing = false;
  RecognitionResponseModel? _recognitionResult;
  String? _errorMessage;

  Future<void> _captureAndRecognize(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1280,
      );

      if (file == null) return;

      setState(() {
        _selectedImage = File(file.path);
        _isProcessing = true;
        _recognitionResult = null;
        _errorMessage = null;
      });

      final recognitionService = ref.read(recognitionServiceProvider);
      final result = await recognitionService.recognizeFaces(_selectedImage!);

      ref.invalidate(recognitionLogsProvider(null));
      ref.invalidate(dashboardStatsProvider);

      if (mounted) {
        setState(() {
          _recognitionResult = result;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasRecognized =
        _recognitionResult != null && _recognitionResult!.recognizedFaces.isNotEmpty;
    final hasUnknown =
        _recognitionResult != null && _recognitionResult!.unknownFaces.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('LIVE RECOGNITION SCANNER'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Image Preview & HUD Scanner
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.neonCyan.withOpacity(0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.neonCyan.withOpacity(0.1),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (_selectedImage != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: kIsWeb
                          ? Image.network(
                              _selectedImage!.path,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                    )
                  else
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.face_retouching_natural,
                              size: 72, color: AppTheme.neonCyan),
                          SizedBox(height: 12),
                          Text(
                            'NO IMAGE SELECTED',
                            style: TextStyle(
                              color: AppTheme.neonCyan,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Take photo or choose from gallery to test live AI recognition.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  if (_isProcessing)
                    const Center(child: AiScanningAnimation(size: 200)),

                  Positioned(
                    top: 16,
                    left: 16,
                    child: StatusIndicator(
                      label: _isProcessing
                          ? 'PROCESSING INSIGHTFACE...'
                          : hasRecognized
                              ? 'MATCH CONFIRMED'
                              : hasUnknown
                                  ? 'UNKNOWN FACE DETECTED'
                                  : 'SCANNER READY',
                      active: _isProcessing || hasRecognized || hasUnknown,
                      activeColor: _isProcessing
                          ? AppTheme.neonCyan
                          : hasRecognized
                              ? AppTheme.neonGreen
                              : AppTheme.errorRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: CyberButton(
                    label: 'CAMERA SCAN',
                    icon: Icons.camera_alt,
                    glowColor: AppTheme.neonCyan,
                    onPressed: _isProcessing
                        ? null
                        : () => _captureAndRecognize(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CyberButton(
                    label: 'PICK PHOTO',
                    icon: Icons.photo_library,
                    glowColor: AppTheme.neonPurple,
                    onPressed: _isProcessing
                        ? null
                        : () => _captureAndRecognize(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Error Display
            if (_errorMessage != null)
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppTheme.errorRed),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Recognition Failed: $_errorMessage',
                        style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Results Display
            if (_recognitionResult != null) ...[
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'AI ANALYSIS RESULT',
                          style: TextStyle(
                            color: AppTheme.neonCyan,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          '${_recognitionResult!.processingTimeMs} ms',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Faces Detected: ${_recognitionResult!.facesDetected}',
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    if (_recognitionResult!.recognizedFaces.isNotEmpty)
                      ..._recognitionResult!.recognizedFaces.map((face) {
                        final int conf = (face.confidence * 100).toInt();
                        return Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.neonGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.neonGreen.withOpacity(0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.verified, color: AppTheme.neonGreen),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      face.personName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: AppTheme.textPrimary),
                                    ),
                                    Text(
                                      'Person ID: ${face.personId} | Similarity: ${(face.similarity * 100).toStringAsFixed(1)}%',
                                      style: const TextStyle(
                                          color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '$conf%',
                                style: const TextStyle(
                                  color: AppTheme.neonGreen,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    if (_recognitionResult!.unknownFaces.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.errorRed.withOpacity(0.5)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Unknown face detected and saved to storage logs.',
                                style: TextStyle(color: AppTheme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}