// lib/features/registration/registration_screen.dart

import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/futuristic_app_bar.dart';
import 'widgets/image_capture_step.dart';
import 'widgets/person_details_form_step.dart';
import 'widgets/review_step.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final PageController _controller = PageController();
  int _currentStep = 0;

  List<String> capturedImagePaths = [];
  Map<String, dynamic> formData = {};

  void _nextStep() {
    if (_currentStep < 2) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _controller.previousPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const FuturisticAppBar(title: 'REGISTRATION'),
      body: Column(
        children: [
          _buildStepIndicator(),
          const SizedBox(height: 12),
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentStep = i),
              children: [
                ImageCaptureStep(
                  onImagesChanged: (images) {
                    capturedImagePaths = images;
                  },
                  onNext: _nextStep,
                ),
                PersonDetailsFormStep(
                  onFormChanged: (data) {
                    formData = data;
                  },
                  onNext: _nextStep,
                  onBack: _previousStep,
                ),
                ReviewStep(
                  imagePaths: capturedImagePaths,
                  formData: formData,
                  onBack: _previousStep,
                  onSaveSuccess: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Capture', 'Details', 'Review'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isDone = index < _currentStep;
          return Expanded(
            child: Row(
              children: [
                if (index > 0)
                  Expanded(
                    child: Container(
                      height: 2,
                      color: isDone
                          ? AppTheme.neonCyan
                          : AppTheme.neonCyan.withOpacity(0.2),
                    ),
                  ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isActive
                              ? AppTheme.neonCyan
                              : isDone
                                  ? AppTheme.neonGreen
                                  : AppTheme.textSecondary,
                          width: 2,
                        ),
                        color: isActive
                            ? AppTheme.neonCyan.withOpacity(0.2)
                            : isDone
                                ? AppTheme.neonGreen.withOpacity(0.2)
                                : Colors.transparent,
                      ),
                      child: Center(
                        child: isDone
                            ? const Icon(Icons.check,
                                color: AppTheme.neonGreen, size: 18)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? AppTheme.neonCyan
                                      : AppTheme.textSecondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      steps[index],
                      style: TextStyle(
                        fontSize: 10,
                        color: isActive
                            ? AppTheme.neonCyan
                            : AppTheme.textSecondary,
                        letterSpacing: 1,
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}