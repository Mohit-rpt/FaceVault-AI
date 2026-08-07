// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/api_client.dart';
import 'core/network/api_constants.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_shell.dart';

import 'services/local_storage/hive_embedding_store.dart';
import 'services/sync/sync_repository.dart';
import 'services/sync/sync_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConstants.initBaseUrl();

  try {
    final store = HiveEmbeddingStore();
    await store.initialize();

    final apiClient = ApiClient();
    final repo = SyncRepository(apiClient: apiClient, localStore: store);
    final syncManager = SyncManager(repository: repo);
    // Non-blocking initial sync check
    syncManager.checkAndSync();
    syncManager.startPeriodicSync(intervalMinutes: 15);
  } catch (e) {
    debugPrint('⚠️ Local storage initialization deferred: $e');
  }

  runApp(const ProviderScope(child: FaceVaultAI()));
}

class FaceVaultAI extends StatelessWidget {
  const FaceVaultAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FaceVault AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkCyberTheme,
      home: const AppShell(),
    );
  }
}