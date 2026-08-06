// lib/features/registration/widgets/review_step.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/person_model.dart';
import '../../../providers/app_providers.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/cyber_button.dart';

class ReviewStep extends ConsumerStatefulWidget {
  final List<String> imagePaths;
  final Map<String, dynamic> formData;
  final VoidCallback onBack;
  final VoidCallback onSaveSuccess;

  const ReviewStep({
    super.key,
    required this.imagePaths,
    required this.formData,
    required this.onBack,
    required this.onSaveSuccess,
  });

  @override
  ConsumerState<ReviewStep> createState() => _ReviewStepState();
}

class _ReviewStepState extends ConsumerState<ReviewStep> {
  bool _isSaving = false;

  Future<void> _submitRegistration() async {
    final String fullName = widget.formData['fullName'] ?? '';
    if (fullName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Full name is required.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final personService = ref.read(personServiceProvider);

      // Step 1: Create Person Record on FastAPI Backend
      final personReq = PersonCreateReq(
        name: fullName,
        nickname: widget.formData['nickname'],
        relationship: widget.formData['relationship'] ?? 'Registered',
        details: PersonDetailModel(
          phone: widget.formData['phone'],
          email: widget.formData['email'],
          company: widget.formData['company'],
          designation: widget.formData['jobRole'],
          address: widget.formData['address'],
        ),
      );

      final createdPerson = await personService.createPerson(personReq);

      // Step 2: Upload Face Images for Registration & Embedding Generation
      if (widget.imagePaths.isNotEmpty) {
        final List<dynamic> imageFiles = widget.imagePaths.map((path) {
          if (kIsWeb) {
            return XFile(path);
          }
          return File(path);
        }).toList();
        await personService.registerFace(createdPerson.personId, imageFiles);
      }

      // Step 3: Refresh Providers
      ref.invalidate(personsListProvider(null));
      ref.invalidate(dashboardStatsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${createdPerson.name} registered & faces trained successfully!'),
            backgroundColor: AppTheme.neonGreen.withOpacity(0.9),
          ),
        );
        widget.onSaveSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REVIEW REGISTRATION',
            style: TextStyle(
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppTheme.neonCyan,
            ),
          ),
          const SizedBox(height: 16),

          // Images Preview
          GlassCard(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CAPTURED IMAGES (${widget.imagePaths.length})',
                  style: const TextStyle(
                    color: AppTheme.neonCyan,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 90,
                  child: widget.imagePaths.isEmpty
                      ? const Center(
                          child: Text('No images captured',
                              style: TextStyle(color: AppTheme.textSecondary)))
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.imagePaths.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: AppTheme.neonCyan.withOpacity(0.5)),
                                image: DecorationImage(
                                  image: FileImage(File(widget.imagePaths[i])),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Details Summary
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('PERSONAL DETAILS'),
                _buildRow('Full Name', widget.formData['fullName']),
                _buildRow('Nickname', widget.formData['nickname']),
                _buildRow('Relationship', widget.formData['relationship']),
                _buildRow('Phone', widget.formData['phone']),
                _buildRow('Email', widget.formData['email']),
                _buildRow('Address', widget.formData['address']),
                const SizedBox(height: 12),
                _buildSectionTitle('PROFESSIONAL DETAILS'),
                _buildRow('Company', widget.formData['company']),
                _buildRow('Job Role', widget.formData['jobRole']),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Action Buttons
          if (_isSaving)
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(color: AppTheme.neonGreen),
                  SizedBox(height: 12),
                  Text('Uploading images & generating InsightFace embeddings...',
                      style: TextStyle(color: AppTheme.neonCyan)),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: CyberButton(
                    label: 'BACK',
                    glowColor: AppTheme.textSecondary,
                    onPressed: widget.onBack,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CyberButton(
                    label: 'SUBMIT & TRAIN',
                    glowColor: AppTheme.neonGreen,
                    onPressed: _submitRegistration,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.neonCyan.withOpacity(0.8),
          letterSpacing: 1.5,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label,
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
          ),
        ],
      ),
    );
  }
}