// lib/features/settings/settings_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/cyber_button.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/futuristic_app_bar.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = ApiConstants.baseUrl;
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveBaseUrl() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      final client = ref.read(apiClientProvider);
      await client.updateBaseUrl(newUrl);

      // Invalidate all API providers to trigger immediate retry with the new Base URL
      ref.invalidate(dashboardStatsProvider);
      ref.invalidate(personsListProvider(null));
      ref.invalidate(recognitionLogsProvider(null));
      ref.invalidate(settingsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Base URL saved to $newUrl & reconnected successfully!'),
            backgroundColor: AppTheme.neonGreen.withOpacity(0.9),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating URL: $e'),
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
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: const FuturisticAppBar(title: 'SYSTEM SETTINGS'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Backend URL Config Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BACKEND SERVER CONFIGURATION',
                      style: TextStyle(
                        color: AppTheme.neonCyan,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _urlController,
                      style: const TextStyle(color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'FastAPI Base URL',
                        hintText: 'e.g. http://192.168.1.10:8000/api/v1',
                        labelStyle: const TextStyle(color: AppTheme.textSecondary),
                        prefixIcon: const Icon(Icons.dns, color: AppTheme.neonCyan),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppTheme.neonCyan.withOpacity(0.3)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_isSaving)
                      const Center(child: CircularProgressIndicator(color: AppTheme.neonCyan))
                    else
                      CyberButton(
                        label: 'SAVE & RECONNECT',
                        glowColor: AppTheme.neonCyan,
                        onPressed: _saveBaseUrl,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // AI Model Configuration Card
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'FACE RECOGNITION ENGINE',
                      style: TextStyle(
                        color: AppTheme.neonCyan,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text('Model Name:',
                              style: TextStyle(color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('InsightFace (buffalo_l)',
                            style: TextStyle(
                                color: AppTheme.neonGreen, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text('Vector Index:',
                              style: TextStyle(color: AppTheme.textSecondary),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Text('FAISS IndexFlatL2 (512d)',
                            style: TextStyle(
                                color: AppTheme.neonPurple, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Database System Settings
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SYSTEM PARAMETERS',
                      style: TextStyle(
                        color: AppTheme.neonCyan,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    settingsAsync.when(
                      data: (settingsList) {
                        if (settingsList.isEmpty) {
                          return const Text('No custom settings reported by backend.',
                              style: TextStyle(color: AppTheme.textSecondary));
                        }
                        return Column(
                          children: settingsList.map((s) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Flexible(
                                    child: Text(s.key,
                                        style: const TextStyle(color: AppTheme.textSecondary),
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(s.value ?? 'N/A',
                                      style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppTheme.neonCyan),
                      ),
                      error: (e, _) => Text('Could not fetch settings: $e',
                          style: const TextStyle(color: AppTheme.errorRed, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
