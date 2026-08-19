// lib/features/registration/widgets/image_capture_step.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/cyber_button.dart';

class ImageCaptureStep extends StatefulWidget {
  final ValueChanged<List<String>> onImagesChanged;
  final VoidCallback onNext;

  const ImageCaptureStep({
    super.key,
    required this.onImagesChanged,
    required this.onNext,
  });

  @override
  State<ImageCaptureStep> createState() => _ImageCaptureStepState();
}

class _ImageCaptureStepState extends State<ImageCaptureStep> {
  final List<String> _imagePaths = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    if (_imagePaths.length >= 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 20 images allowed.')),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 100,
        maxWidth: 1920,
      );

      if (image != null) {
        setState(() {
          _imagePaths.add(image.path);
        });
        widget.onImagesChanged(List.from(_imagePaths));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imagePaths.removeAt(index);
    });
    widget.onImagesChanged(List.from(_imagePaths));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Capture / Preview Card
          Expanded(
            flex: 3,
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.neonCyan.withOpacity(0.4)),
                      color: AppTheme.surfaceDark,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              size: 64, color: AppTheme.neonCyan.withOpacity(0.8)),
                          const SizedBox(height: 12),
                          const Text(
                            'FACE REGISTRATION SCANNER',
                            style: TextStyle(
                              color: AppTheme.neonCyan,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Capture 1 or more face photos from multiple angles.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: CyberButton(
                        label: 'OPEN CAMERA',
                        icon: Icons.camera_alt,
                        glowColor: AppTheme.neonCyan,
                        onPressed: () => _pickImage(ImageSource.camera),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Gallery selection button
          CyberButton(
            label: 'SELECT FROM GALLERY',
            icon: Icons.photo_library,
            glowColor: AppTheme.neonPurple,
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
          const SizedBox(height: 16),

          // Captured Images Grid
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'CAPTURED IMAGES',
                      style: TextStyle(
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_imagePaths.length} Images Selected',
                      style: const TextStyle(
                        color: AppTheme.neonCyan,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _imagePaths.isEmpty
                      ? Center(
                          child: Text(
                            'No images selected yet. Take or choose photos above.',
                            style: TextStyle(
                                color: AppTheme.textSecondary.withOpacity(0.6)),
                          ),
                        )
                      : GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1,
                          ),
                          itemCount: _imagePaths.length,
                          itemBuilder: (context, index) => Stack(
                            children: [
                              Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppTheme.neonCyan.withOpacity(0.4)),
                                    image: DecorationImage(
                                      image: kIsWeb
                                          ? NetworkImage(_imagePaths[index])
                                          : FileImage(File(_imagePaths[index])) as ImageProvider,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.errorRed,
                                    ),
                                    child: const Icon(Icons.close,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Next step button
          CyberButton(
            label: 'NEXT: PERSON DETAILS',
            glowColor: AppTheme.neonGreen,
            onPressed: () {
              if (_imagePaths.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select at least 1 image first.')),
                );
                return;
              }
              widget.onNext();
            },
          ),
        ],
      ),
    );
  }
}