// lib/features/registration/widgets/person_details_form_step.dart
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_text_field.dart';
import '../../../shared/widgets/cyber_dropdown.dart';
import '../../../shared/widgets/cyber_button.dart';

class PersonDetailsFormStep extends StatefulWidget {
  final ValueChanged<Map<String, dynamic>> onFormChanged;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const PersonDetailsFormStep({
    super.key,
    required this.onFormChanged,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<PersonDetailsFormStep> createState() => _PersonDetailsFormStepState();
}

class _PersonDetailsFormStepState extends State<PersonDetailsFormStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  String? _gender;
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _jobCtrl = TextEditingController();
  final _deptCtrl = TextEditingController();
  final _empIdCtrl = TextEditingController();
  final _workEmailCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nicknameCtrl.dispose();
    _ageCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _companyCtrl.dispose();
    _jobCtrl.dispose();
    _deptCtrl.dispose();
    _empIdCtrl.dispose();
    _workEmailCtrl.dispose();
    _tagsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final data = {
        'fullName': _nameCtrl.text,
        'nickname': _nicknameCtrl.text,
        'age': _ageCtrl.text,
        'gender': _gender,
        'phone': _phoneCtrl.text,
        'email': _emailCtrl.text,
        'address': _addressCtrl.text,
        'company': _companyCtrl.text,
        'jobRole': _jobCtrl.text,
        'department': _deptCtrl.text,
        'employeeId': _empIdCtrl.text,
        'workEmail': _workEmailCtrl.text,
        'tags': _tagsCtrl.text.split(',').map((s) => s.trim()).toList(),
        'notes': _notesCtrl.text,
      };
      widget.onFormChanged(data);
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PERSONAL DETAILS',
                style: TextStyle(
                    color: AppTheme.neonCyan,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            CyberTextField(
                label: 'Full Name *', controller: _nameCtrl,
                validator: (v) => v!.isEmpty ? 'Required' : null),
            const SizedBox(height: 12),
            CyberTextField(label: 'Nickname', controller: _nicknameCtrl),
            const SizedBox(height: 12),
            CyberTextField(
                label: 'Age',
                controller: _ageCtrl,
                keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            CyberDropdown<String>(
              label: 'Gender',
              value: _gender,
              items: ['Male', 'Female', 'Other']
                  .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                  .toList(),
              onChanged: (v) => setState(() => _gender = v),
            ),
            const SizedBox(height: 12),
            CyberTextField(label: 'Phone', controller: _phoneCtrl),
            const SizedBox(height: 12),
            CyberTextField(label: 'Email', controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 12),
            CyberTextField(label: 'Address', controller: _addressCtrl),
            const SizedBox(height: 24),

            const Text('PROFESSIONAL DETAILS',
                style: TextStyle(
                    color: AppTheme.neonCyan,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            CyberTextField(label: 'Company', controller: _companyCtrl),
            const SizedBox(height: 12),
            CyberTextField(label: 'Job Role', controller: _jobCtrl),
            const SizedBox(height: 12),
            CyberTextField(label: 'Department', controller: _deptCtrl),
            const SizedBox(height: 12),
            CyberTextField(label: 'Employee ID', controller: _empIdCtrl),
            const SizedBox(height: 12),
            CyberTextField(label: 'Work Email', controller: _workEmailCtrl,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 24),

            const Text('ADDITIONAL',
                style: TextStyle(
                    color: AppTheme.neonCyan,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            CyberTextField(
                label: 'Tags (comma separated)', controller: _tagsCtrl),
            const SizedBox(height: 12),
            CyberTextField(label: 'Notes', controller: _notesCtrl,
                keyboardType: TextInputType.multiline),
            const SizedBox(height: 24),

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
                    label: 'NEXT: REVIEW',
                    glowColor: AppTheme.neonGreen,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}