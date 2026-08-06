// lib/shared/widgets/cyber_dropdown.dart
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class CyberDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;

  const CyberDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppTheme.neonCyan.withOpacity(0.8),
            fontSize: 12,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.neonCyan.withOpacity(0.3)),
            color: Colors.white.withOpacity(0.05),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            dropdownColor: AppTheme.surface,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppTheme.neonCyan),
            style: const TextStyle(color: AppTheme.textPrimary),
            items: items,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}