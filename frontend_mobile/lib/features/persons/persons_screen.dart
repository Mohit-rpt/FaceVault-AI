// lib/features/persons/persons_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/futuristic_app_bar.dart';
import '../../shared/widgets/glass_card.dart';
import 'person_details_screen.dart';
import 'widgets/person_card.dart';

class PersonsScreen extends ConsumerStatefulWidget {
  const PersonsScreen({super.key});

  @override
  ConsumerState<PersonsScreen> createState() => _PersonsScreenState();
}

class _PersonsScreenState extends ConsumerState<PersonsScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isFaceSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performFaceSearch(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile == null) return;

      setState(() => _isFaceSearching = true);

      final personService = ref.read(personServiceProvider);
      final result = await personService.searchByFace(pickedFile);

      if (!mounted) return;
      setState(() => _isFaceSearching = false);

      if (result['matched'] == true && result['person'] != null) {
        final personData = result['person'];
        final personId = personData['person_id'];
        final confidence = result['confidence'] ?? 0.0;

        showModalBottomSheet(
          context: context,
          backgroundColor: AppTheme.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: AppTheme.neonGreen, size: 48),
                const SizedBox(height: 10),
                const Text(
                  'FACE MATCH FOUND!',
                  style: TextStyle(
                    color: AppTheme.neonGreen,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Name: ${personData['name']}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Match Confidence: $confidence%',
                  style: const TextStyle(color: AppTheme.neonCyan, fontSize: 14),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.neonCyan,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PersonDetailsScreen(personId: personId),
                      ),
                    );
                  },
                  child: const Text('VIEW FULL PROFILE'),
                ),
              ],
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No registered person matched the face.'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFaceSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Face search error: $e'), backgroundColor: AppTheme.errorRed),
        );
      }
    }
  }

  void _showFaceSearchOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'SEARCH BY FACE PHOTO',
              style: TextStyle(
                color: AppTheme.neonCyan,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.neonCyan),
              title: const Text('Take Photo with Camera', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _performFaceSearch(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.neonPurple),
              title: const Text('Choose Photo from Gallery', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () {
                Navigator.pop(ctx);
                _performFaceSearch(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _switchToEmulatorHostIp() async {
    final client = ref.read(apiClientProvider);
    await client.updateBaseUrl('http://10.0.2.2:8000/api/v1');
    ref.invalidate(personsListProvider(null));
    ref.invalidate(dashboardStatsProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Switched Base URL to Emulator Host IP (10.0.2.2:8000)'),
          backgroundColor: AppTheme.neonGreen,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final personsAsync = ref.watch(personsListProvider(_searchQuery.isEmpty ? null : _searchQuery));

    return Scaffold(
      appBar: const FuturisticAppBar(title: 'PERSONS DATABASE'),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Face Search Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.trim()),
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search by name, email, phone, company...',
                        hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5), fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: AppTheme.neonCyan),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.neonCyan.withOpacity(0.3)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.neonCyan.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.neonCyan, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isFaceSearching ? null : _showFaceSearchOptions,
                    child: Container(
                      height: 52,
                      width: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.neonCyan.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.neonCyan, width: 1.5),
                      ),
                      child: _isFaceSearching
                          ? const Center(
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: AppTheme.neonCyan, strokeWidth: 2),
                              ),
                            )
                          : const Icon(Icons.face_retouching_natural, color: AppTheme.neonCyan),
                    ),
                  ),
                ],
              ),
            ),

            // Persons List
            Expanded(
              child: RefreshIndicator(
                color: AppTheme.neonCyan,
                onRefresh: () async {
                  ref.invalidate(personsListProvider(_searchQuery.isEmpty ? null : _searchQuery));
                },
                child: personsAsync.when(
                  data: (persons) {
                    if (persons.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_outlined,
                                size: 64, color: AppTheme.textSecondary.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No persons matching "$_searchQuery"'
                                  : 'No persons registered in database yet.',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: persons.length,
                      itemBuilder: (context, index) {
                        final person = persons[index];
                        return PersonCard(
                          person: person,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PersonDetailsScreen(personId: person.personId),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppTheme.neonCyan),
                  ),
                  error: (err, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.dns_outlined, size: 48, color: AppTheme.errorRed),
                          const SizedBox(height: 12),
                          Text(
                            'Unable to connect to backend server at:\n${ApiConstants.baseUrl}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Make sure backend server is running.\nIf using Android Emulator, use 10.0.2.2 instead of 127.0.0.1.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _switchToEmulatorHostIp,
                            icon: const Icon(Icons.phonelink_setup),
                            label: const Text('Use Android Host IP (10.0.2.2)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.neonGreen,
                              foregroundColor: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => ref.invalidate(personsListProvider(_searchQuery.isEmpty ? null : _searchQuery)),
                            icon: const Icon(Icons.refresh, color: AppTheme.neonCyan),
                            label: const Text('Retry Connection', style: TextStyle(color: AppTheme.neonCyan)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}