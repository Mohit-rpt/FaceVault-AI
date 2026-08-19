// lib/features/persons/edit_person_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../models/person_model.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/cyber_button.dart';
import '../../shared/widgets/cyber_text_field.dart';
import '../../shared/widgets/glass_card.dart';

class EditPersonScreen extends ConsumerStatefulWidget {
  final PersonModel person;

  const EditPersonScreen({super.key, required this.person});

  @override
  ConsumerState<EditPersonScreen> createState() => _EditPersonScreenState();
}

class _EditPersonScreenState extends ConsumerState<EditPersonScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _nicknameCtrl;
  late TextEditingController _relationshipCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _birthdayCtrl;
  late TextEditingController _genderCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _companyCtrl;
  late TextEditingController _designationCtrl;
  late TextEditingController _departmentCtrl;
  late TextEditingController _empIdCtrl;
  late TextEditingController _collegeCtrl;

  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final p = widget.person;
    final d = p.details;

    _nameCtrl = TextEditingController(text: p.name);
    _nicknameCtrl = TextEditingController(text: p.nickname ?? '');
    _relationshipCtrl = TextEditingController(text: p.relationship ?? '');
    _phoneCtrl = TextEditingController(text: d?.phone ?? '');
    _emailCtrl = TextEditingController(text: d?.email ?? '');
    _birthdayCtrl = TextEditingController(text: d?.birthday ?? '');
    _genderCtrl = TextEditingController(text: d?.gender ?? '');
    _addressCtrl = TextEditingController(text: d?.address ?? '');
    _companyCtrl = TextEditingController(text: d?.company ?? '');
    _designationCtrl = TextEditingController(text: d?.designation ?? '');
    _departmentCtrl = TextEditingController(text: d?.department ?? '');
    _empIdCtrl = TextEditingController(text: d?.employeeId ?? '');
    _collegeCtrl = TextEditingController(text: d?.college ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _relationshipCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _birthdayCtrl.dispose();
    _genderCtrl.dispose();
    _addressCtrl.dispose();
    _companyCtrl.dispose();
    _designationCtrl.dispose();
    _departmentCtrl.dispose();
    _empIdCtrl.dispose();
    _collegeCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final service = ref.read(personServiceProvider);
      final String bdayRaw = _birthdayCtrl.text.trim();
      String? birthdayVal;
      if (bdayRaw.isNotEmpty) {
        try {
          final parsed = DateTime.parse(bdayRaw);
          birthdayVal = "${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid birthday format. Please use YYYY-MM-DD (e.g. 1995-05-15)'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
      }

      final String? phoneVal = _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim();
      final String? emailVal = _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim();
      final String? genderVal = _genderCtrl.text.trim().isEmpty ? null : _genderCtrl.text.trim();
      final String? addressVal = _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();
      final String? companyVal = _companyCtrl.text.trim().isEmpty ? null : _companyCtrl.text.trim();
      final String? designationVal = _designationCtrl.text.trim().isEmpty ? null : _designationCtrl.text.trim();
      final String? departmentVal = _departmentCtrl.text.trim().isEmpty ? null : _departmentCtrl.text.trim();
      final String? empIdVal = _empIdCtrl.text.trim().isEmpty ? null : _empIdCtrl.text.trim();
      final String? collegeVal = _collegeCtrl.text.trim().isEmpty ? null : _collegeCtrl.text.trim();

      final updateData = {
        'name': _nameCtrl.text.trim(),
        'nickname': _nicknameCtrl.text.trim().isEmpty ? null : _nicknameCtrl.text.trim(),
        'relationship': _relationshipCtrl.text.trim().isEmpty ? null : _relationshipCtrl.text.trim(),
        'details': {
          'phone': phoneVal,
          'email': emailVal,
          'birthday': birthdayVal,
          'gender': genderVal,
          'address': addressVal,
          'company': companyVal,
          'designation': designationVal,
          'department': departmentVal,
          'employee_id': empIdVal,
          'college': collegeVal,
        },
      };

      await service.updatePerson(widget.person.personId, updateData);

      ref.invalidate(personDetailProvider(widget.person.personId));
      ref.invalidate(personsListProvider(null));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppTheme.neonGreen,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadNewFacePhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 100, maxWidth: 1920);
      if (picked == null) return;

      setState(() => _isSaving = true);

      final service = ref.read(personServiceProvider);
      await service.registerFace(widget.person.personId, [picked]);

      // Sync & update AiWorker
      final syncManager = ref.read(syncManagerProvider);
      await syncManager.checkAndSync();
      if (!mounted) return;

      final vectorIndexManager = ref.read(vectorIndexManagerProvider);
      await vectorIndexManager.refreshFromHive();
      if (!mounted) return;

      final aiWorker = ref.read(aiWorkerProvider);
      if (aiWorker.isInitialized) {
        aiWorker.updateVectorIndex(vectorIndexManager.getIndexItems());
      }

      if (!mounted) return;
      ref.invalidate(personDetailProvider(widget.person.personId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('New face image registered & trained!'),
            backgroundColor: AppTheme.neonGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Face registration error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteFaceImage(int imageId) async {
    try {
      final service = ref.read(personServiceProvider);
      await service.deleteFaceImage(widget.person.personId, imageId);

      ref.invalidate(personDetailProvider(widget.person.personId));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Face image removed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete image: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EDIT PROFILE'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.neonCyan),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Personal Information Card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PERSONAL INFORMATION',
                        style: TextStyle(
                          color: AppTheme.neonCyan,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CyberTextField(
                        label: 'Full Name *',
                        controller: _nameCtrl,
                        validator: (v) => v!.trim().isEmpty ? 'Name required' : null,
                      ),
                      const SizedBox(height: 10),
                      CyberTextField(label: 'Nickname', controller: _nicknameCtrl),
                      const SizedBox(height: 10),
                      CyberTextField(label: 'Relationship / Tag', controller: _relationshipCtrl),
                      const SizedBox(height: 10),
                      CyberTextField(label: 'Phone', controller: _phoneCtrl),
                      const SizedBox(height: 10),
                      CyberTextField(label: 'Email', controller: _emailCtrl),
                      const SizedBox(height: 10),
                      CyberTextField(label: 'Birthday (YYYY-MM-DD)', controller: _birthdayCtrl),
                      const SizedBox(height: 10),
                      CyberTextField(label: 'Gender', controller: _genderCtrl),
                      const SizedBox(height: 10),
                      CyberTextField(label: 'Address', controller: _addressCtrl),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Professional Information Card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PROFESSIONAL INFORMATION',
                        style: TextStyle(
                          color: AppTheme.neonCyan,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CyberTextField(label: 'Company', controller: _companyCtrl),
                      const SizedBox(height: 10),
                      CyberTextField(label: 'Designation / Job Role', controller: _designationCtrl),
                      const SizedBox(height: 10),
                      CyberTextField(label: 'Department', controller: _departmentCtrl),
                      const SizedBox(height: 10),
                      CyberTextField(label: 'Employee ID', controller: _empIdCtrl),
                      const SizedBox(height: 10),
                      CyberTextField(label: 'College / University', controller: _collegeCtrl),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Face Images Management Card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'FACE IMAGES & DATA',
                            style: TextStyle(
                              color: AppTheme.neonCyan,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                              fontSize: 13,
                            ),
                          ),
                          PopupMenuButton<ImageSource>(
                            icon: const Icon(Icons.add_a_photo, color: AppTheme.neonCyan),
                            onSelected: _uploadNewFacePhoto,
                            itemBuilder: (ctx) => const [
                              PopupMenuItem(value: ImageSource.camera, child: Text('Take Camera Photo')),
                              PopupMenuItem(value: ImageSource.gallery, child: Text('Upload from Gallery')),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (widget.person.images.isEmpty)
                        const Text('No registered face images.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
                      else
                        SizedBox(
                          height: 80,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.person.images.length,
                            itemBuilder: (ctx, i) {
                              final img = widget.person.images[i];
                              return Stack(
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: AppTheme.neonCyan.withOpacity(0.5)),
                                      color: AppTheme.surfaceDark,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        img.imagePath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.person, color: AppTheme.neonCyan),
                                      ),
                                    ),
                                  ),
                                  if (img.imageId != null)
                                    Positioned(
                                      top: 2,
                                      right: 10,
                                      child: GestureDetector(
                                        onTap: () => _deleteFaceImage(img.imageId!),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppTheme.errorRed,
                                          ),
                                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Save Profile Button
                if (_isSaving)
                  const Center(child: CircularProgressIndicator(color: AppTheme.neonGreen))
                else
                  CyberButton(
                    label: 'SAVE CHANGES',
                    glowColor: AppTheme.neonGreen,
                    onPressed: _saveProfile,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
