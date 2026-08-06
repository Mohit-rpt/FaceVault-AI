// lib/features/persons/person_details_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/person_model.dart';
import '../../models/timeline_model.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/status_indicator.dart';
import 'edit_person_screen.dart';

class PersonDetailsScreen extends ConsumerWidget {
  final dynamic personId;

  const PersonDetailsScreen({super.key, required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personAsync = ref.watch(personDetailProvider(personId));
    final timelineAsync = ref.watch(personTimelineProvider(personId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('PERSON DETAILS'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.neonCyan),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          personAsync.when(
            data: (person) => IconButton(
              icon: const Icon(Icons.edit_note, color: AppTheme.neonCyan, size: 28),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditPersonScreen(person: person),
                  ),
                );
              },
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorRed),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      body: personAsync.when(
        data: (person) {
          final details = person.details;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Profile Header Card
                GlassCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.neonCyan, width: 2),
                          color: AppTheme.surfaceDark,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.neonCyan.withOpacity(0.4),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.person, color: AppTheme.neonCyan, size: 36),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              person.fullName.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (person.nickname != null && person.nickname!.isNotEmpty)
                              Text(
                                '@${person.nickname}',
                                style: const TextStyle(
                                  color: AppTheme.neonCyan,
                                  fontSize: 14,
                                ),
                              ),
                            const SizedBox(height: 8),
                            StatusIndicator(
                              label: person.relationship ?? 'Registered',
                              active: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Personal Details Card
                _buildSectionCard(context, 'PERSONAL INFORMATION', [
                  _buildField('Full Name', person.fullName),
                  if (person.nickname != null && person.nickname!.isNotEmpty)
                    _buildField('Nickname', person.nickname!),
                  if (details?.gender != null && details!.gender!.isNotEmpty)
                    _buildField('Gender', details.gender!),
                  if (details?.phone != null && details!.phone!.isNotEmpty)
                    _buildField('Phone', details.phone!),
                  if (details?.email != null && details!.email!.isNotEmpty)
                    _buildField('Email', details.email!),
                  if (details?.birthday != null && details!.birthday!.isNotEmpty)
                    _buildField('Birthday', details.birthday!),
                  if (details?.address != null && details!.address!.isNotEmpty)
                    _buildField('Address', details.address!),
                ]),
                const SizedBox(height: 12),

                // Professional Information Card
                if (details?.company != null ||
                    details?.designation != null ||
                    details?.department != null ||
                    details?.employeeId != null ||
                    details?.college != null)
                  _buildSectionCard(context, 'PROFESSIONAL INFORMATION', [
                    if (details?.company != null && details!.company!.isNotEmpty)
                      _buildField('Company', details.company!),
                    if (details?.designation != null && details!.designation!.isNotEmpty)
                      _buildField('Designation', details.designation!),
                    if (details?.department != null && details!.department!.isNotEmpty)
                      _buildField('Department', details.department!),
                    if (details?.employeeId != null && details!.employeeId!.isNotEmpty)
                      _buildField('Employee ID', details.employeeId!),
                    if (details?.college != null && details!.college!.isNotEmpty)
                      _buildField('College', details.college!),
                  ]),
                if (details?.company != null ||
                    details?.designation != null ||
                    details?.department != null ||
                    details?.employeeId != null ||
                    details?.college != null)
                  const SizedBox(height: 12),

                // Dynamic Custom Fields Card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'CUSTOM FIELDS',
                            style: TextStyle(
                              color: AppTheme.neonCyan.withOpacity(0.8),
                              fontSize: 13,
                              letterSpacing: 2,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppTheme.neonCyan, size: 22),
                            onPressed: () => _showAddCustomFieldDialog(context, ref),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (person.customFields.isEmpty)
                        const Text('No custom fields added.',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13))
                      else
                        ...person.customFields.map((cf) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 110,
                                  child: Text(
                                    cf.fieldName,
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    cf.fieldValue ?? '-',
                                    style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                                  ),
                                ),
                                if (cf.fieldId != null) ...[
                                  GestureDetector(
                                    onTap: () => _showEditCustomFieldDialog(context, ref, cf),
                                    child: const Icon(Icons.edit, color: AppTheme.neonCyan, size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _deleteCustomField(context, ref, cf.fieldId!),
                                    child: const Icon(Icons.close, color: AppTheme.errorRed, size: 18),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Face Data Section
                _buildSectionCard(context, 'FACE EMBEDDINGS & IMAGES', [
                  Row(
                    children: [
                      const Icon(Icons.memory, color: AppTheme.neonPurple, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${person.embeddingsCount} Face Embeddings Stored',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.photo_library_outlined, color: AppTheme.neonCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        '${person.images.length} Registered Face Images',
                        style: const TextStyle(color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ]),
                const SizedBox(height: 12),

                // Timeline Section
                timelineAsync.when(
                  data: (timelines) {
                    if (timelines.isEmpty) return const SizedBox.shrink();
                    return _buildSectionCard(
                      context,
                      'INTERACTION TIMELINE',
                      timelines.map((t) => _buildTimelineItem(t)).toList(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.neonCyan),
        ),
        error: (err, stack) => Center(
          child: Text('Failed to load details: $err',
              style: const TextStyle(color: AppTheme.textSecondary)),
        ),
      ),
    );
  }

  void _showAddCustomFieldDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final valueCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ADD CUSTOM FIELD', style: TextStyle(color: AppTheme.neonCyan, fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Field Name (e.g. Employee ID, Tag)', labelStyle: TextStyle(color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valueCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Field Value', labelStyle: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonCyan, foregroundColor: Colors.black),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                final service = ref.read(personServiceProvider);
                await service.addCustomField(personId, nameCtrl.text.trim(), valueCtrl.text.trim());
                ref.invalidate(personDetailProvider(personId));
                ref.invalidate(personsListProvider(null));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add field: $e')));
                }
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  void _showEditCustomFieldDialog(BuildContext context, WidgetRef ref, CustomFieldModel field) {
    final nameCtrl = TextEditingController(text: field.fieldName);
    final valueCtrl = TextEditingController(text: field.fieldValue ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('EDIT CUSTOM FIELD', style: TextStyle(color: AppTheme.neonCyan, fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Field Name', labelStyle: TextStyle(color: AppTheme.textSecondary)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: valueCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(labelText: 'Field Value', labelStyle: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: AppTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.neonCyan, foregroundColor: Colors.black),
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              try {
                final service = ref.read(personServiceProvider);
                await service.updateCustomField(personId, field.fieldId!, nameCtrl.text.trim(), valueCtrl.text.trim());
                ref.invalidate(personDetailProvider(personId));
                ref.invalidate(personsListProvider(null));
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to edit field: $e')));
                }
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCustomField(BuildContext context, WidgetRef ref, int fieldId) async {
    try {
      final service = ref.read(personServiceProvider);
      await service.deleteCustomField(personId, fieldId);
      ref.invalidate(personDetailProvider(personId));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete custom field: $e')));
      }
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceDark,
        title: const Text('Delete Person?', style: TextStyle(color: AppTheme.errorRed)),
        content: const Text('Are you sure you want to delete this person and all face data?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final personService = ref.read(personServiceProvider);
                await personService.deletePerson(personId);
                ref.invalidate(personsListProvider(null));
                ref.invalidate(dashboardStatsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Person deleted successfully')),
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete: $e')),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, String title, List<Widget> children) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.neonCyan.withOpacity(0.8),
              fontSize: 13,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem(TimelineModel item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.neonGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                if (item.description != null)
                  Text(item.description!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(
            item.interactionDate.split('T').first,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}