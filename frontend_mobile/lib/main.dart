// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/api_constants.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiConstants.initBaseUrl();
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