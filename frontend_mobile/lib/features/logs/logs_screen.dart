// lib/features/logs/logs_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/futuristic_app_bar.dart';
import 'widgets/recognition_log_card.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  String? _dateFilter;
  final List<Map<String, String?>> _dateOptions = [
    {'label': 'All Logs', 'value': null},
    {'label': 'Today', 'value': 'today'},
    {'label': 'Yesterday', 'value': 'yesterday'},
  ];

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(recognitionLogsProvider(_dateFilter));

    return Scaffold(
      appBar: const FuturisticAppBar(title: 'RECOGNITION LOGS'),
      body: Column(
        children: [
          // Filter Chips
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _dateOptions.length,
              itemBuilder: (context, index) {
                final opt = _dateOptions[index];
                final selected = opt['value'] == _dateFilter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(opt['label']!),
                    selected: selected,
                    onSelected: (_) => setState(() => _dateFilter = opt['value']),
                    selectedColor: AppTheme.neonCyan.withOpacity(0.2),
                    labelStyle: TextStyle(
                      color: selected ? AppTheme.neonCyan : AppTheme.textSecondary,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    side: BorderSide(
                      color: selected ? AppTheme.neonCyan : AppTheme.neonCyan.withOpacity(0.3),
                    ),
                  ),
                );
              },
            ),
          ),

          // Logs List
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.neonCyan,
              onRefresh: () async {
                ref.invalidate(recognitionLogsProvider(_dateFilter));
              },
              child: logsAsync.when(
                data: (logs) {
                  if (logs.isEmpty) {
                    return const Center(
                      child: Text(
                        'No recognition logs recorded for this period.',
                        style: TextStyle(color: AppTheme.textSecondary),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: logs.length,
                    itemBuilder: (context, index) =>
                        RecognitionLogCard(log: logs[index]),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppTheme.neonCyan),
                ),
                error: (err, stack) => Center(
                  child: Text('Failed to load logs: $err',
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}